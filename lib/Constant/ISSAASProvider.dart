import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class ISSAASProvider with ChangeNotifier {
  bool _isSaas = false;
  LatLng _GPSloc = const LatLng(0.0, 0.0); // Default value

  bool get isSaas => _isSaas;
  LatLng get GPSPostions => _GPSloc;

  // Method to set the SaaS mode
  void setIsSaas(bool value) {
    _isSaas = value;
    notifyListeners();
  }

  // Method to update the current LatLng
  void updateCurrentLatLng(LatLng latLng) {
    _GPSloc = latLng;
    notifyListeners();
  }

  Future<void> init() async {
    final position = await getPosition();
    _GPSloc = LatLng(position.latitude, position.longitude);
    notifyListeners();
    }

  Future<Position> getPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }
}