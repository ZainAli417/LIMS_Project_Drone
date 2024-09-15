import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:geocoding/geocoding.dart' as geocoding; // Prefixed geocoding
import 'package:geocoding/geocoding.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:location/location.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/services.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';
import 'package:project_drone/Screens/homescreen.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:location/location.dart' as gps; // Prefixed location
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import '../Constant/ISSAASProvider.dart';
import '../Constant/controller_weather.dart';
import '../shared_state.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:http/http.dart' as http;
import 'LoginScreen.dart';


enum PathDirection { horizontal, vertical }

class Fetch_Input extends StatefulWidget {
  // final YoutubePlayerController controller;
  final bool isManualControl; // Accept the boolean parameter
  const Fetch_Input(
      {Key? key, /*required this.controller*/ required this.isManualControl})
      : super(key: key);
  @override
  _Fetch_InputState createState() => _Fetch_InputState();
}

class _Fetch_InputState extends State<Fetch_Input> {
  final GlobalKey _googleMapKey = GlobalKey(); // Key to capture GoogleMap
  final ScreenshotController _screenshotController = ScreenshotController();
  Timer? _debounce;
  final FocusNode _focusNode = FocusNode();
  int drone_direct = 0;
  // UP = 3
  // Down = 4
  // Left = 1
  // Right = 2
  // Stop = 0
  late BitmapDescriptor ugv_active;
  late BitmapDescriptor ugv_dead;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showInputSelectionPopup();
    });
    _checkCityAndFetchData();

    _requestLocationPermission();
    _initializeFirebaseListener();
    if (_markers.isNotEmpty) {
      selectedMarker = _markers.first.position;
    }
    _carPosition = LatLng(0, 0); // Initialize with a default value
    _loadCarIcons();




  }

  void dispose() {
    _debounce?.cancel();
    _movementTimer?.cancel(); // Add this line
    super.dispose();
  }
//DEFAULT and Variables
  LatLng _currentPosition = LatLng(0, 0); // Default position
  late DatabaseReference _latRef;
  late DatabaseReference _longRef;
  late Stream<DatabaseEvent> _latStream;
  late Stream<DatabaseEvent> _longStream;
  PathDirection _selectedDirection = PathDirection.horizontal;


  //BOOL VARIABLE FOR COUSTOM MODES
  bool _isFullScreen = false;
  bool _isbackwardPressed = false;
  bool _isStop = false;
  bool _isLeftPressed = false;
  bool _isRightPressed = false;
  bool _isforwardPressed = false;
  bool _isMoving = false;
  bool _isConfirmed = false;
  bool _ismanual = false;


  late LatLng _carPosition;
  int _currentPointIndex = 0;
  final gps.Location _location = gps.Location(); // Use the prefixed `gps.Location`
  LocationData? _currentLocation;

  //POLYGONS and LIST
  Set<Polygon> _buildingPolygons = {};
  final List<List<LatLng>> _selectedPathsQueue = [];
  List<List<LatLng>> _allPaths = []; // Initialize _allPaths here
  late List<List<LatLng>> selectedSegments;
  late List<Marker> _markers = [];
  final List<LatLng> _markerPositions = [];
  Set<Polyline> _polylines = {};
  Set<Polygon> polygons = {};
  List<LatLng> _dronepath = [];
  double _totalDistanceKM = 0.0;
  double _remainingDistanceKM_SelectedPath = 0.0;
  double distanceTraveled = 0.0;
  double totalZigzagPathKm = 0.0;
  double TLM = 0.0;
  String direction = ""; // Can be "forward" or "backward"
  double speed = 10.0; // meters per second
  double totalDistanceCoveredKM_SelectedPath = 0.0;
  double distanceCoveredInWholeJourney = 0.0;
  double segmentDistanceCoveredKM = 0.0;
  double updateInterval = 0.1; // seconds
  VoidCallback? _controllerButtonListener; // Fix 1

  double pathWidth = 10.0;
  bool _isHorizontalDirection = false;
  late LatLng? selectedMarker =
  _markers.isNotEmpty ? _markers.first.position : null;

  late GoogleMapController _googleMapController;
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.ref();
  Timer? _movementTimer;
  bool _isCustomMode = false;
  bool _isShapeClosed = false;
  double _remainingDistanceKM_TotalPath = 0.0;
  List<LatLng> polygonPoints = [];
  final WeatherController weatherController = Get.put(WeatherController());
  MarkerId? _selectedMarkerId; // Add this to track the selected marker

  //USER SELECTION RECEIPT
  String? _selectedLocalFilePath;
  String _selectedMethod = 'N/A'; // Variable to store selected method
  String? _selectedFileSource =
      'N/A in Manual Mode'; // To store the file source (Local or Cloud)
  String? _selectedLocalFile =
      'N/A in Manual Mode'; // To store the selected local file
  String? _selectedCloudFile =
      'N/A in Manual Mode'; // To store the selected cloud file
  double _turnLength = 5.0; // To store turn length
  LatLng? _selectedStartingPoint;

  String get message => 'Cannot place marker on buildings. Please select a plain area';


  void _resetMarkers() async {
    setState(() {
      // Reset to default values

      // Reset other variables and clear data
      _isMoving = false;
      _isConfirmed = false;
      _isShapeClosed = false;
      _ismanual = false;
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
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (BuildContext context) => widget),
    );
  }
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




  void _startMovement(List<LatLng> path, List<List<LatLng>> selectedSegments) {
    if (path.isEmpty || _selectedStartingPoint == null) {
      print(
          "Path is empty or starting point not selected, cannot start movement");
      return;
    }
    _isMoving = true;

    // Find the nearest point on the path to the selected starting point
    int startingPointIndex =
    _findClosestPointIndex(path, _selectedStartingPoint!);

    // Set the car's initial position to the selected starting point
    setState(() {
      _carPosition = path[startingPointIndex]; // Start from the closest point
      _currentPointIndex = startingPointIndex;
    });

    // Decide the direction-specific marker function
    Add_Car_Marker(_isSegmentSelected(
        path, selectedSegments, _currentPointIndex, PathDirection.horizontal));


    // Determine movement direction based on starting point
    bool movingForward = startingPointIndex < path.length / 2;

    // Start movement with timer
    _movementTimer = Timer.periodic(
        Duration(milliseconds: (updateInterval * 1000).toInt()), (timer) async {
      if (_isMoving) {
        if (movingForward) {
          if (_currentPointIndex < path.length - 1) {
            LatLng start = path[_currentPointIndex];
            LatLng end = path[_currentPointIndex + 1];
            double segmentDistanceKM = calculateonelinedistance(start, end);
            double distanceCoveredInThisTickKM =
                (speed * updateInterval) / 1000.0;
            segmentDistanceCoveredKM += distanceCoveredInThisTickKM;
            double segmentProgress =
            (segmentDistanceCoveredKM / segmentDistanceKM).clamp(0.0, 1.0);
            _carPosition = _lerpLatLng(start, end, segmentProgress);

            bool isSelectedSegment = _isSegmentSelected(
              path,
              selectedSegments,
              _currentPointIndex,
              _isHorizontalDirection
                  ? PathDirection.horizontal
                  : PathDirection.vertical,
            );

            distanceCoveredInWholeJourney += distanceCoveredInThisTickKM;

            if (isSelectedSegment) {
              totalDistanceCoveredKM_SelectedPath +=
                  distanceCoveredInThisTickKM;
              double remainingDistanceKM_SelectedPath =
                  _totalDistanceKM - totalDistanceCoveredKM_SelectedPath;
              setState(() {
                _remainingDistanceKM_SelectedPath =
                    remainingDistanceKM_SelectedPath.clamp(
                        0.0, _totalDistanceKM);
                _storeTimeLeftInDatabase(_remainingDistanceKM_SelectedPath);
              });

              if (totalDistanceCoveredKM_SelectedPath % 0.5 == 0) {
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

            // Update car marker position
            setState(() {
              _markers.removeWhere(
                      (marker) => marker.markerId == const MarkerId('car'));
              Add_Car_Marker(isSelectedSegment);

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
        } else {
          if (_currentPointIndex > 0) {
            LatLng start = path[_currentPointIndex];
            LatLng end = path[_currentPointIndex - 1];
            double segmentDistanceKM = calculateonelinedistance(start, end);
            double distanceCoveredInThisTickKM =
                (speed * updateInterval) / 1000.0;
            segmentDistanceCoveredKM += distanceCoveredInThisTickKM;
            double segmentProgress =
            (segmentDistanceCoveredKM / segmentDistanceKM).clamp(0.0, 1.0);
            _carPosition = _lerpLatLng(start, end, segmentProgress);

            bool isSelectedSegment = _isSegmentSelected(
              path,
              selectedSegments,
              _currentPointIndex - 1,
              _isHorizontalDirection
                  ? PathDirection.horizontal
                  : PathDirection.vertical,
            );

            distanceCoveredInWholeJourney += distanceCoveredInThisTickKM;

            if (isSelectedSegment) {
              totalDistanceCoveredKM_SelectedPath +=
                  distanceCoveredInThisTickKM;
              double remainingDistanceKM_SelectedPath =
                  _totalDistanceKM - totalDistanceCoveredKM_SelectedPath;
              setState(() {
                _remainingDistanceKM_SelectedPath =
                    remainingDistanceKM_SelectedPath.clamp(
                        0.0, _totalDistanceKM);
                _storeTimeLeftInDatabase(_remainingDistanceKM_SelectedPath);
              });

              if (totalDistanceCoveredKM_SelectedPath % 0.5 == 0) {
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

            // Update car marker position
            setState(() {
              _markers.removeWhere(
                      (marker) => marker.markerId == const MarkerId('car'));

              Add_Car_Marker(isSelectedSegment);

              if (segmentProgress >= 1.0) {
                _currentPointIndex--;
                segmentDistanceCoveredKM = 0.0;
              }
            });

            if (_currentPointIndex <= 0) {
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
        }
      }
    });
  }






// Helper function to find the closest point in the path to the selected starting point
  /*int _findClosestPointIndex(List<LatLng> path, LatLng startingPoint) {
    if (path.isEmpty) return -1; // No path, return invalid index

    int closestIndex = 0;
    double closestDistance = calculateonelinedistance(path[0], startingPoint);

    for (int i = 1; i < path.length; i++) {
      double distance = calculateonelinedistance(path[i], startingPoint);

      // Compare and find the smallest distance
      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = i;
      }
    }

    return closestIndex; // Return the index of the closest point
  }*/

  int _findClosestPointIndex(List<LatLng> path, LatLng targetPoint) {
    int closestPointIndex = 0;
    double closestDistance = double.infinity;

    for (int i = 0; i < path.length; i++) {
      double distance = calculateonelinedistance(path[i], targetPoint);

      if (distance < closestDistance) {
        closestDistance = distance;
        closestPointIndex = i;
      }
    }

    return closestPointIndex;
  }

  void Selecting_Path_Direction_and_Turn() {
    bool isStartingPointEmpty = false; // Validation flag for the dropdown

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              titlePadding: EdgeInsets.zero,
              title: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.indigo[800],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Text(
                  'Enter settings',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Enter Turn Length (Default 5.0m)',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[800],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.indigo),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: TextField(
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          _turnLength = double.tryParse(value) ?? 5.0;
                        });
                      },
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: _turnLength.toString(),
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.black45,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: [
                      Text(
                        'Choose Path Direction',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.red[800],
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Radio<PathDirection>(
                            value: PathDirection.horizontal,
                            groupValue: _selectedDirection,
                            onChanged: (PathDirection? value) {
                              setState(() {
                                _selectedDirection = value!;
                                _isHorizontalDirection =
                                (value == PathDirection.horizontal);
                              });
                            },
                          ),
                          Text(
                            'Horizontal',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                          Radio<PathDirection>(
                            value: PathDirection.vertical,
                            groupValue: _selectedDirection,
                            onChanged: (PathDirection? value) {
                              setState(() {
                                _selectedDirection = value!;
                                _isHorizontalDirection =
                                (value == PathDirection.horizontal);
                              });
                            },
                          ),
                          Text(
                            'Vertical',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Choose Starting Point',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.red[800],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.indigo),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButton<LatLng>(
                      value: _selectedStartingPoint,
                      isExpanded: true,
                      items: (_isCustomMode
                          ? _markers
                          : _markers.sublist(0, _markers.length - 1))
                          .map((marker) {
                        return DropdownMenuItem<LatLng>(
                          value: marker.position,
                          child: Text(marker.markerId.value),
                        );
                      }).toList(),
                      onChanged: (LatLng? newValue) {
                        setState(() {
                          _selectedStartingPoint = newValue;
                          _selectedMarkerId = _markers
                              .firstWhere(
                                  (marker) => marker.position == newValue)
                              .markerId;
                          isStartingPointEmpty = false; // Reset error state

                          // Update marker colors
                          _markers = _markers.map((marker) {
                            if (marker.markerId == _selectedMarkerId) {
                              return marker.copyWith(
                                iconParam:
                                BitmapDescriptor.defaultMarkerWithHue(
                                    BitmapDescriptor.hueGreen),
                              );
                            } else {
                              return marker.copyWith(
                                iconParam:
                                BitmapDescriptor.defaultMarkerWithHue(
                                    BitmapDescriptor.hueAzure),
                              );
                            }
                          }).toList();
                        });
                      },
                    ),
                  ),
                  if (isStartingPointEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        'Starting point is Required',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.red[600],
                        ),
                      ),
                    ),
                ],
              ),
              actions: <Widget>[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[800],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    if (_selectedStartingPoint == null) {
                      setState(() {
                        isStartingPointEmpty = true; // Show error message
                      });
                    } else {
                      Navigator.of(context).pop();
                      LatLng initialPosition = _selectedStartingPoint!;
                      extractLatLngPoints();
                      if (_selectedDirection == PathDirection.vertical) {
                        _isHorizontalDirection = false; // Set direction flag
                        dronepath_Vertical(
                            polygonPoints, pathWidth, _selectedStartingPoint!);
                      } else {
                        _isHorizontalDirection = true; // Set direction flag
                        dronepath_Horizontal(
                            polygonPoints, pathWidth, _selectedStartingPoint!);
                      }

                      _closePolygon(_turnLength);
                      setup_hardware();
                    }
                  },
                  child: Center(
                    child: Text(
                      'Generate Path',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
  void _onPathComplete() {
    // Clear all paths and stop movement
    setState(() {
      _isMoving = false;
      _movementTimer?.cancel();
      _markers
          .removeWhere((marker) => marker.markerId == const MarkerId('car'));
    });

    _screenshotController.capture().then((Uint8List? capturedBytes) {
      if (capturedBytes != null) {
        // Trigger the success dialog with the screenshot
        ShowSuccessDialog(capturedBytes);
      }
    }).catchError((e) {
      print('Error capturing screenshot: $e');
    });
  }
// Check if the current segment is part of the selected route
  bool _isSegmentSelected(List<LatLng> path,List<List<LatLng>> selectedSegments, int index, PathDirection direction) {
    if (index < path.length - 1) {
      LatLng start = path[index];
      LatLng end = path[index + 1];

      for (var segment in selectedSegments) {
        bool isMatch = false;
        if (direction == PathDirection.horizontal) {
          isMatch = _isHorizontalSegmentEqual([start, end], segment);
        } else if (direction == PathDirection.vertical) {
          isMatch = _isVerticalSegmentEqual([start, end], segment);
        }
        if (isMatch) {
          return true;
        }
      }
    }
    return false;
  }
  Future<void> _loadCarIcons() async {
    // Load the image from your assets
    const ImageConfiguration imageConfiguration = ImageConfiguration(
      size: Size(20, 20),
    );
    ugv_active = await BitmapDescriptor.fromAssetImage(
      imageConfiguration,

      'images/ugv_active.png', // Replace with your actual asset path
    );
    ugv_dead = await BitmapDescriptor.fromAssetImage(
      imageConfiguration,
      'images/ugv_dead.png', // Replace with your actual asset path
      //'images/ugv_active.png', // Replace with your actual asset path
    );
  }
  Future<void> Add_Car_Marker(bool isSelectedSegment) async {
    setState(() {
      _markers.add(Marker(
        markerId: const MarkerId('car'),
        position: LatLng(_carPosition.latitude, _carPosition.longitude),
        icon: isSelectedSegment
            ? ugv_active
            : ugv_dead, // Set the car marker based on the segment selection
      ));
    });
  }
// Check if two horizontal segments are equal
  bool _isHorizontalSegmentEqual(List<LatLng> segment1, List<LatLng> segment2) {
    return (segment1[0].latitude == segment2[0].latitude &&
        segment1[1].latitude == segment2[1].latitude &&
        (segment1[0].longitude == segment2[0].longitude &&
            segment1[1].longitude == segment2[1].longitude ||
            segment1[0].longitude == segment2[1].longitude &&
                segment1[1].longitude == segment2[0].longitude)) ||
        (segment1[0].latitude == segment2[1].latitude &&
            segment1[1].latitude == segment2[0].latitude &&
            (segment1[0].longitude == segment2[0].longitude &&
                segment1[1].longitude == segment2[1].longitude ||
                segment1[0].longitude == segment2[1].longitude &&
                    segment1[1].longitude == segment2[0].longitude));
  }
// Check if two vertical segments are equal
  bool _isVerticalSegmentEqual(List<LatLng> segment1, List<LatLng> segment2) {
    return (segment1[0].longitude == segment2[0].longitude &&
        segment1[1].longitude == segment2[1].longitude &&
        (segment1[0].latitude == segment2[0].latitude &&
            segment1[1].latitude == segment2[1].latitude ||
            segment1[0].latitude == segment2[1].latitude &&
                segment1[1].latitude == segment2[0].latitude)) ||
        (segment1[0].longitude == segment2[1].longitude &&
            segment1[1].longitude == segment2[0].longitude &&
            (segment1[0].latitude == segment2[0].latitude &&
                segment1[1].latitude == segment2[1].latitude ||
                segment1[0].latitude == segment2[1].latitude &&
                    segment1[1].latitude == segment2[0].latitude));
  }
  void ShowSuccessDialog(Uint8List screenshotBytes) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          titlePadding: EdgeInsets.zero, // Remove default padding
          title: Container(
            padding: const EdgeInsets.fromLTRB(
                10, 5, 10, 5), // Adjust padding inside the header
            decoration: BoxDecoration(
              color: Colors.indigo[800], // Indigo background color for header
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20), // Rounded corners for the top
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Spraying Operation Completed',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Colors.white, // White text for better contrast
                  ),
                ),
              ],
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.memory(screenshotBytes), // Display the screenshot
              const SizedBox(height: 5), // Space between image and button
            ],
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo[800],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const MyHomePage()),
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_to_home_screen_outlined,
                      color: Colors.white), // Add the home icon
                  const SizedBox(width: 10), // Space between icon and text
                  Text(
                    'Go Back to Home',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
  void setup_hardware() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SizedBox(
          width: 500, // Adjust the width

          height: 700, // Adjust the height

          child: AlertDialog(
            backgroundColor: Colors.white,

            titlePadding: EdgeInsets.zero, // Remove default padding

            title: Container(
              padding: const EdgeInsets.fromLTRB(
                  10, 5, 10, 5), // Adjust padding inside the header

              decoration: BoxDecoration(
                color: Colors.indigo[800], // Indigo background color for header

                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20), // Rounded corners for the top

                  topRight: Radius.circular(20),
                ),
              ),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Settings',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white, // White text for better contrast
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close,
                        color: Colors.white), // White close icon
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Your Coordinate Method: ',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.black, // Black color for the label
                        ),
                      ),
                      TextSpan(
                        text: _selectedMethod,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors
                              .indigo[800], // Indigo color for the method value
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Your File Selection Mode: ',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.black, // Black color for the label
                        ),
                      ),
                      TextSpan(
                        text: _selectedFileSource,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo[
                          800], // Indigo color for the file source value
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Your Selected File: ',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.black, // Black color for the label
                        ),
                      ),
                      TextSpan(
                        text:
                        _selectedLocalFile ?? _selectedCloudFile ?? 'None',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo[
                          800], // Indigo color for the selected file value
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Your Turn Length: ',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.black, // Black color for the label
                        ),
                      ),
                      TextSpan(
                        text: _turnLength.toStringAsFixed(
                            1), // Format the double to 2 decimal places
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo[
                          800], // Indigo color for the turn length value
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Your Path Direction: ',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.black, // Black color for the label
                        ),
                      ),
                      TextSpan(
                        text: _selectedDirection == PathDirection.horizontal
                            ? 'Horizontal'
                            : 'Vertical',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo[
                          800], // Indigo color for the path direction value
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Your Starting Point is: ',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: Colors.black, // Black color for the label
                        ),
                      ),
                      TextSpan(
                        text: _selectedStartingPoint != null
                            ? 'Lat: ${_selectedStartingPoint!.latitude.toStringAsFixed(3)}, Lng: ${_selectedStartingPoint!.longitude.toStringAsFixed(3)}'
                            : 'None',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo[
                          800], // Indigo color for the starting point value
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 110, // Set the width of the button
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF037441),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(); // Close the dialog
                        Selecting_Path_Direction_and_Turn(); // Call function to select path direction and turn
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Text(
                            'Edit',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(
                              width: 9), // Reduced space between icon and text
                          const Icon(Icons.edit,
                              color: Colors.white,
                              size: 16), // Reduced icon size
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 133, // Set the width of the button
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop(); // Close the dialog

                        // Check the selected direction and call the appropriate function
                        if (_selectedDirection == PathDirection.vertical) {
                          _showVerticalRoutesDialog(); // Call vertical path dialog
                        } else {
                          _showHorizontalRoutesDialog(); // Call horizontal path dialog
                        }
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Text(
                            'Proceed',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(
                              width: 9), // Reduced space between icon and text
                          const Icon(Icons.arrow_forward_ios,
                              color: Colors.white,
                              size: 16), // Reduced icon size
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
  void _showHorizontalRoutesDialog() {
    List<int> selectedSegments = [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              titlePadding: EdgeInsets.zero,
              title: Center(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                  decoration: BoxDecoration(
                    color: Colors.indigo[800],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select One or More Routes to Spray',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              content: SizedBox(
                width: 700,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          // Select all routes
                          selectedSegments = List.generate(
                            _dronepath.length ~/ 2,
                                (i) => i,
                          );
                        });
                      },
                      child: Text(
                        'Select All Routes',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _dronepath.length ~/ 2,
                        itemBuilder: (BuildContext context, int index) {
                          int routeNumber = index + 1;
                          bool isSelected = selectedSegments.contains(index);

                          return CheckboxListTile(
                            title: Text(
                              'Route #$routeNumber',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
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
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {


                        if (selectedSegments.isEmpty)
                        {
                          _showWarningDialog(context);
                          return;
                        }
                        else
                        {
                          Navigator.of(context).pop();
                        }

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

                        _totalDistanceKM = totalDistance;
                        FirebaseDatabase.instance
                            .ref()
                            .child('totalDistance')
                            .set(_totalDistanceKM);
                        _storeTimeDurationInDatabase(_totalDistanceKM);

                        setState(() {
                          _selectedPathsQueue.clear();
                          _selectedPathsQueue.addAll(selectedPaths);

                          // Update polyline colors
                          _updatePolylineColors(selectedSegments);
                        });
                        if (!_isMoving) {
                          if (widget.isManualControl) {
                            // Call manual movement function if manual control is enabled
                            _startManualMovement(_dronepath, _selectedPathsQueue);
                          } else {
                            // Call the default movement function otherwise
                            _startMovement(_dronepath, _selectedPathsQueue);
                          }
                        }

                      },
                      child: Text(
                        'Start Spraying',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
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
  void _showVerticalRoutesDialog() {
    List<int> selectedSegments = [];
    List<List<LatLng>> verticalPaths = _allPaths;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              titlePadding: EdgeInsets.zero,
              title: Center(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                  decoration: BoxDecoration(
                    color: Colors.indigo[800],
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Select One or More Routes to Spray',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              content: SizedBox(
                width: 700,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          selectedSegments = List.generate(
                            verticalPaths.length,
                                (i) => i,
                          );
                        });
                      },
                      child: Text(
                        'Select All',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: verticalPaths.length,
                        itemBuilder: (BuildContext context, int index) {
                          int routeNumber = index + 1;
                          bool isSelected = selectedSegments.contains(index);

                          return CheckboxListTile(
                            title: Text(
                              'Route #$routeNumber',
                              style: GoogleFonts.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
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
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        if (selectedSegments.isEmpty) {
                          _showWarningDialog(context);
                          return;

                        }
                        else{
                          Navigator.of(context).pop();

                        }

                        List<List<LatLng>> selectedPaths = [];
                        double totalDistance = 0.0;

                        for (int index in selectedSegments) {
                          selectedPaths.add(verticalPaths[index]);
                          double segmentDistance =
                          calculate_selcted_segemnt_distance(
                              verticalPaths[index]);
                          totalDistance += segmentDistance;
                        }

                        _totalDistanceKM = totalDistance;
                        FirebaseDatabase.instance
                            .ref()
                            .child('totalDistance')
                            .set(_totalDistanceKM);
                        _storeTimeDurationInDatabase(_totalDistanceKM);

                        setState(() {
                          _selectedPathsQueue.clear();
                          _selectedPathsQueue.addAll(selectedPaths);

                          // Update polyline colors
                          _updatePolylineColors(selectedSegments,
                              isVertical: true);
                        });

                        if (!_isMoving) {
                          if (widget.isManualControl) {
                            // Call manual movement function if manual control is enabled
                            _startManualMovement(_dronepath, _selectedPathsQueue);
                          } else {
                            // Call the default movement function otherwise
                            _startMovement(_dronepath, _selectedPathsQueue);
                          }
                        }

                      },
                      child: Text(
                        'Start Spraying',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
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
  void _updatePolylineColors(List<int> selectedSegments, {bool isVertical = false}) {
    setState(() {
      // Update horizontal paths
      if (!isVertical) {
        _polylines.removeWhere(
                (polyline) => polyline.polylineId.value == 'dronepath');
        for (int i = 0; i < _dronepath.length ~/ 2; i++) {
          int startIndex = i * 2;
          List<LatLng> segment = _dronepath.sublist(startIndex, startIndex + 2);
          Color color =
          selectedSegments.contains(i) ? Colors.green : Colors.red;
          _polylines.add(Polyline(
            polylineId: PolylineId('dronepath_$i'),
            points: segment,
            color: color,
            width: 3,
          ));
        }
      } else {
        // Update vertical paths
        _polylines.removeWhere(
                (polyline) => polyline.polylineId.value == 'verticalpath');
        for (int i = 0; i < _allPaths.length; i++) {
          List<LatLng> segment = _allPaths[i];
          Color color =
          selectedSegments.contains(i) ? Colors.green : Colors.red;
          _polylines.add(Polyline(
            polylineId: PolylineId('verticalpath_$i'),
            points: segment,
            color: color,
            width: 3,
          ));
        }
      }
    });
  }
  // Warning dialog when no routes are selected
  void _showWarningDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'No Route Selected',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.red,
            ),
          ),
          content: Text(
            'Please select at least one route before starting the spray operation.',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close the warning dialog
              },
              child: Text(
                'Close',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.indigo[800],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  void dronepath_Horizontal(List<LatLng> polygon, double pathWidth, LatLng startPoint) {
    if (polygon.isEmpty) return;

    List<LatLng> sortedByLat = List.from(polygon)
      ..sort((a, b) => a.latitude.compareTo(b.latitude));
    List<LatLng> sortedByLng = List.from(polygon)
      ..sort((a, b) => a.longitude.compareTo(b.longitude));

    double minLat = sortedByLat.first.latitude;
    double maxLat = sortedByLat.last.latitude;
    double minLng = sortedByLng.first.longitude;
    double maxLng = sortedByLng.last.longitude;

    double startLat = startPoint.latitude.clamp(minLat, maxLat);

    List<List<LatLng>> straightPaths = [];
    bool leftToRight = true;

    double latIncrement = pathWidth / 111111;

    for (double lat = startLat; lat <= maxLat; lat += latIncrement) {
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
          intersections.add(LatLng(lat, lng.clamp(minLng, maxLng)));
        }
      }
      if (intersections.length == 2) {
        intersections.sort((a, b) => a.longitude.compareTo(b.longitude));
        straightPaths.add(leftToRight
            ? [intersections[0], intersections[1]]
            : [intersections[1], intersections[0]]);
        leftToRight = !leftToRight;
      }
    }

    for (double lat = startLat - latIncrement;
    lat >= minLat;
    lat -= latIncrement) {
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
          intersections.add(LatLng(lat, lng.clamp(minLng, maxLng)));
        }
      }
      if (intersections.length == 2) {
        intersections.sort((a, b) => a.longitude.compareTo(b.longitude));
        straightPaths.add(leftToRight
            ? [intersections[0], intersections[1]]
            : [intersections[1], intersections[0]]);
        leftToRight = !leftToRight;
      }
    }

    List<LatLng> dronePath =
    straightPaths.expand((segment) => segment).toList();
    dronePath.insert(0, startPoint);

    double totalDistancezigzagKm = _calculateTotalDistanceZIGAG(dronePath);

    setState(() {
      _dronepath = straightPaths.expand((segment) => segment).toList();
      _allPaths = straightPaths;

      // Clear existing polylines

      // Add updated polyline
      _polylines.add(Polyline(
        polylineId: const PolylineId('dronepath'),
        points: _dronepath,
        color: Colors.red,
        width: 3,
      ));

      totalZigzagPathKm = totalDistancezigzagKm;
    });
  }
  void dronepath_Vertical(List<LatLng> polygon, double pathWidth, LatLng startPoint) {
    if (polygon.isEmpty) return;

    List<LatLng> sortedByLng = List.from(polygon)
      ..sort((a, b) => a.longitude.compareTo(b.longitude));

    double minLng = sortedByLng.first.longitude;
    double maxLng = sortedByLng.last.longitude;

    double startLng = startPoint.longitude.clamp(minLng, maxLng);

    List<List<LatLng>> straightPaths = [];
    bool bottomToTop = true;

    double lngIncrement = pathWidth / 111111;

    for (double lng = startLng; lng <= maxLng; lng += lngIncrement) {
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
        straightPaths.add(bottomToTop
            ? [intersections[0], intersections[1]]
            : [intersections[1], intersections[0]]);
        bottomToTop = !bottomToTop;
      }
    }

    for (double lng = startLng - lngIncrement;
    lng >= minLng;
    lng -= lngIncrement) {
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
        straightPaths.add(bottomToTop
            ? [intersections[0], intersections[1]]
            : [intersections[1], intersections[0]]);
        bottomToTop = !bottomToTop;
      }
    }

    List<LatLng> dronePath =
    straightPaths.expand((segment) => segment).toList();
    dronePath.insert(0, startPoint);

    double totalDistancezigzagKm = _calculateTotalDistanceZIGAG(dronePath);

    setState(() {
      _dronepath = straightPaths.expand((segment) => segment).toList();
      _allPaths = straightPaths;

      // Add updated polyline with correct color
      _polylines.add(Polyline(
        polylineId: const PolylineId('dronepath'),
        points: _dronepath,
        color: Colors.red,
        width: 3,
      ));

      totalZigzagPathKm = totalDistancezigzagKm;
    });
  }
// Extracting LatLng points from markers
  void extractLatLngPoints() {
    if (polygons.isNotEmpty) {
      polygonPoints = polygons.first.points.toList();
    }
  }
  Future<void> _closePolygon(double turnLength) async {
    setState(() {
      _ismanual = true;
      _polylines.clear();
      polygons.add(Polygon(
        polygonId: const PolygonId('polygon'),
        points: _markerPositions,
        strokeColor: Colors.blue,
        strokeWidth: 5,
        fillColor: Colors.blue.withOpacity(0.2),
      ));
    });

    if (_selectedDirection == PathDirection.horizontal) {
      dronepath_Horizontal(_markerPositions, turnLength, selectedMarker!);
    } else {
      if (_selectedDirection == PathDirection.vertical) {
        dronepath_Vertical(_markerPositions, turnLength, selectedMarker!);
        double area = _calculateSphericalPolygonArea(_markerPositions);
        try {
          await _databaseReference.child('Area').set(area);
        } catch (e) {
          print('Error updating area in database: $e');
        }
      } else {
        print('No starting point selected for vertical path generation.');
      }
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
  void _showInputSelectionPopup() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (BuildContext context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
              decoration: BoxDecoration(
                color: Colors.indigo[800],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Select Coordinate Method',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo[800],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                setState(() {
                  _isCustomMode = true;
                  // _ismanual = true;
                  _selectedMethod =
                  'Placing Markers Manually'; // Store selection
                });
                Navigator.pop(context);
              },
              child: Text(
                'Place Markers Manually',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Stack(
              alignment: Alignment.center,
              children: [
                const Divider(color: Colors.grey),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    'OR',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo[800],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                setState(() {
                  _selectedMethod =
                  'Load Coordinates From KML'; // Store selection
                });
                Navigator.pop(context);
                _showFileSelectionPopup();
              },
              child: Text(
                'Load Coordinates From KML',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        );
      },
    );
  }
  Future<void> _showFileSelectionPopup() async {
    List<String> cloudFiles = await _fetchCloudFiles(); // Get list of cloud files

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          titlePadding: EdgeInsets.zero,
          title: Container(
            padding: EdgeInsets.fromLTRB(10, 5, 10, 5),
            decoration: BoxDecoration(
              color: Colors.indigo[800],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Files to Plot',
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_outlined, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: [
                      Radio<String>(
                        value: 'Local',
                        groupValue: _selectedFileSource,
                        onChanged: (String? value) {
                          setState(() {
                            _selectedFileSource = value;
                            _selectedLocalFile = null;
                            _selectedCloudFile = null; // Reset the other selection
                          });
                        },
                      ),
                      Text(
                        'Select files from Local',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.indigo[800],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Image.asset(
                        'images/mobile.png', // replace with your image asset path
                        width: 40,
                        height: 40,
                      ),
                    ],
                  ),
                  if (_selectedFileSource == 'Local')
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[800],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () async {
                        // Open the file picker
                        FilePickerResult? result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['txt', 'kml'], // Only allow .txt and .kml files
                        );

                        // Check if the user selected a file
                        if (result != null) {
                          // Get the full file path and the file name
                          String filePath = result.files.single.path!;
                          String fileName = path.basename(filePath); // Extract just the file name

                          setState(() {
                            _selectedLocalFilePath = filePath; // Store the full file path
                            _selectedLocalFile = fileName; // Store the file name to display in UI
                          });

                          // Do not call _loadMarkersFromFile here
                        }
                      },
                      child: Text(
                        _selectedLocalFile != null
                            ? _selectedLocalFile! // Show the file name in UI
                            : "Browse Local Files",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Radio<String>(
                        value: 'Cloud',
                        groupValue: _selectedFileSource,
                        onChanged: (String? value) {
                          setState(() {
                            _selectedFileSource = value;
                            _selectedLocalFile = null;
                            _selectedCloudFile = null; // Reset the other selection
                          });
                        },
                      ),
                      Text(
                        'Select files from Cloud',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.indigo[800],
                        ),
                      ),
                      const SizedBox(width: 5),
                      Image.asset(
                        'images/cloud.png', // replace with your image asset path
                        width: 40,
                        height: 40,
                      ),
                    ],
                  ),
                  if (_selectedFileSource == 'Cloud')
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.indigo),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButton<String>(
                        hint: Text(
                          'Choose File',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black45,
                          ),
                        ),
                        value: _selectedCloudFile,
                        isExpanded: true,
                        underline: SizedBox(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedCloudFile = newValue;
                          });
                        },
                        items: cloudFiles.map<DropdownMenuItem<String>>((String file) {
                          return DropdownMenuItem<String>(
                            value: file,
                            child: Text(file),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              );
            },
          ),
          actions: <Widget>[
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo[800],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                if (_selectedLocalFile != null || _selectedCloudFile != null) {
                  Navigator.pop(context);
                  if (_selectedLocalFile != null) {
                    // Call _loadMarkersFromFile only here
                    _loadMarkersFromFile(_selectedLocalFilePath!);
                  } else if (_selectedCloudFile != null) {
                    // Call _loadMarkersFromCloudFile only here
                    _loadMarkersFromCloudFile(_selectedCloudFile!);
                  }
                }
              },
              child: Text(
                'Plot Area',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo[800],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  Future<void> _loadMarkersFromCloudFile(String fileName) async {
    try {
      final Reference fileRef = FirebaseStorage.instance.ref().child(fileName);
      final String downloadUrl = await fileRef.getDownloadURL();
      final response = await http.get(Uri.parse(downloadUrl));

      if (response.statusCode == 200) {
        final contents = response.body;

        _markers.clear();
        _markerPositions.clear();

        // Use regex to extract content inside <coordinates> tags
        final RegExp coordRegExp = RegExp(r'<coordinates>(.*?)<\/coordinates>', dotAll: true);
        final Iterable<RegExpMatch> matches = coordRegExp.allMatches(contents);

        bool restrictedAreaFound = false; // Flag for restricted area

        for (var match in matches) {
          final String coordinateData = match.group(1)!.trim();
          final coordinatePairs = coordinateData.split(RegExp(r'\s+'));

          for (var pair in coordinatePairs) {
            final parts = pair.split(',');
            if (parts.length >= 2) {
              final lng = double.parse(parts[0].trim());
              final lat = double.parse(parts[1].trim());
              final latLng = LatLng(lat, lng);

              // Check if the LatLng falls in a restricted building area
              if (_isLatLngInRestrictedArea(latLng)) {
                restrictedAreaFound = true;
                break;
              }

              // Create marker only if not in restricted area
              final markerId = MarkerId('M${_markers.length + 1}');
              final newMarker = Marker(
                markerId: markerId,
                position: latLng,
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              );

              _markers.add(newMarker);
              _markerPositions.add(latLng);
            }
          }

          if (restrictedAreaFound) break;
        }

        if (restrictedAreaFound) {
          _showRestrictedAreaSnackbar(context, 'KML file Have restricted markers on building areas,PLease choose another File'); // Show snackbar if restricted area is found
        } else {
          // Update the UI if no restricted area was found
          setState(() {
            _updatePolylines();
            _updateRouteData();
            animateToFirstMarker();
          });
        }
      } else {
        print('Error fetching cloud file: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading markers from cloud file: $e');
    }
  }
//Widget to make a button which will trigger the functions SELECTING_PATH_AND_DIRECTION()
  Future<void> _loadMarkersFromFile(String filePath) async {
    try {
      final file = File(filePath);
      final contents = await file.readAsString();

      _markers.clear();
      _markerPositions.clear();

      final RegExp coordRegExp = RegExp(r'<coordinates>(.*?)<\/coordinates>', dotAll: true);
      final Iterable<RegExpMatch> matches = coordRegExp.allMatches(contents);

      bool restrictedAreaFound = false; // Flag for restricted area

      for (var match in matches) {
        final String coordinateData = match.group(1)!.trim();
        final coordinatePairs = coordinateData.split(RegExp(r'\s+'));

        for (var pair in coordinatePairs) {
          final parts = pair.split(',');
          if (parts.length >= 2) {
            final lng = double.parse(parts[0].trim());
            final lat = double.parse(parts[1].trim());
            final latLng = LatLng(lat, lng);

            // Check if the LatLng falls in a restricted building area
            if (_isLatLngInRestrictedArea(latLng)) {
              restrictedAreaFound = true;
              break;
            }

            // Create marker only if not in restricted area
            final markerId = MarkerId('M${_markers.length + 1}');
            final newMarker = Marker(
              markerId: markerId,
              position: latLng,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            );

            _markers.add(newMarker);
            _markerPositions.add(latLng);
          }
        }

        if (restrictedAreaFound) break;
      }

      if (restrictedAreaFound) {
        _showRestrictedAreaSnackbar(context, 'KML file Have restricted markers on building areas,PLease choose another File'); // Show snackbar if restricted area is found
      } else {
        // Update the UI if no restricted area was found
        setState(() {
          _updatePolylines();
          _updateRouteData();
          animateToFirstMarker();
        });
      }
    } catch (e) {
      print("Error reading file: $e");
    }
  }
  bool _isLatLngInRestrictedArea(LatLng point) {
    for (var polygon in _buildingPolygons) {
      if (_isPointInPolygon(point, polygon.points)) {
        return true; // Point is in restricted area
      }
    }
    return false;
  }
// Function to fetch files from Firebase Storage
  Future<List<String>> _fetchCloudFiles() async {
    List<String> fileNames = [];
    try {
      final ListResult result = await FirebaseStorage.instance.ref().listAll();
      for (var ref in result.items) {
        fileNames.add(ref.name); // Add file name to the list
      }
    } catch (e) {
      print('Error fetching cloud files: $e');
    }
    return fileNames;
  }
  void _updatePolylines() {
    _polylines.clear();

    if (_markerPositions.length > 1) {
      // Draw the polylines connecting the markers
      for (int i = 0; i < _markerPositions.length - 1; i++) {
        _polylines.add(Polyline(
          polylineId: PolylineId('route$i'),
          points: [_markerPositions[i], _markerPositions[i + 1]],
          color: Colors.blue,
          width: 3,
        ));
      }

      // Check if the shape is closed by comparing the first and last marker positions
      if (_markerPositions.first == _markerPositions.last) {
        setState(() {
          _isShapeClosed =
          true; // Set the boolean to true if the shape is closed
        });
      } else {
        setState(() {
          _isShapeClosed = false; // Set to false if the shape is not closed
        });
      }
    } else {
      setState(() {
        _isShapeClosed =
        false; // If fewer than 2 markers, the shape cannot be closed
      });
    }
  }






  void _startManualMovement(List<LatLng> path, List<List<LatLng>> selectedSegments) {
    if (path.isEmpty || _selectedStartingPoint == null) {
      print("Path is empty or starting point not selected, cannot start movement");
      return;
    }

    // Find the nearest point on the path to the selected starting point
    int startingPointIndex = _findClosestPointIndex(path, _selectedStartingPoint!);

    // Set the car's initial position to the selected starting point
    setState(() {
      _isMoving=false;
      _carPosition = path[startingPointIndex]; // Start from the closest point
      _currentPointIndex = startingPointIndex;
    });

    // Decide the direction-specific marker function
    Add_Car_Marker(_isSegmentSelected(
        path, selectedSegments, _currentPointIndex, PathDirection.horizontal));

    // Initialize movement variables


    // Initialize movement direction
    bool movingForward = true;

    // Start listening to controller button presses
    _controllerButtonListener = () {
      if (_isbackwardPressed) {
        _moveBackward(path, selectedSegments);
      } else if (_isforwardPressed) {
        _moveForward(path, selectedSegments);
      } 
      /*else if (_isLeftPressed) {
        _moveLeft(path, selectedSegments);
      } else if (_isRightPressed) {
        _moveRight(path, selectedSegments);
      }*/
      else if (_isStop) {
        _isStop=true;
        _stopMovement();
      }
    };
  }

  void _moveBackward(List<LatLng> path, List<List<LatLng>> selectedSegments) {
    if (_currentPointIndex > 0) {
      LatLng end = path[_currentPointIndex]; // Current point (end for reverse movement)
      LatLng start = path[_currentPointIndex - 1]; // Previous point (start for reverse movement)
      double segmentDistanceKM = calculateonelinedistance(start, end);
      double distanceCoveredInThisTickKM = (speed * updateInterval) / 1000.0;

      // Continue from the previously covered segment distance without resetting it
      segmentDistanceCoveredKM += distanceCoveredInThisTickKM;

      // Calculate reverse progress, continuing from where the forward movement stopped
      double segmentProgress = 1.0 - (segmentDistanceCoveredKM / segmentDistanceKM).clamp(0.0, 1.0);
      _carPosition = _lerpLatLng(end, start, segmentProgress); // Reverse interpolation

      bool isSelectedSegment = _isSegmentSelected(
        path,
        selectedSegments,
        _currentPointIndex - 1,
        PathDirection.horizontal,
      );

      distanceCoveredInWholeJourney -= distanceCoveredInThisTickKM; // Subtract distance since moving backward

      if (isSelectedSegment) {
        totalDistanceCoveredKM_SelectedPath -= distanceCoveredInThisTickKM; // Subtract distance for selected path
        double remainingDistanceKM_SelectedPath = _totalDistanceKM - totalDistanceCoveredKM_SelectedPath;
        setState(() {
          _remainingDistanceKM_SelectedPath = remainingDistanceKM_SelectedPath.clamp(0.0, _totalDistanceKM);
          _storeTimeLeftInDatabase(_remainingDistanceKM_SelectedPath);
        });

        if (totalDistanceCoveredKM_SelectedPath % 0.5 == 0) {
          FirebaseDatabase.instance.ref().child('remainingDistance').set(_remainingDistanceKM_SelectedPath);
        }
      }

      setState(() {
        _remainingDistanceKM_TotalPath = (totalZigzagPathKm - distanceCoveredInWholeJourney).clamp(0.0, totalZigzagPathKm);
      });

      // Update car marker position
      setState(() {
        _markers.removeWhere((marker) => marker.markerId == const MarkerId('car'));
        Add_Car_Marker(isSelectedSegment);

        if (segmentProgress <= 0.0) { // We are done with this segment and need to move to the previous one
          _currentPointIndex--; // Move to the previous segment
          segmentDistanceCoveredKM = 0.0; // Reset the segment distance for the next segment
        }
      });
    }
  }


  void _moveForward(List<LatLng> path, List<List<LatLng>> selectedSegments) {
    if (_currentPointIndex < path.length - 1) {
      LatLng start = path[_currentPointIndex]; // Current point (start for forward movement)
      LatLng end = path[_currentPointIndex + 1]; // Next point (end for forward movement)
      double segmentDistanceKM = calculateonelinedistance(start, end);
      double distanceCoveredInThisTickKM = (speed * updateInterval) / 1000.0;
      segmentDistanceCoveredKM += distanceCoveredInThisTickKM;

      // Calculate forward progress (moving from start to end)
      double segmentProgress = (segmentDistanceCoveredKM / segmentDistanceKM).clamp(0.0, 1.0);
      _carPosition = _lerpLatLng(start, end, segmentProgress); // Forward interpolation

      bool isSelectedSegment = _isSegmentSelected(
        path,
        selectedSegments,
        _currentPointIndex,
        PathDirection.horizontal,
      );

      distanceCoveredInWholeJourney += distanceCoveredInThisTickKM; // Add distance for forward movement

      if (isSelectedSegment) {
        totalDistanceCoveredKM_SelectedPath += distanceCoveredInThisTickKM;
        double remainingDistanceKM_SelectedPath = _totalDistanceKM - totalDistanceCoveredKM_SelectedPath;
        setState(() {
          _remainingDistanceKM_SelectedPath = remainingDistanceKM_SelectedPath.clamp(0.0, _totalDistanceKM);
          _storeTimeLeftInDatabase(_remainingDistanceKM_SelectedPath);
        });

        if (totalDistanceCoveredKM_SelectedPath % 0.5 == 0) {
          FirebaseDatabase.instance.ref().child('remainingDistance').set(_remainingDistanceKM_SelectedPath);
        }
      }

      setState(() {
        _remainingDistanceKM_TotalPath = (totalZigzagPathKm - distanceCoveredInWholeJourney).clamp(0.0, totalZigzagPathKm);
      });

      // Update car marker position
      setState(() {
        _markers.removeWhere((marker) => marker.markerId == const MarkerId('car'));
        Add_Car_Marker(isSelectedSegment);

        if (segmentProgress >= 1.0) {
          _currentPointIndex++; // Move to the next segment
          segmentDistanceCoveredKM = 0.0; // Reset the segment distance for the next segment
        }
      });
    }
  }
  bool _isStraightLine(List<LatLng> path, int index) {
    if (index <= 0 || index >= path.length - 1) return false;

    LatLng prev = path[index - 1];
    LatLng current = path[index];
    LatLng next = path[index + 1];

    double dx1 = current.longitude - prev.longitude;
    double dy1 = current.latitude - prev.latitude;
    double dx2 = next.longitude - current.longitude;
    double dy2 = next.latitude - current.latitude;

    // Check if both vectors have the same direction (indicating a straight line)
    return (dx1 * dy2 - dy1 * dx2).abs() < 0.0001; // Small tolerance for floating point errors
  }

  /*void _moveLeft(List<LatLng> path, List<List<LatLng>> selectedSegments) {
    if (_currentPointIndex > 0 && !_isStraightLine(path, _currentPointIndex)) {
      int newIndex = _currentPointIndex - 1;
      while (newIndex >= 0 && !_isSegmentSelected(path, selectedSegments, newIndex, PathDirection.horizontal)) {
        newIndex--;
      }
      if (newIndex >= 0) {
        _carPosition = _lerpLatLng(path[_currentPointIndex], path[newIndex], 0.5); // Smaller interpolation step
        _currentPointIndex = newIndex;
        setState(() {
          _markers.removeWhere((marker) => marker.markerId == const MarkerId('car'));
          Add_Car_Marker(_isSegmentSelected(path, selectedSegments, _currentPointIndex, PathDirection.horizontal));
        });
      }
    }
  }

  void _moveRight(List<LatLng> path, List<List<LatLng>> selectedSegments) {
    if (_currentPointIndex < path.length - 1 && !_isStraightLine(path, _currentPointIndex)) {
      int newIndex = _currentPointIndex + 1;
      while (newIndex < path.length && !_isSegmentSelected(path, selectedSegments, newIndex, PathDirection.horizontal)) {
        newIndex++;
      }
      if (newIndex < path.length) {
        _carPosition = _lerpLatLng(path[_currentPointIndex], path[newIndex], 0.00005); // Smaller interpolation step
        _currentPointIndex = newIndex;
        setState(() {
          _markers.removeWhere((marker) => marker.markerId == const MarkerId('car'));
          Add_Car_Marker(_isSegmentSelected(path, selectedSegments, _currentPointIndex, PathDirection.horizontal));
        });
      }
    }
  }
*/
  void ManualStartMovement(void Function() moveFunction) {
    _movementTimer?.cancel(); // Cancel any existing timer
    _movementTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      moveFunction();
    });
  }

  void _stopMovement() {
    _movementTimer?.cancel(); // Stop the timer when button is released
    _movementTimer = null;
    _isMoving = false;
  }





//UI BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        backgroundColor: Colors.indigo[800],
        toolbarHeight: 160, // Custom height for the AppBar
        flexibleSpace: Padding(
          padding: const EdgeInsets.fromLTRB(
              10, 30, 10, 0), // Padding to control spacing
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // First Row: Logo, Title, Notification Icon, Three Dots Icon
              Container(
                decoration: BoxDecoration(
                  color: Colors.white, // Set the background color to white
                  borderRadius: BorderRadius.circular(
                      15), // Make the background rounded (capsule effect)
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12, // Optional shadow for better look
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                        Colors.white, // Set the background color to white
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(1),
                        child: ClipOval(
                          child: Image.asset(
                            'images/logo.png',
                            fit: BoxFit.fill,
                          ),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "LIMS",
                          style: TextStyle(
                            color: Colors
                                .black, // Changed text color to black to be visible on white background
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                            fontFamily: GoogleFonts.poppins().fontFamily,
                          ),
                        ),
                        Text(
                          " Robo",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                            fontSize: 24,
                            fontFamily: GoogleFonts.poppins().fontFamily,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Sign out',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                fontFamily: GoogleFonts.poppins().fontFamily,
                              ),
                            ),
                            const SizedBox(
                                width:
                                2), // Reduced spacing between icon and text

                            IconButton(
                              icon: const Icon(
                                Icons.logout_outlined,
                                color: Colors.black,
                                size: 25,
                              ),
                              onPressed: () async {
                                context.read<ISSAASProvider>().setIsSaas(
                                    false); // Set ISSAAS state to true

                                try {
                                  await FirebaseAuth.instance.signOut();
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            LoginScreen()), // Adjust the navigation to your Login page
                                  );
                                } catch (e) {
                                  // Handle any errors that may occur during sign out
                                  print('Error signing out: $e');
                                }
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              // Second Row: UGV Connected Widget, Rawalpindi Text, Location Icon
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Weather Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(15, 5, 15, 5),
                    child: Obx(() {
                      return Row(
                        children: [
                          Text(
                            weatherController.weather.value.cityname.isEmpty
                                ? "Loading..."
                                : weatherController.weather.value.cityname,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: GoogleFonts.poppins().fontFamily,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(Icons.location_on_outlined,
                              color: Colors.white),
                          const SizedBox(width: 10),
                        ],
                      );
                    }),
                  ),

                  widget.isManualControl
                      ? Padding(
                    padding: const EdgeInsets.fromLTRB(10, 5, 15, 5),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(5, 1, 0, 0),
                      width: 120,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.indigo[800],
                        borderRadius:
                        const BorderRadius.all(Radius.circular(5)),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors
                              .white, // Set the background color to white
                          borderRadius: BorderRadius.circular(
                              10), // Rounded corners
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 7),
                            Center(
                              child: Text(
                                "Manual Mode",
                                style: TextStyle(
                                  color: Colors.indigo[
                                  800], // Text color set to indigo
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  fontFamily:
                                  GoogleFonts.poppins().fontFamily,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                      : Padding(
                    padding: const EdgeInsets.fromLTRB(10, 5, 15, 5),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(5, 1, 0, 0),
                      width: 140,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.indigo[800],
                        borderRadius:
                        const BorderRadius.all(Radius.circular(5)),
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors
                              .white, // Set the background color to white
                          borderRadius: BorderRadius.circular(
                              10), // Rounded corners
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 7),
                            Center(
                              child: Text(
                                "Autonomous Mode",
                                style: TextStyle(
                                  color: Colors.indigo[
                                  800], // Text color set to indigo
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  fontFamily:
                                  GoogleFonts.poppins().fontFamily,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  // Return an empty widget if not purchased
                ],
              ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(15),
              color: Colors.white,
              child: Center(
                child: Container(
                  color: Colors.grey[300], // Light grey background
                  width: 400, // Full width
                  height: 200, // Adjust height as needed
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.videocam_off, // No camera icon
                        size: 50,
                        color: Colors.grey[700],
                      ),
                      SizedBox(height: 10), // Space between icon and text
                      Text(
                        'No Camera View Found',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 5), // Small space between texts
                      Text(
                        'Check Your Camera Settings',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Column(children: [
              // Conditional widget loading with `Visibility`
              if (polygons.isNotEmpty)

                Card(
                  color: Colors.white,
                  elevation: 8,

                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Row 1: Totality fields in containers
                        Card(
                          color: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(5),
                              topRight: Radius.circular(5),
                              bottomLeft: Radius.circular(5),
                              bottomRight: Radius.circular(5),
                            ),
                          ),
                          elevation: 0,
                          child: Row(
                            children: [
                              _CardItem(
                                title: 'Area',
                                value: '${_calculateSphericalPolygonArea(_markerPositions).toStringAsFixed(2)} ac',
                                color: Colors.indigo[800]!,
                                icon: Icons.location_on,
                              ),
                              _CardItem(
                                title: 'Total',
                                value: '${totalZigzagPathKm.toStringAsFixed(2)} Km',
                                color: Colors.deepPurple[800]!,
                                icon: Icons.directions,
                              ),
                              _CardItem(
                                title: 'Spray',
                                value: '${_totalDistanceKM.toStringAsFixed(2)} Km',
                                color: Colors.amber[900]!,
                                icon: Icons.shower_outlined,
                              ),
                              _CardItem(
                                title: 'Spray',
                                value: '${timeduration.toStringAsFixed(2)} min',
                                color: Colors.red[800]!,
                                icon: Icons.route_outlined,
                              ),
                              _CardItem(
                                title: 'UGV',
                                icon: Icons.speed,

                                value: '10m/s',
                                color: Colors.cyan[800]!,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 5),

                        // Row 2: Progress bars for remaining fields
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Rem Spray label and progress bar
                            Row(
                              children: [
                                // First row
                                Expanded(
                                  child: Row(
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.shower_outlined, // replace with your desired icon
                                            color: Colors.black87,
                                            weight: 10,
                                          ),
                                          const SizedBox(width: 5), // space between icon and text
                                          Text(
                                            "Rem Spray:",
                                            style: TextStyle(
                                              color: Colors.amber[900],
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              fontFamily: GoogleFonts.poppins().fontFamily,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 5),

                                      Expanded(
                                        child: Stack(
                                          alignment: Alignment.bottomLeft,
                                          children: [
                                            // The bottle image
                                            Image.asset(
                                              'images/spray.png', // Your sprayer image asset path
                                              height: 100, // Adjust size as needed
                                              width: 70, // Adjust size as needed
                                              fit: BoxFit.contain,
                                            ),
                                            // Remaining spray represented by a container
                                            Positioned(
                                              bottom: 16.3, // Align with the bottom of the bottle body
                                              left: 3.5, // Adjust left offset if necessary

                                              // Wrap the FractionallySizedBox inside a SizedBox with a fixed height
                                              child: SizedBox(
                                                height: 42, // Adjust to fit the height of the bottle body
                                                child: FractionallySizedBox(
                                                  alignment: Alignment.bottomLeft,
                                                  heightFactor: (_totalDistanceKM != 0)
                                                      ? _remainingDistanceKM_SelectedPath / _totalDistanceKM
                                                      : 0.0, // Proportional height
                                                  child: Container(
                                                    width: 20, // Width matching the image or as needed
                                                    decoration: BoxDecoration(
                                                      gradient: const LinearGradient(
                                                        colors: [Colors.red, Colors.green],
                                                        begin: Alignment.bottomCenter,
                                                        end: Alignment.topCenter,
                                                      ),
                                                      borderRadius: BorderRadius.circular(6), // Rounded edges for the liquid
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 2), // spacing between rows

                                // Second row
                                Expanded(
                                  child: Row(
                                    children: [
                                      // Watch Icon with Circular Progress Indicator
                                      const Icon(
                                        Icons.timer_outlined, // replace with your desired icon
                                        color: Colors.black87,
                                        weight: 10,
                                      ),
                                      const SizedBox(width: 5), // space between icon and text

                                      // "Rem Time" Text
                                      Text(
                                        "Rem Time:",
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          fontFamily: GoogleFonts.poppins().fontFamily,
                                        ),
                                      ),
                                      const SizedBox(width: 0), // Spacing between icon and text

                                      SizedBox(
                                        width: 60, // Adjust width as needed
                                        height: 60, // Adjust height as needed
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            // Watch icon image
                                            Image.asset(
                                              'images/watch.png', // Your sprayer image asset path
                                              height: 100, // Adjust size as needed
                                              width: 70, // Adjust size as needed
                                              fit: BoxFit.contain,
                                            ),

                                            // Filled circle (inside the CircularProgressIndicator)
                                            Positioned(
                                              bottom: 18.5, // Align with the bottom of the watch body
                                              left: 25.3, // Adjust left offset if necessary
                                              child: SizedBox(
                                                width: 10, // Adjust size as needed
                                                height: 10,
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    // Filled background circle

                                                    // Circular progress indicator (on top of the filled circle)
                                                    CircularProgressIndicator(
                                                      value: (TLM != null && timeduration != null && timeduration != 0)
                                                          ? 1 - (TLM / timeduration) // Progress value based on remaining time, progressing clockwise
                                                          : 0.0, // No progress initially
                                                      strokeWidth: 31, // Adjust the stroke width for the progress bar
                                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.red), // Red progress color for the stroke
                                                      backgroundColor: Colors.green, // Set background to transparent
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),



                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Rem Dis label and progress bar
                            Row(
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.route_outlined, // replace with your desired icon
                                      color: Colors.black87,
                                    ),
                                    const SizedBox(width: 5), // space between icon and text
                                    Text(
                                      "Rem Dis:",
                                      style: TextStyle(
                                        color: Colors.indigo[800],
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        fontFamily: GoogleFonts.poppins().fontFamily,
                                      ),
                                    ),
                                  ],
                                ),


                                const SizedBox(width: 10),


                                Expanded(
                                  child: AnimatedOpacity(
                                    duration: const Duration(seconds: 1),
                                    opacity: 1,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.black, width: 1.3), // Black border
                                        borderRadius: const BorderRadius.all(Radius.circular(10)),
                                      ),
                                      child: LinearPercentIndicator(
                                        lineHeight: 10,
                                        percent: (_remainingDistanceKM_TotalPath != null && totalZigzagPathKm != null && totalZigzagPathKm != 0)
                                            ? _remainingDistanceKM_TotalPath / totalZigzagPathKm
                                            : 0.0, // default to 0 if values are invalid
                                        linearGradient: const LinearGradient(
                                          colors: [Colors.red, Colors.green], // White
                                        ),
                                        backgroundColor: Colors.grey[200],
                                        barRadius: const Radius.circular(10),
                                        padding: EdgeInsets.zero, // Remove extra padding
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

              widget.isManualControl
                  ?






              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                /*  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [

                          GestureDetector(
                            onTapDown: (TapDownDetails details) {
                              setState(() {
                                _isbackwardPressed = true;
                              });
                              ManualStartMovement(() => _moveBackward(_dronepath, _selectedPathsQueue)); // Start movement
                            },
                            onTapUp: (TapUpDetails details) {
                              setState(() {
                                _isbackwardPressed = false;
                              });
                              _stopMovement(); // Stop movement when button released
                            },
                            child: Image.asset(
                              _isbackwardPressed ? 'images/up_active.png' : 'images/up.png',
                              width:50,
                              height:50,
                            ),
                          ),                         
                        ],
                      ),
                    ],
                  ),*/
                  const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTapDown: (TapDownDetails details) {
                          setState(() {
                            _isbackwardPressed = true;
                          });
                          ManualStartMovement(() => _moveBackward(_dronepath, _selectedPathsQueue)); // Start movement
                        },
                        onTapUp: (TapUpDetails details) {
                          setState(() {
                            _isbackwardPressed = false;
                          });
                          _stopMovement(); // Stop movement when button released
                        },
                        child: Image.asset(
                          _isbackwardPressed ? 'images/bwd_active.png' : 'images/bwd.png',
                          width:50,
                          height:50,
                        ),
                      ),

                      const SizedBox(width: 5),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _stopMovement(); // Stop movement function called
                          });
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
                            _isforwardPressed = true;
                          });
                          ManualStartMovement(() => _moveForward(_dronepath, _selectedPathsQueue)); // Start movement
                        },
                        onTapUp: (TapUpDetails details) {
                          setState(() {
                            _isforwardPressed = false;
                          });
                          _stopMovement(); // Stop movement when button released
                        },
                        child: Image.asset(
                          _isforwardPressed ? 'images/fwd_active.png' : 'images/fwd.png',
                          width: 50,
                          height: 50,
                        ),
                      ),

                    ],
                  ),
                  /*Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [

                          GestureDetector(
                            onTapDown: (TapDownDetails details) {
                              setState(() {
                                _isforwardPressed = true;
                              });
                              ManualStartMovement(() => _moveForward(_dronepath, _selectedPathsQueue)); // Start movement
                            },
                            onTapUp: (TapUpDetails details) {
                              setState(() {
                                _isforwardPressed = false;
                              });
                              _stopMovement(); // Stop movement when button released
                            },
                            child: Image.asset(
                              _isforwardPressed ? 'images/down_active.png' : 'images/down.png',
                              width: 50,
                              height: 50,
                            ),
                          ),

                          SizedBox(height: 10),
                        ],
                      ),
                    ],
                  ),*/
                ],
              )


                  : Container(),





            ]),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[600],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: Text(
                            'Reset Map?',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          content: Text(
                            'Do you really want to reset the map?',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                            ),
                          ),
                          actions: [
                            TextButton(
                              child: Text(
                                'Cancel',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey,
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop(); // Close the dialog
                              },
                            ),
                            TextButton(
                              child: Text(
                                'Yes,Reset?',
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.red,
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop(); // Close the dialog
                                _resetMarkers(); // Call the reset function
                              },
                            ),
                          ],
                        );
                      },
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Text(
                        'Reset Map',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(
                          width: 9), // Reduced space between icon and text
                      const Icon(Icons.warning_amber_outlined,
                          color: Colors.white,
                          size: 18), // Reduced icon size
                    ],
                  ),
                ),

                // Conditionally show the Confirm Field button
                if (_isShapeClosed && !_isConfirmed)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _isConfirmed = true; // Hide this button after pressing
                      });
                      Selecting_Path_Direction_and_Turn(); // Call your function
                    },
                    child: Text(
                      'Confirm Field',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),

                // Conditionally show the Start Spray button

                IconButton(
                  splashRadius: 5,
                  icon: ImageIcon(
                    _isFullScreen
                        ? const AssetImage('images/min.png')
                        : const AssetImage('images/max.png'),
                    size: 40,
                    color: Colors.indigo[800],
                  ),
                  onPressed: () {
                    setState(() {
                      _isFullScreen = !_isFullScreen;
                    });
                  },
                )
              ],
            ),
            Container(
              height: _isFullScreen
                  ? MediaQuery.of(context).size.height * 0.85
                  : 400,
              width: double.infinity,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    Screenshot(
                      controller: _screenshotController,
                      child: _currentLocation == null
                          ? const Center(child: CircularProgressIndicator())
                          : RepaintBoundary(
                        key: _googleMapKey, // Attach the key to GoogleMap
                        child: GoogleMap(
                          initialCameraPosition: _currentLocation != null
                              ? CameraPosition(
                            target: LatLng(
                              _currentLocation!.latitude!,
                              _currentLocation!.longitude!,
                            ),
                            zoom: 15.0,
                          )
                              : const CameraPosition(
                            target: LatLng(
                                0, 0), // Default fallback position
                            zoom: 3.0, // Low zoom for global view
                          ),
                          markers: {
                            ..._markers,
                            if (_currentPosition != null)
                              Marker(
                                markerId:
                                const MarkerId('currentLocation'),
                                position: _currentPosition,
                                icon:
                                BitmapDescriptor.defaultMarkerWithHue(
                                    BitmapDescriptor.hueViolet),
                              ),
                          },
                          polylines: _polylines,
                          polygons: {
                            ..._buildingPolygons, // Building detection polygons
                            ...polygons,   // Custom polygons you will draw
                          },
                          zoomGesturesEnabled: true,
                          rotateGesturesEnabled: true,
                          scrollGesturesEnabled: true,
                          buildingsEnabled: false,
                          onTap: _isCustomMode ? _onMapTap : null,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: false,
                          onMapCreated: (controller) {
                            _googleMapController = controller;
                            // Camera animation is now handled separately.
                            _checkCityAndFetchData(); // Fetch and display building data on map creation
                          },
                          gestureRecognizers: <Factory<
                              OneSequenceGestureRecognizer>>{
                            Factory<OneSequenceGestureRecognizer>(
                                    () => EagerGestureRecognizer()),
                          },
                        ),
                      ),


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
                              style: TextStyle(
                                fontFamily: GoogleFonts.poppins().fontFamily,

                                fontSize: 15.0, // Customize font size
                                color: Colors.black, // Customize text color
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                labelText: 'Search Spraying Location',
                                labelStyle: TextStyle(
                                  fontFamily: GoogleFonts.poppins().fontFamily,
                                  fontWeight: FontWeight
                                      .w600, // Replace with your font family
                                  fontSize: 14.0, // Customize label font size
                                  color: Color(
                                      0xFF037441), // Customize label color
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
                              if (pattern.isEmpty) {
                                return Future.value(<geocoding.Placemark>[]);
                              }
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
                                  style: TextStyle(
                                    fontFamily:
                                    GoogleFonts.poppins().fontFamily,
                                    fontSize: 16.0,
                                    fontWeight:
                                    FontWeight.w400, // Customize font size
                                    color: Colors.black, // Customize text color
                                  ),
                                ),
                                subtitle: Text(
                                  suggestion.locality ?? 'No locality Exists',
                                  style: TextStyle(
                                    fontFamily:
                                    GoogleFonts.poppins().fontFamily,

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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }















  Future<void> captureBottomHalfGoogleMap() async {
    try {
      // Capture the widget as an image
      RenderRepaintBoundary boundary = _googleMapKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image capturedImage = await boundary.toImage();

      // Get image dimensions
      final int imageWidth = capturedImage.width;
      final int imageHeight = capturedImage.height;

      // Convert the image to byte data and extract only the bottom half
      final ByteData? byteData =
      await capturedImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();

        // You can crop the image now to get the bottom half
        final croppedBytes = cropBottomHalf(pngBytes, imageWidth, imageHeight);

        // Trigger the success dialog with the cropped screenshot
        ShowSuccessDialog(croppedBytes);
      }
    } catch (e) {
      print('Error capturing GoogleMap screenshot: $e');
    }
  }
  Uint8List cropBottomHalf(Uint8List originalBytes, int width, int height) {
    // Decode the original image from the Uint8List
    final img.Image? originalImage = img.decodeImage(originalBytes);

    if (originalImage != null) {
      // Crop the bottom half of the image
      final img.Image croppedImage = img.copyCrop(
        originalImage,
        x: 0, // x-coordinate (left)
        y: height ~/ 2, // y-coordinate (start from the middle)
        width: width, // width of the cropped image (same as original)
        height: height ~/ 2, // height of the cropped image (bottom half)
      );

      // Encode the cropped image back to Uint8List
      return Uint8List.fromList(img.encodePng(croppedImage));
    }

    return originalBytes; // Return original bytes if decoding fails
  }
  void animateToFirstMarker() {
    if (_isCustomMode == false && _markerPositions.isNotEmpty) {
      _googleMapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _markerPositions.first, // Animate to first marker position
            zoom: 20.0,
          ),
        ),
      );
    }
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
  void _onMapTap(LatLng latLng) async {
    // Check if the tapped location intersects with any building polygon
    bool isOnBuilding = _buildingPolygons.any((polygon) =>
        _isPointInPolygon(latLng, polygon.points));

    if (isOnBuilding) {
      // Show snackbar indicating that the marker can't be placed on buildings or residential areas
      _showSnackbar(context, 'Cannot place marker on building areas');
      return; // Exit the function to avoid placing the marker
    }

    // Continue with marker placement if no building is detected
    final markerId = MarkerId('M${_markers.length + 1}');
    final newMarker = Marker(
      markerId: markerId,
      position: latLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(_selectedMarkerId == markerId
          ? BitmapDescriptor.hueGreen
          : BitmapDescriptor.hueAzure),
      onTap: () {
        if (_markers.length > 2 && latLng == _markers.first.position) {
          Selecting_Path_Direction_and_Turn();
        }
      },
    );

    setState(() {
      _markers.add(newMarker);
      _markerPositions.add(latLng);

      // Update polylines and route data if more than one marker is present
      if (_markers.length > 1) {
        _updatePolylines();
        _updateRouteData();
      }
    });
  }
// Helper function to check if a point is inside a polygon
  bool _isPointInPolygon(LatLng point, List<LatLng> points) {
    int j = points.length - 1;
    bool inside = false;

    for (int i = 0; i < points.length; i++) {
      if ((points[i].longitude < point.longitude && points[j].longitude >= point.longitude) ||
          (points[j].longitude < point.longitude && points[i].longitude >= point.longitude)) {
        if (points[i].latitude + (point.longitude - points[i].longitude) /
            (points[j].longitude - points[i].longitude) *
            (points[j].latitude - points[i].latitude) < point.latitude) {
          inside = !inside;
        }
      }
      j = i;
    }
    return inside;
  }
  Future<void> _checkCityAndFetchData() async {
    // Get the city name from the weatherController (you may need to adapt this part depending on your architecture)
    // String cityName = weatherController.weather.value.cityname;
    String cityName = 'rawalpindi';

    if (cityName.isEmpty) {
      print("City name is still loading...");
      return; // Wait until city name is loaded
    }

    switch (cityName.toLowerCase()) {
      case 'islamabad':
        await _fetchBuildingData(
            'https://overpass-api.de/api/interpreter?data=[out:json];node[building](33.6600,73.1000,34.2000,73.3000);out;');
        break;
      case 'rawalpindi':
        await _fetchBuildingData(
            'https://overpass-api.de/api/interpreter?data=[out:json];node[building](33.5667,73.0500,33.7167,73.2000);out;');
        break;
      case 'lahore':
        await _fetchBuildingData(
            'https://overpass-api.de/api/interpreter?data=[out:json];node[building](31.4000,73.0300,31.6000,74.4000);out;');
        break;
      case 'karachi':
        await _fetchBuildingData(
            'https://overpass-api.de/api/interpreter?data=[out:json];node[building](24.8500,66.8500,25.2000,67.2000);out;');
        break;
      case 'quetta':
        await _fetchBuildingData(
            'https://overpass-api.de/api/interpreter?data=[out:json];node[building](30.1000,66.8500,30.3000,67.0000);out;');
        break;
      default:
        print('City not recognized for fetching building data.');
        break;
    }
  }
  Future<void> _fetchBuildingData(String url) async {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        _processBuildingData(data);
      } catch (e) {
        print('Error decoding JSON: $e');
      }
    } else {
      throw Exception('Failed to fetch building data');
    }
  }
  void _processBuildingData(Map<String, dynamic> data) {
    List<Polygon> polygons = [];

    for (var element in data['elements']) {
      if (element['type'] == 'node') {
        var lat = element['lat'];
        var lon = element['lon'];

        // Create a circular polygon around the building coordinate
        List<LatLng> circlePoints = _createCirclePoints(LatLng(lat, lon), 0.029, 8); // Radius and number of points

        polygons.add(Polygon(
          polygonId: PolygonId('building_${element['id']}'),
          points: circlePoints,
          strokeColor: Colors.red.shade900,
          strokeWidth: 1,
          fillColor: Colors.red.withOpacity(0.3),
        ));
      }
    }

    setState(() {
      _buildingPolygons = polygons.toSet(); // Ensure you use Set<Polygon>
    });
  }
  List<LatLng> _createCirclePoints(LatLng center, double radius, int pointsCount) {
    List<LatLng> circlePoints = [];
    const double degreeToRadians = pi / 180.0;

    for (int i = 0; i < pointsCount; i++) {
      double angle = degreeToRadians * (i * (360 / pointsCount)); // Distribute points evenly
      double latOffset = radius * cos(angle);
      double lonOffset = radius * sin(angle);

      double lat = center.latitude + latOffset;
      double lon = center.longitude + lonOffset;

      circlePoints.add(LatLng(lat, lon));
    }

    return circlePoints;
  }
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
//below stripping the triangle method to find area was used but unsuccessful results
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
/*
  void _onMapTap(LatLng latLng) {
    final markerId = MarkerId('M${_markers.length + 1}');
    final newMarker = Marker(
      markerId: markerId,
      position: latLng,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),

      onTap: () {
        if (_markers.length > 2 && latLng == _markers.first.position) {
          _initializeAndShowInfoWindows();
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
// Function to initialize all markers with labels and show InfoWindows
  void _initializeAndShowInfoWindows() {
    List<Marker> updatedMarkers = [];
    for (int i = 0; i < _markerPositions.length; i++) {
      final markerId = MarkerId('M${i + 1}');
      final markerLabel = 'M${i + 1}';
      final updatedMarker = Marker(
        markerId: markerId,
        position: _markerPositions[i],
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),

        infoWindow: InfoWindow(
          title: markerLabel,
        ),
      );

      updatedMarkers.add(updatedMarker);
    }

    setState(() {
      _markers = updatedMarkers;
    });

    Future.delayed(Duration(milliseconds: 1000), ()  {
      for (var marker in _markers) {
        _googleMapController.showMarkerInfoWindow(marker.markerId);
      }
    });
  }

*/
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
}
void _showSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(
          fontFamily: GoogleFonts.poppins().fontFamily,
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: Colors.red.withOpacity(0.8),
      duration: const Duration(seconds: 5),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(10),
        ),
      ),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.all(8),
    ),
  );
}
void _showRestrictedAreaSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(
          fontFamily: GoogleFonts.poppins().fontFamily,
          fontSize: 16,
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: Colors.red.withOpacity(0.8),
      duration: const Duration(seconds: 7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(
          Radius.circular(10),
        ),
      ),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.all(8),
    ),
  );
}
class _CardItem extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  _CardItem({required this.title, required this.value, required this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 8,
        color: color,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,

                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      fontFamily: GoogleFonts.poppins().fontFamily,
                    ),
                  ),
                  const SizedBox(width: 4),

                  Icon(icon, color: Colors.white, size: 18),

                ],
              ),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}