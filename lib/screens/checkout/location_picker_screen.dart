import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../services/location_service.dart';

/// Full-screen map picker for confirming a delivery location - the
/// Swiggy/Zomato-style flow: center on the device's GPS fix, let the user
/// drag the map to fine-tune the pin (which stays fixed at screen center
/// while the map moves beneath it), resolve an address for wherever the
/// pin currently points, and return that address only once the user
/// explicitly confirms it. Pushed from [AddressFormFields]'s "Use current
/// location" button instead of silently trusting the first GPS fix.
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final _locationService = LocationService();
  GoogleMapController? _mapController;

  bool _loadingInitialPosition = true;
  bool _resolvingAddress = false;
  String? _errorMessage;
  ReverseGeocodedAddress? _resolvedAddress;
  LatLng _center = const LatLng(17.3850, 78.4867); // Hyderabad, until GPS resolves
  Timer? _debounce;
  final _searchController = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _loadInitialPosition();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _mapController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchAndMove(String query) async {
    if (query.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _searching = true);
    try {
      final (lat, lon) = await _locationService.searchAddress(query.trim());
      final target = LatLng(lat, lon);
      if (!mounted) return;
      setState(() {
        _center = target;
        _searching = false;
      });
      await _mapController?.animateCamera(CameraUpdate.newLatLngZoom(target, 17));
      unawaited(_resolveAddressAt(target));
    } on LocationServiceException catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _loadInitialPosition() async {
    try {
      final position = await _locationService.getCurrentPosition();
      final center = LatLng(position.latitude, position.longitude);
      if (!mounted) return;
      setState(() {
        _center = center;
        _loadingInitialPosition = false;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLng(center));
      unawaited(_resolveAddressAt(center));
    } on LocationServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingInitialPosition = false;
        _errorMessage = e.message;
      });
    }
  }

  Future<void> _resolveAddressAt(LatLng point) async {
    setState(() {
      _resolvingAddress = true;
      _errorMessage = null;
    });
    try {
      final address = await _locationService.reverseGeocode(
        point.latitude,
        point.longitude,
      );
      if (!mounted) return;
      setState(() {
        _resolvedAddress = address;
        _resolvingAddress = false;
      });
    } on LocationServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _resolvingAddress = false;
        _errorMessage = e.message;
      });
    }
  }

  void _onCameraMove(CameraPosition position) {
    _center = position.target;
  }

  void _onCameraIdle() {
    // Debounced so dragging the map doesn't fire a geocoding request per
    // frame - only once the camera has actually settled.
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _resolveAddressAt(_center),
    );
  }

  String _addressLine(ReverseGeocodedAddress address) {
    final parts = [
      if (address.building != null) address.building!,
      if (address.area != null) address.area!,
      if (address.city != null) address.city!,
      if (address.pincode != null) address.pincode!,
    ];
    return parts.isEmpty ? 'Address not found for this location' : parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search for area, street, landmark...',
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            suffixIcon: _searching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _searchAndMove(_searchController.text),
                  ),
          ),
          onSubmitted: _searchAndMove,
        ),
        titleSpacing: 0,
      ),
      body: _loadingInitialPosition
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _center,
                    zoom: 17,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                  myLocationButtonEnabled: false,
                  myLocationEnabled: true,
                  zoomControlsEnabled: false,
                ),
                // Fixed pin overlay at screen center - the map moves
                // beneath it, not the other way around, so the pin always
                // marks exactly the point being reverse-geocoded.
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.center,
                    child: Padding(
                      // Offset upward by half the pin's height so its tip,
                      // not its center, marks the map's center point.
                      padding: const EdgeInsets.only(bottom: 36),
                      child: Icon(
                        Icons.location_on,
                        size: 44,
                        color: colorScheme.primary,
                        shadows: const [
                          Shadow(color: Colors.black38, blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 180,
                  child: FloatingActionButton.small(
                    heroTag: 'recenter',
                    onPressed: _loadInitialPosition,
                    child: const Icon(Icons.my_location),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: _ConfirmCard(
                    resolving: _resolvingAddress,
                    errorMessage: _errorMessage,
                    addressLine: _resolvedAddress == null
                        ? null
                        : _addressLine(_resolvedAddress!),
                    onConfirm: _resolvedAddress == null
                        ? null
                        : () => Navigator.of(context).pop(_resolvedAddress),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ConfirmCard extends StatelessWidget {
  final bool resolving;
  final String? errorMessage;
  final String? addressLine;
  final VoidCallback? onConfirm;

  const _ConfirmCard({
    required this.resolving,
    required this.errorMessage,
    required this.addressLine,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 12),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Delivery location',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            if (resolving)
              const Row(
                children: [
                  SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Finding address...'),
                ],
              )
            else if (errorMessage != null)
              Text(
                errorMessage!,
                style: TextStyle(color: colorScheme.error),
              )
            else
              Text(
                addressLine ?? 'Move the map to set your location',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onConfirm,
                child: const Text('Confirm Location'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
