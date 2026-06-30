import 'package:flutter/foundation.dart';

/// Lets screens several levels deep in a pushed stack (e.g. the checkout
/// wizard's [OrderPlacedScreen]) request which bottom-nav tab
/// `CustomerRootScreen` should land on, since popping back to root doesn't
/// otherwise let a descendant screen control the root's own tab state.
class NavigationProvider extends ChangeNotifier {
  int _customerTabIndex = 0;

  int get customerTabIndex => _customerTabIndex;

  void setCustomerTab(int index) {
    _customerTabIndex = index;
    notifyListeners();
  }

  void goToHome() => setCustomerTab(0);

  void goToCart() => setCustomerTab(1);

  void goToOrders() => setCustomerTab(2);

  void goToProfile() => setCustomerTab(3);
}
