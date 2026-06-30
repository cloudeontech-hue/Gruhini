import 'package:flutter/foundation.dart';

import '../models/customer.dart';
import '../services/supabase_client.dart';

class CustomersProvider extends ChangeNotifier {
  final List<Customer> _customers = [];
  bool _isLoaded = false;

  List<Customer> get customers => List.unmodifiable(_customers);
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    try {
      final rows = await supabase.from('customers').select();
      _customers
        ..clear()
        ..addAll(rows.map(Customer.fromMap));
    } catch (error) {
      // Don't leave isLoaded stuck false on a backend hiccup - that would
      // freeze every screen that gates on this provider in a permanent
      // loading spinner.
      debugPrint('Could not load customers: $error');
    }
    _isLoaded = true;
    notifyListeners();
  }
}
