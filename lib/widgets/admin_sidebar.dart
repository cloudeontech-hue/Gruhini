import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../utils/app_colors.dart';

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
      color: theme.cardTheme.color ?? theme.colorScheme.surfaceContainerLow,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
              decoration: const BoxDecoration(
                color: AppColors.brand,
                border: Border(
                  bottom: BorderSide(color: AppColors.gold, width: 2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: ClipOval(
                      child: SvgPicture.asset(
                        'assets/images/logo.svg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Gruhini Foods\nAdmin',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                itemCount: titles.length,
                itemBuilder: (context, index) {
                  final title = titles[index];
                  final selected = index == selectedIndex;
                  final color = selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      decoration: BoxDecoration(
                        border: selected
                            ? const Border(
                                left: BorderSide(
                                  color: AppColors.gold,
                                  width: 3,
                                ),
                              )
                            : const Border(
                                left: BorderSide(
                                  color: Colors.transparent,
                                  width: 3,
                                ),
                              ),
                      ),
                      child: ListTile(
                        selected: selected,
                        selectedTileColor: theme.colorScheme.primary.withValues(
                          alpha: 0.12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        leading: Icon(
                          _icons[title] ?? Icons.circle_outlined,
                          color: color,
                        ),
                        title: Text(
                          title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: color,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                        onTap: () => onItemSelected(index),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                hoverColor: theme.colorScheme.error.withValues(alpha: 0.08),
                leading: Icon(Icons.logout, color: theme.colorScheme.error),
                title: Text(
                  'Logout',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
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
