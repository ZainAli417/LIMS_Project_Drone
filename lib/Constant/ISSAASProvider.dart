import 'package:flutter/material.dart';

class ISSAASProvider with ChangeNotifier {
  bool _isSaas = false;

  bool get isSaas => _isSaas;

  void setIsSaas(bool value) {
    _isSaas = value;
    notifyListeners(); // Notify widgets to rebuild when value changes
  }
}
