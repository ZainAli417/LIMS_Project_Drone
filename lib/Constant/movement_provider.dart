import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';


class MovementProvider with ChangeNotifier {
  LatLng _carPosition;
  int _currentPointIndex;

  MovementProvider(this._carPosition, this._currentPointIndex);

  LatLng get carPosition => _carPosition;
  int get currentPointIndex => _currentPointIndex;

  void updateCarPosition(LatLng newPosition) {
    _carPosition = newPosition;
    notifyListeners();
  }

  void updateCurrentPointIndex(int newIndex) {
    _currentPointIndex = newIndex;
    notifyListeners();
  }
}