import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:location/location.dart';
import '../shared_state.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:latlong2/latlong.dart' as latlong;

enum PathDirection { horizontal, vertical }

class VideoScreen extends StatefulWidget {
  final YoutubePlayerController controller;
  const VideoScreen({Key? key, required this.controller}) : super(key: key);
  @override
  _VideoScreenState createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  Timer? _debounce;
  final FocusNode _focusNode = FocusNode();
  int drone_direct = 0;
  // UP = 3
  // Down = 4
  // Left = 1
  // Right = 2
  // Stop = 0
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

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _initializeFirebaseListener();
    _carPosition = LatLng(0, 0); // Initialize with a default value
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
      _polygons.clear();
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
  Timer? _movementTimer;
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.ref();
  late GoogleMapController _googleMapController;
  final List<Marker> _markers = [];
  final List<LatLng> _markerPositions = [];
  Set<Polyline> _polylines = {};
  Set<Polygon> _polygons = {};
  List<LatLng> _dronepath = [];
  double _remainingDistanceKM_TotalPath = 0.0;

  double calculate_selcted_segemnt_distance(List<LatLng> path) {
    double totalDistance = 0.0;
    for (int i = 0; i < path.length - 1; i++) {
      totalDistance += calculateonelinedistance(path[i], path[i + 1]);
    }
    _storeTimeDurationInDatabase(totalDistance);

    return totalDistance;
  } // Return distance in kilometers

  LatLng _lerpLatLng(LatLng a, LatLng b, double t) {
    double lat = a.latitude + (b.latitude - a.latitude) * t;
    double lng = a.longitude + (b.longitude - a.longitude) * t;
    return LatLng(lat, lng);
  }

  void _storeTimeDurationInDatabase(double totalDistanceInKM) {
    try {
      const double speed = 10; // Speed in meters per second
      double totalDistanceInMeters = totalDistanceInKM * 1000;
      double timeDurationInSeconds = totalDistanceInMeters / speed;
      double timeDurationInMinutes = timeDurationInSeconds / 60;
      timeduration = timeDurationInMinutes;
      DatabaseReference timeDuration = _databaseReference.child('TimeDuration');
      timeDuration.set(timeDurationInMinutes);
    } catch (e) {
      print('Error storing time duration in database: $e');
    }
  }

  void _storeTimeLeftInDatabase(double remainingDistanceKM_SelectedPath) async {
    try {
      const double speed = 10; // Speed in meters per second
      double remainingDistanceMeters = remainingDistanceKM_SelectedPath * 1000;
      double timeLeftSeconds = remainingDistanceMeters / speed;
      double timeLeftMinutes = timeLeftSeconds / 60;
      TLM = timeLeftMinutes;
      DatabaseReference timeDurationRef = _databaseReference.child('TimeLeft');
      await timeDurationRef.set(timeLeftMinutes);
    } catch (e) {
      print('Error storing time duration in database: $e');
    }
  }

  double calculateonelinedistance(LatLng start, LatLng end) {
    const R = 6371; // Radius of the Earth in kilometers
    double lat1 = start.latitude * pi / 180;
    double lon1 = start.longitude * pi / 180;
    double lat2 = end.latitude * pi / 180;
    double lon2 = end.longitude * pi / 180;
    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c; // Distance in kilometers
  }

  double _calculateTotalDistanceZIGAG(List<LatLng> path) {
    double totalzigzagdis = 0.0;
    for (int i = 0; i < path.length - 1; i++) {
      totalzigzagdis += calculateonelinedistance(path[i], path[i + 1]);
    }
    return totalzigzagdis;
  } // Return distance in kilometers

  void _startMovement(List<LatLng> path) {
    if (path.isEmpty) {
      print("Path is empty, cannot start movement");
      return;
    }

    setState(() {
      _carPosition = path[0];
      _currentPointIndex = 0;
    });
    _addCarMarker(_isSegmentSelected(path, 0));
    double updateInterval = 0.1; // seconds
    _isMoving = true;
    double speed = 10.0; // 10 meters per second
    double totalDistanceCoveredKM_SelectedPath = 0.0;
    double distanceCoveredInWholeJourney = 0.0;
    double segmentDistanceCoveredKM = 0.0;
    _movementTimer = Timer.periodic(
        Duration(milliseconds: (updateInterval * 1000).toInt()), (timer) async {
      if (_currentPointIndex < path.length - 1) {
        LatLng start = path[_currentPointIndex];
        LatLng end = path[_currentPointIndex + 1];
        double segmentDistanceKM = calculateonelinedistance(start, end);
        double distanceCoveredInThisTickKM = (speed * updateInterval) / 1000.0;
        segmentDistanceCoveredKM += distanceCoveredInThisTickKM;
        double segmentProgress =
            (segmentDistanceCoveredKM / segmentDistanceKM).clamp(0.0, 1.0);
        _carPosition = _lerpLatLng(start, end, segmentProgress);
        bool isSelectedSegment = _isSegmentSelected(path, _currentPointIndex);
        distanceCoveredInWholeJourney += distanceCoveredInThisTickKM;

        if (isSelectedSegment) {
          totalDistanceCoveredKM_SelectedPath += distanceCoveredInThisTickKM;
          double remainingDistanceKM_SelectedPath =
              _totalDistanceKM - totalDistanceCoveredKM_SelectedPath;
          setState(() {
            _remainingDistanceKM_SelectedPath =
                remainingDistanceKM_SelectedPath.clamp(0.0, _totalDistanceKM);
            _storeTimeLeftInDatabase(_remainingDistanceKM_SelectedPath);
          });
          // Only update database periodically
          if (totalDistanceCoveredKM_SelectedPath % 0.5 == 0) {
            // Update every 500m
            FirebaseDatabase.instance
                .ref()
                .child('remainingDistance')
                .set(_remainingDistanceKM_SelectedPath);
          }
        }
        setState(() {
          _remainingDistanceKM_TotalPath =
              (totalZigzagPathKm - distanceCoveredInWholeJourney)
                  .clamp(0.0, totalZigzagPathKm);
        });
        setState(() {
          _markers.removeWhere(
              (marker) => marker.markerId == const MarkerId('car'));
          _addCarMarker(isSelectedSegment);
          if (segmentProgress >= 1.0) {
            _currentPointIndex++;
            segmentDistanceCoveredKM = 0.0;
          }
        });
        if (_currentPointIndex >= path.length - 1) {
          _isMoving = false;
          timer.cancel();
          _onPathComplete();
        }
      } else {
        _movementTimer?.cancel();
        _isMoving = false;
        timer.cancel();
        _onPathComplete();
      }
    });
  }

  void _onPathComplete() {
    // Clear all paths and stop movement
    setState(() {
      _isMoving = false;
      _movementTimer?.cancel();
      _markers
          .removeWhere((marker) => marker.markerId == const MarkerId('car'));
    });
  }

  Future<void> _addCarMarker(bool isSelectedSegment) async {
    setState(() {
      _markers.add(Marker(
        markerId: const MarkerId('car'),
        position: _carPosition,
        icon: isSelectedSegment
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
            : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
    });
  }

  void _showRoutesDialog() {
    List<int> selectedSegments = [];
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select One or More Routes to Spray'),
              content: Container(
                width: double.minPositive,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: (_dronepath.length - 1) ~/ 2,
                        itemBuilder: (BuildContext context, int index) {
                          int routeNumber = index + 1;
                          bool isSelected = selectedSegments.contains(index);
                          return CheckboxListTile(
                            title: Text('Route #$routeNumber'),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  selectedSegments.add(index);
                                } else {
                                  selectedSegments.remove(index);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () {
                            setState(() {
                              selectedSegments = List.generate(
                                (_dronepath.length - 1) ~/ 2,
                                (i) => i,
                              );
                            });
                          },
                          child: const Text('Select All'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            List<List<LatLng>> selectedPaths = [];
                            double totalDistance = 0.0;
                            for (int index in selectedSegments) {
                              int startIndex = index * 2;
                              List<LatLng> segment = _dronepath.sublist(
                                startIndex,
                                startIndex + 2,
                              );
                              selectedPaths.add(segment);
                              double segmentDistance =
                                  calculate_selcted_segemnt_distance(segment);
                              totalDistance += segmentDistance;
                            }
                            _totalDistanceKM =
                                totalDistance; // Distance in kilometers
                            FirebaseDatabase.instance
                                .ref()
                                .child('totalDistance')
                                .set(_totalDistanceKM);
                            _storeTimeDurationInDatabase(_totalDistanceKM);
                            setState(() {
                              _selectedPathsQueue.addAll(selectedPaths);
                            });
                            if (!_isMoving) {
                              _startMovement(
                                  _dronepath); // Start movement with the full path
                            }
                          },
                          child: const Text('Start Routing'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void dronepath_Horizontal(List<LatLng> polygon, double pathWidth) {
    if (polygon.isEmpty) return;
    List<LatLng> sortedPoints = List.from(polygon);
    sortedPoints.sort((a, b) => a.latitude.compareTo(b.latitude));
    double minLat = sortedPoints.first.latitude;
    double maxLat = sortedPoints.last.latitude;
    List<LatLng> dronepath = [];
    bool leftToRight = true;
    for (double lat = minLat; lat <= maxLat; lat += pathWidth / 111111) {
      List<LatLng> intersections = [];
      for (int i = 0; i < polygon.length; i++) {
        LatLng p1 = polygon[i];
        LatLng p2 = polygon[(i + 1) % polygon.length];
        if ((p1.latitude <= lat && p2.latitude >= lat) ||
            (p1.latitude >= lat && p2.latitude <= lat)) {
          double lng = p1.longitude +
              (lat - p1.latitude) *
                  (p2.longitude - p1.longitude) /
                  (p2.latitude - p1.latitude);
          intersections.add(LatLng(lat, lng));
        }
      }
      if (intersections.length == 2) {
        intersections.sort((a, b) => a.longitude.compareTo(b.longitude));
        if (leftToRight) {
          dronepath.addAll(intersections);
        } else {
          dronepath.addAll(intersections.reversed);
        }
        leftToRight = !leftToRight;
      }
    }
    double totalDistancezigzagKm = _calculateTotalDistanceZIGAG(dronepath);

    setState(() {
      _dronepath = dronepath; // Update the state with the new drone path
      _polylines.add(Polyline(
        polylineId: const PolylineId('dronepath'),
        points: dronepath,
        color: Colors.red,
        width: 3,
      ));
      totalZigzagPathKm = totalDistancezigzagKm; // Update the distance here
    });
  }

  void dronepath_Vertical(List<LatLng> polygon, double pathWidth) {
    if (polygon.isEmpty) return;
    List<LatLng> sortedPoints = List.from(polygon);
    sortedPoints.sort((a, b) => a.longitude.compareTo(b.longitude));
    double minLng = sortedPoints.first.longitude;
    double maxLng = sortedPoints.last.longitude;
    List<LatLng> dronepath = [];
    bool bottomToTop = true;
    for (double lng = minLng; lng <= maxLng; lng += pathWidth / 111111) {
      List<LatLng> intersections = [];
      for (int i = 0; i < polygon.length; i++) {
        LatLng p1 = polygon[i];
        LatLng p2 = polygon[(i + 1) % polygon.length];
        if ((p1.longitude <= lng && p2.longitude >= lng) ||
            (p1.longitude >= lng && p2.longitude <= lng)) {
          double lat = p1.latitude +
              (lng - p1.longitude) *
                  (p2.latitude - p1.latitude) /
                  (p2.longitude - p1.longitude);
          intersections.add(LatLng(lat, lng));
        }
      }
      if (intersections.length == 2) {
        intersections.sort((a, b) => a.latitude.compareTo(b.latitude));
        if (bottomToTop) {
          dronepath.addAll(intersections);
        } else {
          dronepath.addAll(intersections.reversed);
        }
        bottomToTop = !bottomToTop;
      }
    }
    double totalDistancezigzagKm = _calculateTotalDistanceZIGAG(dronepath);

    setState(() {
      _dronepath = dronepath; // Update the state with the new drone path
      _polylines.add(Polyline(
        polylineId: const PolylineId('dronepath'),
        points: dronepath,
        color: Colors.red,
        width: 3,
      ));
      totalZigzagPathKm = totalDistancezigzagKm; // Update the distance here
    });
  }

  void Selecting_Path_Direction_and_Turn() {
    double turnLength = 10.0; // Default turn length
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title:
                  const Text('Enter Turn Length (meters) default is 10 meters'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      turnLength = double.tryParse(value) ?? 10.0;
                    },
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Radio<PathDirection>(
                        value: PathDirection.horizontal,
                        groupValue: _selectedDirection,
                        onChanged: (PathDirection? value) {
                          setState(() {
                            _selectedDirection = value!;
                          });
                        },
                      ),
                      const Text('Horizontal'),
                      Radio<PathDirection>(
                        value: PathDirection.vertical,
                        groupValue: _selectedDirection,
                        onChanged: (PathDirection? value) {
                          setState(() {
                            _selectedDirection = value!;
                          });
                        },
                      ),
                      const Text('Vertical'),
                    ],
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _closePolygon(turnLength);
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _closePolygon(double turnLength) async {
    setState(() {
      _polylines.clear();
      _polygons.add(Polygon(
        polygonId: const PolygonId('polygon'),
        points: _markerPositions,
        strokeColor: Colors.blue,
        strokeWidth: 3,
        fillColor: Colors.blue.withOpacity(0.2),
      ));
    });
    if (_selectedDirection == PathDirection.horizontal) {
      dronepath_Horizontal(_markerPositions, turnLength);
    } else {
      dronepath_Vertical(_markerPositions, turnLength);
      double area = _calculateSphericalPolygonArea(_markerPositions);
      try {
        await _databaseReference.child('Area').set(area);
      } catch (e) {
        print('Error updating area in database: $e');
      }
    }
  }

  bool _isSegmentSelected(List<LatLng> path, int index) {
    if (index < path.length - 1) {
      List<LatLng> segment = path.sublist(index, index + 2);
      for (List<LatLng> selectedSegment in _selectedPathsQueue) {
        if (_isSegmentEqual(segment, selectedSegment)) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isSegmentEqual(List<LatLng> segment1, List<LatLng> segment2) {
    if (segment1.length != segment2.length) {
      return false;
    }
    for (int i = 0; i < segment1.length; i++) {
      if (segment1[i] != segment2[i]) {
        return false;
      }
    }
    return true;
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

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _hideKeyboard() {
    FocusScope.of(context).previousFocus();
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
                            polygons: _polygons,
                            zoomGesturesEnabled: true,
                            rotateGesturesEnabled: true,
                            buildingsEnabled: true,
                            scrollGesturesEnabled: true,
                            onTap: _onMapTap,
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
                                  icon: Icon(Icons.search,
                                      color:
                                          Colors.black), // Customize icon color
                                  onPressed:
                                      _hideKeyboard, // Hide keyboard on search button press
                                ),
                                contentPadding: EdgeInsets.symmetric(
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
                                  _googleMapController?.animateCamera(
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
                    Positioned(
                      top: 70,
                      right: 45,
                      child: ElevatedButton(
                        onPressed: () => _showRoutesDialog(),
                        child: const Text('Start'),
                      ),
                    ),
                    if (_polygons.isNotEmpty)
                      Positioned(
                        top: 70,
                        left: 5,
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: Colors.blueGrey,
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Area: ${_calculateSphericalPolygonArea(_markerPositions).toStringAsFixed(2)} acres",
                                style: const TextStyle(
                                  color: Colors.teal,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                "Total Path Dis.: ${totalZigzagPathKm.toStringAsFixed(2)} Km",
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                "Reamining Path Dis.: ${_remainingDistanceKM_TotalPath.toStringAsFixed(2)} Km",
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                "Selected Path Dis.: ${_totalDistanceKM.toStringAsFixed(2)} Km",
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                "Reamaining Selected Path Dis.: ${_remainingDistanceKM_SelectedPath.toStringAsFixed(2)} Km",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                "TIme Taken to Spray: ${timeduration.toStringAsFixed(2)} min",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                "Remaining Time: ${TLM.toStringAsFixed(2)} min",
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Text(
                                "UGV Speed: 10m/s",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.deepPurple,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
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
    );
  }

  void _updateRouteData() {
    try {
      for (int i = 0; i < _markers.length; i++) {
        // Calculate the next index, wrapping around at the end of the list
        int nextIndex = (i + 1) % _markers.length;
        // Retrieve start and end coordinates
        LatLng startLatLng = _markers[i].position;
        LatLng endLatLng = _markers[nextIndex].position;
        // Determine the route name
        String routeName = 'M${i + 1} to M${nextIndex + 1}';
        // Create the data structure
        Map<String, dynamic> routeData = {
          'start': {
            'latitude': startLatLng.latitude.toStringAsFixed(8),
            'longitude': startLatLng.longitude.toStringAsFixed(8),
          },
          'end': {
            'latitude': endLatLng.latitude.toStringAsFixed(8),
            'longitude': endLatLng.longitude.toStringAsFixed(8),
          },
        };
        // Update the database with the route data
        _databaseReference.child('Route').child(routeName).set(routeData);
        // Print the route name for verification
      }
    } catch (e) {
      print('Error updating route data: $e');
    }
  }

  void _updatePolylines() {
    _polylines.clear();
    if (_markerPositions.length > 1) {
      for (int i = 0; i < _markerPositions.length - 1; i++) {
        _polylines.add(Polyline(
          polylineId: PolylineId('route$i'),
          points: [_markerPositions[i], _markerPositions[i + 1]],
          color: Colors.blue,
          width: 3,
        ));
      }
    }
  }

  void _onMapTap(LatLng latLng) {
    final markerId = MarkerId('M${_markers.length + 1}');
    final newMarker = Marker(
      markerId: markerId,
      position: latLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      onTap: () {
        if (_markers.length > 2 && latLng == _markers.first.position) {
          Selecting_Path_Direction_and_Turn();
        }
      },
    );
    setState(() {
      _markers.add(newMarker);
      _markerPositions.add(latLng);
      if (_markers.length > 1) {
        _updatePolylines();
        _updateRouteData();
      }
    });
  }
//update polylines

//area calculation of field
  double _calculateSphericalPolygonArea(List<LatLng> points) {
    const double radiusOfEarth = 6378137.0; // Earth's radius in meters
    double totalArea = 0.0;

    // Calculate the area of each triangle and sum them up
    for (int i = 0; i < points.length - 2; i++) {
      LatLng p1 = points[0];
      LatLng p2 = points[i + 1];
      LatLng p3 = points[i + 2];

      double lat1 = p1.latitude * pi / 180.0;
      double lon1 = p1.longitude * pi / 180.0;
      double lat2 = p2.latitude * pi / 180.0;
      double lon2 = p2.longitude * pi / 180.0;
      double lat3 = p3.latitude * pi / 180.0;
      double lon3 = p3.longitude * pi / 180.0;

      // Convert to Cartesian coordinates
      double x1 = radiusOfEarth * cos(lat1) * cos(lon1);
      double y1 = radiusOfEarth * cos(lat1) * sin(lon1);
      double z1 = radiusOfEarth * sin(lat1);
      double x2 = radiusOfEarth * cos(lat2) * cos(lon2);
      double y2 = radiusOfEarth * cos(lat2) * sin(lon2);
      double z2 = radiusOfEarth * sin(lat2);
      double x3 = radiusOfEarth * cos(lat3) * cos(lon3);
      double y3 = radiusOfEarth * cos(lat3) * sin(lon3);
      double z3 = radiusOfEarth * sin(lat3);

      // Calculate thearea of the triangle using the formula: (1/2) * |(x2 - x1)(y3 - y1) - (x3 - x1)(y2 - y1)|
      double area = 0.5 * ((x2 - x1) * (y3 - y1) - (x3 - x1) * (y2 - y1));

      totalArea += area.abs();
    }

    // Convert area to acres
    double areaInSquareMeters = totalArea;
    double areaInAcres = areaInSquareMeters * 0.000247105;

    return areaInAcres;
  }
/* DEFAULT APPROCH double _calculateSphericalPolygonArea(List<LatLng> points) {
    const double radiusOfEarth = 6378137.0; // Earth's radius in meters
    double total = 0.0;
    int numPoints = points.length;

    for (int i = 0; i < numPoints; i++) {
      LatLng p1 = points[i];
      LatLng p2 = points[(i + 1) % numPoints];

      double lat1 = p1.latitude * pi / 180.0;
      double lon1 = p1.longitude * pi / 180.0;
      double lat2 = p2.latitude * pi / 180.0;
      double lon2 = p2.longitude * pi / 180.0;

      total += (lon2 - lon1) * (2 + sin(lat1) + sin(lat2));
    }

    total = total.abs() * radiusOfEarth * radiusOfEarth / 2.0;

    // Convert area to acres
    double areaInSquareMeters = total;
    double areaInAcres = areaInSquareMeters * 0.000247105;

    return areaInAcres;
  }*/
//below stripping the triagle emthod to find area was used but unseccesfull results
/*
  double _calculateSphericalPolygonArea(List<LatLng> points) {
    const double radiusOfEarth = 6378137.0; // Earth's radius in meters
    double totalArea = 0.0;
    int numPoints = points.length;

    if (numPoints < 3) {
      return 0.0; // Not a polygon
    }

    for (int i = 0; i < numPoints - 2; i++) {
      double area = _calculateSphericalTriangleArea(
          points[i],
          points[i + 1],
          points[i + 2],
          radiusOfEarth
      );
      totalArea += area;
    }

    // Convert area to acres
    double areaInAcres = totalArea * 0.000247105;

    return areaInAcres;
  }
  double _calculateAngle(double lat1, double lon1, double lat2, double lon2, double lat3, double lon3) {
    double dLon1 = lon2 - lon1;
    double dLon2 = lon3 - lon2;
    double dLon3 = lon3 - lon1;

    double tan1 = tan(lat1 / 2.0 + pi / 4.0);
    double tan2 = tan(lat2 / 2.0 + pi / 4.0);
    double tan3 = tan(lat3 / 2.0 + pi / 4.0);

    double delta1 = atan2(sin(dLon1) * tan2, tan1 * tan3 - cos(dLon1));
    double delta2 = atan2(sin(dLon2) * tan3, tan2 * tan1 - cos(dLon2));
    double delta3 = atan2(sin(dLon3) * tan1, tan3 * tan2 - cos(dLon3));

    return (delta1 + delta2 + delta3).abs();
  }

  double _calculateSphericalTriangleArea(LatLng p1, LatLng p2, LatLng p3, double radiusOfEarth) {
    double lat1 = p1.latitude * pi / 180.0;
    double lon1 = p1.longitude * pi / 180.0;
    double lat2 = p2.latitude * pi / 180.0;
    double lon2 = p2.longitude * pi / 180.0;
    double lat3 = p3.latitude * pi / 180.0;
    double lon3 = p3.longitude * pi / 180.0;

    // Use the spherical excess formula to calculate the area of a spherical triangle
    double angle1 = _calculateAngle(lat1, lon1, lat2, lon2, lat3, lon3);
    double angle2 = _calculateAngle(lat2, lon2, lat3, lon3, lat1, lon1);
    double angle3 = _calculateAngle(lat3, lon3, lat1, lon1, lat2, lon2);

    double sphericalExcess = angle1 + angle2 + angle3 - pi;

    double triangleArea = sphericalExcess * radiusOfEarth * radiusOfEarth;
    return triangleArea;
  }*/
}
