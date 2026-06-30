import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Backing controllers for [AddressFormFields], shared by the delivery
/// address screen and the profile address editor. [compose] prefixes the
/// result with `[label]` (e.g. `[Home] ...`) — callers that display a saved
/// address strip that prefix back off before showing it to the user.
class AddressFieldControllers {
  final TextEditingController flatNo = TextEditingController();
  final TextEditingController building = TextEditingController();
  final TextEditingController area = TextEditingController();
  final TextEditingController city = TextEditingController();
  final TextEditingController pincode = TextEditingController();
  String label = 'Home';

  void dispose() {
    flatNo.dispose();
    building.dispose();
    area.dispose();
    city.dispose();
    pincode.dispose();
  }

  String compose() {
    final parts = [
      flatNo.text.trim(),
      if (building.text.trim().isNotEmpty) building.text.trim(),
      area.text.trim(),
      '${city.text.trim()} - ${pincode.text.trim()}',
    ];
    return '[$label] ${parts.join(', ')}';
  }
}

class AddressFormFields extends StatefulWidget {
  final AddressFieldControllers controllers;

  const AddressFormFields({super.key, required this.controllers});

  @override
  State<AddressFormFields> createState() => _AddressFormFieldsState();
}

class _AddressFormFieldsState extends State<AddressFormFields> {
  static const _labels = ['Home', 'Work', 'Other'];
  static const _labelIcons = {
    'Home': Icons.home_outlined,
    'Work': Icons.work_outline,
    'Other': Icons.location_on_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Field(
          controller: widget.controllers.flatNo,
          label: 'House / Flat / Floor No.',
          icon: Icons.apartment_outlined,
          required: true,
        ),
        const SizedBox(height: 12),
        _Field(
          controller: widget.controllers.building,
          label: 'Building / Apartment Name',
          icon: Icons.business_outlined,
          required: false,
        ),
        const SizedBox(height: 12),
        _Field(
          controller: widget.controllers.area,
          label: 'Street / Colony / Area',
          icon: Icons.signpost_outlined,
          required: true,
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: _Field(
                controller: widget.controllers.city,
                label: 'City',
                icon: Icons.location_city_outlined,
                required: true,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: widget.controllers.pincode,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  labelText: 'Pincode',
                  prefixIcon: Icon(
                    Icons.pin_drop_outlined,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                validator: (value) {
                  final v = value?.trim() ?? '';
                  if (v.isEmpty) return 'Required';
                  if (v.length != 6) return '6 digits';
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Save as',
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Row(
          children: _labels.map((label) {
            final selected = widget.controllers.label == label;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                avatar: Icon(
                  _labelIcons[label],
                  size: 16,
                  color: selected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
                label: Text(label),
                selected: selected,
                showCheckmark: false,
                selectedColor: colorScheme.primary,
                labelStyle: TextStyle(
                  color: selected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                onSelected: (_) =>
                    setState(() => widget.controllers.label = label),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool required;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    required this.required,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: required ? label : '$label (optional)',
        prefixIcon: Icon(
          icon,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
      validator: required
          ? (value) =>
                (value == null || value.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }
}
