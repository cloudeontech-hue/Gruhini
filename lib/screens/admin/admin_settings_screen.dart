import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/theme_provider.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Column(
            children: [
              const ListTile(
                leading: Icon(Icons.storefront_outlined),
                title: Text('Store Name'),
                subtitle: Text('Gruhini Foods'),
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.email_outlined),
                title: Text('Support Email'),
                subtitle: Text('support@Gruhinifoods.com'),
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: Icon(
                  themeProvider.isDarkMode ? Icons.dark_mode : Icons.dark_mode_outlined,
                ),
                title: const Text('Dark Mode'),
                value: themeProvider.isDarkMode,
                onChanged: (value) => themeProvider.setDarkMode(value),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'App version 1.0.0',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
