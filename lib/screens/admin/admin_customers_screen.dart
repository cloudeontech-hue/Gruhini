import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/customers_provider.dart';

class AdminCustomersScreen extends StatefulWidget {
  const AdminCustomersScreen({super.key});

  @override
  State<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends State<AdminCustomersScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final customersProvider = context.watch<CustomersProvider>();
    if (!customersProvider.isLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    final customers = customersProvider.customers
        .where((c) => c.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Search customers...',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: customers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final customer = customers[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?'),
                  ),
                  title: Text(customer.name),
                  subtitle: Text('${customer.phone}\n${customer.address}'),
                  isThreeLine: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
