import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;

  // Initial camera position
  static const LatLng initialCameraPosition = LatLng(33.5923397, 73.0476774);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    appBar: AppBar(
        title: Text('Google Maps'),
      ),
      body: SingleChildScrollView(

      child: GoogleMap(
        onMapCreated: (controller) {
          setState(() {
            mapController = controller;
          });
        },
        initialCameraPosition: const CameraPosition(
          target: initialCameraPosition,
          zoom: 14.0,
        ),
        markers: {
          const Marker(
            markerId: MarkerId('marker_id'),
            position: initialCameraPosition,
            infoWindow: InfoWindow(title: 'Marker Title', snippet: 'Marker Snippet'),
          ),
        },
      ),
        ),
    );
  }
}
