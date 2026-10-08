import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Thrown by [LocationService] for every failure mode - permission denied,
/// location services off, GPS timeout, or the reverse-geocoding lookup
/// itself failing. [message] is already user-facing (shown directly in a
/// SnackBar by callers).
class LocationServiceException implements Exception {
  final String message;
  const LocationServiceException(this.message);

  @override
  String toString() => message;
}

/// Address fields recovered from a GPS fix via reverse geocoding. Any field
/// can be null if Google has no data for it at this location - the caller
/// fills what it can and leaves the rest for the user to type.
class ReverseGeocodedAddress {
  final String? houseNumber;
  final String? building;
  final String? area;
  final String? city;
  final String? pincode;

  const ReverseGeocodedAddress({
    this.houseNumber,
    this.building,
    this.area,
    this.city,
    this.pincode,
  });
}

/// Reads the device's current GPS position and reverse-geocodes it into
/// address fields via Google's Geocoding API. Requires
/// GOOGLE_GEOCODING_API_KEY in .env - the key is restricted in Google Cloud
/// Console (Android app restriction: package name + release keystore
/// SHA-1) rather than kept secret, since Maps Platform keys are designed
/// to be embedded client-side and secured that way.
class LocationService {
  static const _reverseGeocodeUrl =
      'https://maps.googleapis.com/maps/api/geocode/json';

  Future<ReverseGeocodedAddress> getCurrentAddress() async {
    final position = await getCurrentPosition();
    return reverseGeocode(position.latitude, position.longitude);
  }

  /// Exposed separately from [getCurrentAddress] so [LocationPickerScreen]
  /// can center the map on the device's position, then call
  /// [reverseGeocode] again itself every time the user drags the pin -
  /// rather than being locked to whatever address the initial GPS fix
  /// resolved to.
  Future<Position> getCurrentPosition() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationServiceException(
        'Location is turned off on this device. Please enable it and try again.',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationServiceException(
          'Location permission was denied. Please allow it to use your current location.',
        );
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationServiceException(
        'Location permission is permanently denied. Enable it from Settings to use your current location.',
      );
    }

    try {
      // LocationAccuracy.best (not .high) actually matters here: .high can
      // settle for a fast network/Wi-Fi-based fix that's only accurate to
      // ~100-500m, which is fine for "which city is this user roughly in"
      // but not for pinpointing a delivery address. .best asks for a real
      // GPS lock, which takes longer (especially the first fix, or
      // indoors) - the 20s budget below accounts for that.
      final firstFix = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          timeLimit: Duration(seconds: 20),
        ),
      );
      // A single reading can still land on a coarse cell/Wi-Fi fix even at
      // .best if GPS hasn't locked yet. If accuracy is worse than ~30m,
      // spend a few more seconds listening for a tighter fix and keep
      // whichever reading is most precise - bounded so a GPS-denied
      // environment (desktop browser, no GPS hardware) can't hang forever.
      if (firstFix.accuracy > 30) {
        return await _refineFix(firstFix);
      }
      return firstFix;
    } on LocationServiceDisabledException {
      throw const LocationServiceException(
        'Location is turned off on this device. Please enable it and try again.',
      );
    } catch (_) {
      throw const LocationServiceException(
        'Could not get your current location. Please try again.',
      );
    }
  }

  /// Listens briefly for a tighter GPS fix than [initialFix], up to a
  /// bounded time budget - never blocks indefinitely if the device can't
  /// do better (e.g. no real GPS hardware, or a persistently weak signal).
  Future<Position> _refineFix(Position initialFix) async {
    var best = initialFix;
    final stream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    );
    try {
      await for (final reading in stream.timeout(const Duration(seconds: 6))) {
        if (reading.accuracy < best.accuracy) best = reading;
        if (best.accuracy <= 15) break; // good enough, stop early
      }
    } catch (_) {
      // Timeout or stream error - fall through and use whatever's best so far.
    }
    return best;
  }

  /// Public so [LocationPickerScreen] can re-resolve an address every time
  /// the user drags the map to a new center point.
  Future<ReverseGeocodedAddress> reverseGeocode(
    double lat,
    double lon,
  ) async {
    final apiKey = dotenv.env['GOOGLE_GEOCODING_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw const LocationServiceException(
        'Location lookup is not configured. Please enter your address manually.',
      );
    }

    final uri = Uri.parse(_reverseGeocodeUrl).replace(
      queryParameters: {
        'latlng': '$lat,$lon',
        'language': 'en',
        'key': apiKey,
      },
    );

    http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const LocationServiceException(
        'Could not reach the location lookup service. Check your connection and try again.',
      );
    }

    if (response.statusCode != 200) {
      throw const LocationServiceException(
        'Could not look up an address for your location. Please try again.',
      );
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const LocationServiceException(
        'Could not look up an address for your location. Please try again.',
      );
    }

    final status = body['status'] as String?;
    if (status == 'ZERO_RESULTS') {
      throw const LocationServiceException(
        'No address was found for your current location.',
      );
    }
    if (status != 'OK') {
      // REQUEST_DENIED (bad/restricted key), OVER_QUERY_LIMIT (billing/quota
      // exhausted), INVALID_REQUEST, or any other non-OK status.
      throw const LocationServiceException(
        'Could not look up an address for your location. Please try again.',
      );
    }

    final results = body['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      throw const LocationServiceException(
        'No address was found for your current location.',
      );
    }

    final components =
        (results.first as Map<String, dynamic>)['address_components']
            as List<dynamic>?;
    if (components == null) {
      throw const LocationServiceException(
        'No address was found for your current location.',
      );
    }

    String? componentOfType(String type) {
      for (final component in components) {
        final map = component as Map<String, dynamic>;
        final types = (map['types'] as List<dynamic>?)?.cast<String>();
        if (types != null && types.contains(type)) {
          final value = map['long_name'] as String?;
          if (value != null && value.trim().isNotEmpty) return value;
        }
      }
      return null;
    }

    final houseNumber = componentOfType('street_number');
    final route = componentOfType('route');
    final sublocality =
        componentOfType('sublocality_level_1') ??
        componentOfType('sublocality') ??
        componentOfType('neighborhood');
    final area = [
      route,
      sublocality,
    ].whereType<String>().join(', ').trim();

    return ReverseGeocodedAddress(
      houseNumber: houseNumber,
      building: componentOfType('premise') ?? componentOfType('point_of_interest'),
      area: area.isEmpty ? null : area,
      city:
          componentOfType('locality') ??
          componentOfType('administrative_area_level_2') ??
          componentOfType('administrative_area_level_1'),
      pincode: componentOfType('postal_code'),
    );
  }

  /// Forward-geocodes a free-text search query (e.g. "Charminar, Hyderabad")
  /// into a coordinate, for [LocationPickerScreen]'s search bar - lets a
  /// user jump the map straight to a typed address instead of only
  /// dragging the pin. Reuses the same Geocoding API endpoint as
  /// [reverseGeocode] (just the `address` param instead of `latlng`), so
  /// no extra API needs enabling in Google Cloud Console beyond what
  /// reverse geocoding already requires.
  Future<(double lat, double lon)> searchAddress(String query) async {
    final apiKey = dotenv.env['GOOGLE_GEOCODING_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw const LocationServiceException(
        'Location search is not configured. Please enter your address manually.',
      );
    }

    final uri = Uri.parse(_reverseGeocodeUrl).replace(
      queryParameters: {'address': query, 'language': 'en', 'key': apiKey},
    );

    http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 10));
    } catch (_) {
      throw const LocationServiceException(
        'Could not reach the location search service. Check your connection and try again.',
      );
    }

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const LocationServiceException(
        'Could not search for that address. Please try again.',
      );
    }

    final status = body['status'] as String?;
    if (status == 'ZERO_RESULTS') {
      throw const LocationServiceException(
        'No matching location found. Try a different search.',
      );
    }
    if (status != 'OK') {
      throw const LocationServiceException(
        'Could not search for that address. Please try again.',
      );
    }

    final results = body['results'] as List<dynamic>?;
    Map<String, dynamic>? location;
    if (results != null && results.isNotEmpty) {
      final firstResult = results.first as Map<String, dynamic>;
      final geometry = firstResult['geometry'] as Map<String, dynamic>?;
      location = geometry?['location'] as Map<String, dynamic>?;
    }
    final lat = location?['lat'] as num?;
    final lng = location?['lng'] as num?;
    if (lat == null || lng == null) {
      throw const LocationServiceException(
        'No matching location found. Try a different search.',
      );
    }
    return (lat.toDouble(), lng.toDouble());
  }
}
