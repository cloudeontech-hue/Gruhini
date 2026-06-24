import 'package:flutter/material.dart';

class AdminSidebar extends StatelessWidget {
  final List<String> titles;
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final VoidCallback onLogout;

  const AdminSidebar({
    super.key,
    required this.titles,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.onLogout,
  });

  static const _icons = {
    'Dashboard': Icons.dashboard_outlined,
    'Products': Icons.inventory_2_outlined,
    'Orders': Icons.receipt_long_outlined,
    'Customers': Icons.people_outline,
    'Shop Owners': Icons.storefront_outlined,
    'Settings': Icons.settings_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  Icon(Icons.storefront, color: theme.colorScheme.primary, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Gruhini Foods\nAdmin',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                itemCount: titles.length,
                itemBuilder: (context, index) {
                  final title = titles[index];
                  final selected = index == selectedIndex;
                  final color =
                      selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: ListTile(
                      selected: selected,
                      selectedTileColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      leading: Icon(_icons[title] ?? Icons.circle_outlined, color: color),
                      title: Text(
                        title,
                        style: TextStyle(
                          color: color,
                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      onTap: () => onItemSelected(index),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                hoverColor: theme.colorScheme.error.withValues(alpha: 0.08),
                leading: Icon(Icons.logout, color: theme.colorScheme.error),
                title: Text(
                  'Logout',
                  style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.w600),
                ),
                onTap: onLogout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
