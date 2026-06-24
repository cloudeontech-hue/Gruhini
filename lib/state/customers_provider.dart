import 'package:flutter/foundation.dart';

import '../models/customer.dart';
import '../services/supabase_client.dart';

class CustomersProvider extends ChangeNotifier {
  final List<Customer> _customers = [];
  bool _isLoaded = false;

  List<Customer> get customers => List.unmodifiable(_customers);
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    final rows = await supabase.from('customers').select();
    _customers
      ..clear()
      ..addAll(rows.map(Customer.fromMap));
    _isLoaded = true;
    notifyListeners();
  }
}
