import 'dart:async';
import 'ParsingKML.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_drone/shared_state.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:location/location.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

enum PathDirection { horizontal, vertical }

class KML extends StatefulWidget {
  final YoutubePlayerController controller;
  const KML({Key? key, required this.controller}) : super(key: key);
  @override
  _KMLState createState() => _KMLState();
}

class _KMLState extends State<KML> {
  Timer? _debounce;
  final FocusNode _focusNode = FocusNode();
  int drone_direct = 0;
  // UP = 3
  // Down = 4
  // Left = 1
  // Right = 2
  // Stop = 0

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _initializeFirebaseListener();
    _loadKMLData(); // Load KML data here
    if (_markers.isNotEmpty) {
      selectedMarker = _markers.first.position;
    }
    _carPosition = LatLng(0, 0); // Initialize with a default value
  }

  Future<void> _loadKMLData() async {
    List<LatLng> kmlCoordinates =
        await KMLParser.parseKML('assets/rawalpindi.kml');
    setState(() {
      polygons.add(
        Polygon(
          polygonId: PolygonId('kml_polygon'),
          points: kmlCoordinates,
          strokeWidth: 2,
          fillColor: Colors.blue.withOpacity(0.3),
        ),
      );
    });
  }

  LatLng _currentPosition = LatLng(0, 0); // Default position
  late DatabaseReference _latRef;
  late DatabaseReference _longRef;
  late Stream<DatabaseEvent> _latStream;
  late Stream<DatabaseEvent> _longStream;
  PathDirection _selectedDirection = PathDirection.horizontal;
  double _totalDistanceKM = 0.0;
  double _remainingDistanceKM_SelectedPath = 0.0;
  double distanceTraveled = 0.0;
  double totalZigzagPathKm = 0.0;
  double TLM = 0.0;
  bool _isFullScreen = false;
  bool _isUpPressed = false;
  bool _isStop = false;
  bool _isLeftPressed = false;
  bool _isRightPressed = false;
  bool _isDownPressed = false;
  final List<List<LatLng>> _selectedPathsQueue = [];
  final Location _location = Location();
  LocationData? _currentLocation;
  bool _isMoving = false;
  late LatLng _carPosition;
  int _currentPointIndex = 0;
  late List<Marker> _markers = [];
  final List<LatLng> _markerPositions = [];
  Set<Polyline> _polylines = {};
  Set<Polygon> polygons = {};
  List<LatLng> _dronepath = [];
  late LatLng? selectedMarker =
      _markers.isNotEmpty ? _markers.first.position : null;
  late GoogleMapController _googleMapController;
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.ref();
  Timer? _movementTimer;
  double _remainingDistanceKM_TotalPath = 0.0;
  List<LatLng> polygonPoints = [];
  double pathWidth = 10.0;

  void _updateValueInDatabase(int value) async {
    try {
      await _databaseReference.child('Direction').set(value);
    } catch (e) {
      print('Error updating value in database: $e');
    }
  }

  void _updateValueInDatabaseOnRelease() async {
    try {
      await _databaseReference.child('Direction').set(0);
    } catch (e) {
      print('Error updating value in database: $e');
    }
  }

  void _resetMarkers() async {
    setState(() {
      _markers
          .removeWhere((marker) => marker.markerId == const MarkerId('car'));
      _isMoving = false;
      _currentPointIndex = 0;
      _movementTimer?.cancel();
      _markers.clear();
      _markerPositions.clear();
      _polylines.clear();
      polygons.clear();
      selectedMarker = null;
      _dronepath.clear();
      _selectedPathsQueue.clear();
      _totalDistanceKM = 0.0;
      _remainingDistanceKM_SelectedPath = 0.0;
      timeduration = 0.0;
      TLM = 0.0;
    });

    try {
      await _databaseReference.child('Markers').remove();
      await _databaseReference.child('Route').remove();
      await _databaseReference.child('Area').remove();
      await _databaseReference.child('totalDistance').remove();
      await _databaseReference.child('remainingDistance').remove();
      await _databaseReference.child('TimeDuration').remove();
      await _databaseReference.child('TimeLeft').remove();
    } catch (e) {
      print('Error resetting data in database: $e');
    }
  }

  Future<void> _requestLocationPermission() async {
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;
    _serviceEnabled = await _location.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await _location.requestService();
      if (!_serviceEnabled) {
        return;
      }
    }
    _permissionGranted = await _location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return;
      }
    }
    _currentLocation = await _location.getLocation();
    setState(() {});
  }

  void _initializeFirebaseListener() {
    _latRef = FirebaseDatabase.instance.ref().child('Current_Lat');
    _longRef = FirebaseDatabase.instance.ref().child('Current_Long');
    _latStream = _latRef.onValue;
    _longStream = _longRef.onValue;
    _latStream.listen((DatabaseEvent latEvent) {
      if (latEvent.snapshot.value != null) {
        final double newLat = latEvent.snapshot.value as double;
        _longStream.listen((DatabaseEvent longEvent) {
          if (longEvent.snapshot.value != null) {
            final double newLong = longEvent.snapshot.value as double;
            _updateMarkerPosition(newLat, newLong);
          }
        });
      }
    });
  }

  void _updateMarkerPosition(double lat, double long) {
    setState(() {
      _currentPosition = LatLng(lat, long);
    });
  }

  void _hideKeyboard() {
    FocusScope.of(context).previousFocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

//UI BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Smart Controller"),
        actions: [
          IconButton(
            icon: const Icon(Icons.fullscreen),
            onPressed: () {
              setState(() {
                _isFullScreen = !_isFullScreen;
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(10),
              color: Colors.white,
              child: Center(
                child: YoutubePlayer(
                  controller: widget.controller,
                  showVideoProgressIndicator: false,
                ),
              ),
            ),
//center
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          GestureDetector(
                            onTapDown: (TapDownDetails details) {
                              setState(() {
                                _isUpPressed = true;
                                _isLeftPressed = false;
                                _isRightPressed = false;
                                _isDownPressed = false;
                                drone_direct = 3;
                              });
                              _updateValueInDatabase(drone_direct);
                            },
                            onTapUp: (TapUpDetails details) {
                              setState(() {
                                _isUpPressed = false;
                                drone_direct = 0;
                              });
                              _updateValueInDatabaseOnRelease();
                            },
                            child: Image.asset(
                              'images/up.png',
                              width: _isUpPressed ? 45 : 35,
                              height: _isUpPressed ? 45 : 35,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTapDown: (TapDownDetails details) {
                          setState(() {
                            _isUpPressed = false;
                            _isLeftPressed = true;
                            _isRightPressed = false;
                            _isDownPressed = false;
                            drone_direct = 1;
                          });
                          _updateValueInDatabase(drone_direct);
                        },
                        onTapUp: (TapUpDetails details) {
                          setState(() {
                            _isLeftPressed = false;
                            drone_direct = 0;
                          });
                          _updateValueInDatabaseOnRelease();
                        },
                        child: Image.asset(
                          'images/left.png',
                          width: _isLeftPressed ? 45 : 35,
                          height: _isLeftPressed ? 45 : 35,
                        ),
                      ),
                      SizedBox(width: 5),
                      GestureDetector(
                        onTapDown: (TapDownDetails details) {
                          setState(() {
                            _isUpPressed = false;
                            _isStop = true;
                            _isLeftPressed = false;
                            _isRightPressed = false;
                            _isDownPressed = false;
                            drone_direct = 0;
                          });
                          _updateValueInDatabase(drone_direct);
                        },
                        onTapUp: (TapUpDetails details) {
                          setState(() {
                            _isStop = false;
                            drone_direct = 0;
                          });
                          _updateValueInDatabaseOnRelease();
                        },
                        child: Image.asset(
                          'images/stop.png',
                          width: _isStop ? 45 : 35,
                          height: _isStop ? 45 : 35,
                        ),
                      ),
                      SizedBox(width: 5),
                      GestureDetector(
                        onTapDown: (TapDownDetails details) {
                          setState(() {
                            _isUpPressed = false;
                            _isStop = false;
                            _isLeftPressed = false;
                            _isRightPressed = true;
                            _isDownPressed = false;
                            drone_direct = 2;
                          });
                          _updateValueInDatabase(drone_direct);
                        },
                        onTapUp: (TapUpDetails details) {
                          setState(() {
                            _isRightPressed = false;
                            drone_direct = 0;
                          });
                          _updateValueInDatabaseOnRelease();
                        },
                        child: Image.asset(
                          'images/right.png',
                          width: _isRightPressed ? 45 : 35,
                          height: _isRightPressed ? 45 : 35,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          GestureDetector(
                            onTapDown: (TapDownDetails details) {
                              setState(() {
                                _isUpPressed = false;
                                _isStop = false;
                                _isLeftPressed = false;
                                _isRightPressed = false;
                                _isDownPressed = true;
                                drone_direct = 4;
                              });
                              _updateValueInDatabase(drone_direct);
                            },
                            onTapUp: (TapUpDetails details) {
                              setState(() {
                                _isDownPressed = false;
                                drone_direct = 0;
                              });
                              _updateValueInDatabaseOnRelease();
                            },
                            child: Image.asset(
                              'images/down.png',
                              width: _isDownPressed ? 45 : 35,
                              height: _isDownPressed ? 45 : 35,
                            ),
                          ),
                          SizedBox(height: 10),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            Container(
              height: _isFullScreen
                  ? MediaQuery.of(context).size.height * 0.85
                  : 400,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    _currentLocation == null
                        ? const Center(child: CircularProgressIndicator())
                        : GoogleMap(
                            initialCameraPosition: CameraPosition(
                              target: LatLng(
                                _currentLocation!.latitude!,
                                _currentLocation!.longitude!,
                              ),
                              zoom: 15.0,
                              //zoom:10.0,
                            ),
                            markers: {
                              ..._markers,
                              Marker(
                                markerId: const MarkerId('currentLocation'),
                                position: _currentPosition,
                                icon: BitmapDescriptor.defaultMarkerWithHue(
                                    BitmapDescriptor.hueViolet),
                              ),
                            },
                            polylines: _polylines,
                            polygons: polygons,
                            zoomGesturesEnabled: true,
                            rotateGesturesEnabled: true,
                            buildingsEnabled: true,
                            scrollGesturesEnabled: true,
                            // onTap: _onMapTap,
                            onMapCreated: (controller) {
                              _googleMapController = controller;
                            },
                            gestureRecognizers: <Factory<
                                OneSequenceGestureRecognizer>>{
                              Factory<OneSequenceGestureRecognizer>(
                                  () => EagerGestureRecognizer()),
                            },
                            myLocationEnabled: true,
                            myLocationButtonEnabled: true,
                          ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ClipRRect(
                        borderRadius:
                            BorderRadius.circular(30.0), // Capsule shape
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                          ),
                          child: TypeAheadField<geocoding.Placemark>(
                            textFieldConfiguration: TextFieldConfiguration(
                              focusNode: _focusNode,
                              autofocus: false,
                              style: const TextStyle(
                                fontFamily:
                                    'sans', // Replace with your font family
                                fontSize: 15.0, // Customize font size
                                color: Colors.black, // Customize text color
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                labelText: 'Search Spraying Location',
                                labelStyle: const TextStyle(
                                  fontFamily: 'impact',
                                  fontWeight: FontWeight
                                      .w500, // Replace with your font family
                                  fontSize: 14.0, // Customize label font size
                                  color: Colors.teal, // Customize label color
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.search,
                                      color:
                                          Colors.black), // Customize icon color
                                  onPressed:
                                      _hideKeyboard, // Hide keyboard on search button press
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 12.0),
                              ),
                            ),
                            suggestionsCallback: (pattern) {
                              if (pattern.isEmpty)
                                return Future.value(<geocoding.Placemark>[]);
                              _debounce?.cancel();
                              final completer =
                                  Completer<List<geocoding.Placemark>>();
                              _debounce = Timer(const Duration(microseconds: 1),
                                  () async {
                                List<geocoding.Placemark> placemarks = [];
                                try {
                                  List<geocoding.Location> locations =
                                      await geocoding
                                          .locationFromAddress(pattern);
                                  if (locations.isNotEmpty) {
                                    placemarks = await Future.wait(
                                      locations.map((location) =>
                                          geocoding.placemarkFromCoordinates(
                                            location.latitude,
                                            location.longitude,
                                          )),
                                    ).then((results) =>
                                        results.expand((x) => x).toList());
                                  }
                                } catch (e) {
                                  // Handle error if needed
                                }
                                completer.complete(placemarks);
                              });
                              return completer.future;
                            },
                            itemBuilder:
                                (context, geocoding.Placemark suggestion) {
                              return ListTile(
                                leading: const Icon(Icons.location_on,
                                    color:
                                        Colors.green), // Customize icon color
                                title: Text(
                                  suggestion.name ??
                                      'No Country/City Available',
                                  style: const TextStyle(
                                    fontFamily:
                                        'sans', // Replace with your font family
                                    fontSize: 16.0,
                                    fontWeight:
                                        FontWeight.w400, // Customize font size
                                    color: Colors.black, // Customize text color
                                  ),
                                ),
                                subtitle: Text(
                                  suggestion.locality ?? 'No locality Exists',
                                  style: const TextStyle(
                                    fontFamily:
                                        'Arial', // Replace with your font family
                                    fontSize: 14.0, // Customize font size
                                    color:
                                        Colors.black54, // Customize text color
                                  ),
                                ),
                              );
                            },
                            onSuggestionSelected:
                                (geocoding.Placemark suggestion) async {
                              final address =
                                  '${suggestion.name ?? ''}, ${suggestion.locality ?? ''}';
                              try {
                                List<geocoding.Location> locations =
                                    await geocoding
                                        .locationFromAddress(address);
                                if (locations.isNotEmpty) {
                                  final location = locations.first;
                                  _googleMapController.animateCamera(
                                    CameraUpdate.newCameraPosition(
                                      CameraPosition(
                                        target: LatLng(location.latitude,
                                            location.longitude),
                                        zoom: 15.0,
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                print('Error: $e');
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 65,
                      right: 0,
                      child: IconButton(
                        icon: Icon(
                          _isFullScreen
                              ? Icons.fullscreen_exit
                              : Icons.fullscreen,
                          size: 40,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          setState(() {
                            _isFullScreen = !_isFullScreen;
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: ElevatedButton(
                        onPressed: _resetMarkers,
                        child: const Text('Reset Map'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
