import 'package:xml/xml.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter/services.dart';

class KMLParser {
  static Future<List<LatLng>> parseKML(String assetPath) async {
    final String kmlString = await rootBundle.loadString(assetPath);
    final XmlDocument document = XmlDocument.parse(kmlString);

    final List<LatLng> coordinates = [];
    final Iterable<XmlElement> placemarks = document.findAllElements('Placemark');

    for (final XmlElement placemark in placemarks) {
      final String coords = placemark.findAllElements('coordinates').first.text.trim();

      final List<String> coordPairs = coords.split(' ');

      for (final String pair in coordPairs) {
        final List<String> latLon = pair.split(',');

        if (latLon.length >= 2) {
          final double longitude = double.parse(latLon[0]);
          final double latitude = double.parse(latLon[1]);
          coordinates.add(LatLng(latitude, longitude));
        }
      }
        }
    return coordinates;
  }
}
