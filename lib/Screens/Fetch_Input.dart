import 'package:flutter/widgets.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart' as geo; // For GPS updates
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import 'package:geocoding/geocoding.dart' as geocoding; // Prefixed geocoding
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  final bool groundMode;
  const Fetch_Input(
      {Key? key,
      /*required this.controller*/ required this.isManualControl,
      required this.groundMode})
      : super(key: key);
  @override
  _Fetch_InputState createState() => _Fetch_InputState();
}

class _Fetch_InputState extends State<Fetch_Input> with SingleTickerProviderStateMixin {
  final GlobalKey _googleMapKey = GlobalKey(); // Key to capture GoogleMap
  late GoogleMapController _googleMapController;
  LatLng _currentPosition = LatLng(0, 0); // Default position
  final gps.Location _location = gps.Location(); // GPS location service instance
  LocationData? _currentLocation; // Store the current location data
  LatLng _carPosition = LatLng(0, 0); // Store the car's current position
  late LatLng? selectedMarker = _markers.isNotEmpty
      ? _markers.first.position
      : null; // Store selected marker position
// Firebase Variables for Lat/Lng Streaming
  late DatabaseReference _latRef;
  late DatabaseReference _longRef;
  late Stream<DatabaseEvent> _latStream;
  late Stream<DatabaseEvent> _longStream;
  // Firebase Storage Variables for Cloud Files
  List<String> cloudFiles =
      []; // Store list of cloud files fetched from Firebase
  bool isLoading = true; // Track if cloud files are loading
  // Path and Polyline Variables
  Set<Polyline> _polylines = {}; // Store drawn paths
  List<List<LatLng>> _allPaths = []; // All paths loaded
  List<List<LatLng>> _selectedPathsQueue = []; // Selected path segments
  late List<List<LatLng>>
      selectedSegments; // Store only selected segments for the journey
  int _currentSegmentIndex = 0; // Track the current segment being traversed

  // Polygon and Marker Variables
  Set<Polygon> _FieldPolygons = {}; // Store polygons representing Fields
  Set<Polygon> polygons = {}; // Polygons that make up paths
  List<LatLng> polygonPoints = []; // Store vertices of polygons
  List<Marker> _markers = []; // List of markers
  final List<LatLng> _markerPositions = []; // Marker positions
  Set<Marker> navmarkers = {};
  Set<Polyline> navpolylines = {};
  // Movement and Direction Variables
  Timer? _movementTimer; // Timer to control movement updates
  Timer? _polygonCheckTimer;  // Timer for polygon checks
  int drone_direct =
      0; // Direction for drone (0 = stop, 1 = left, 2 = right, 3 = up, 4 = down)
  double speed = 10.0; // Movement speed in meters per second
  String direction = ""; // Store direction ("forward" or "backward")
  PathDirection _selectedDirection =
      PathDirection.horizontal; // Store the selected direction
  // Distance Tracking Variables
  double _totalDistanceKM = 0.0; // Total distance of path in KM
  double distanceTraveled = 0.0; // Total distance traveled
  double totalZigzagPathKm = 0.0; // Total zigzag path distance
  double TLM = 0.0; // Total Linear Movement
  double totalDistanceCoveredKM_SelectedPath =
      0.0; // Total distance covered in selected path
  double distanceCoveredInWholeJourney =
      0.0; // Total distance covered in the entire journey
  double segmentDistanceCoveredKM =
      0.0; // Distance covered in the current segment
  double _remainingDistanceKM_TotalPath =
      0.0; // Remaining distance in the total path
  double _remainingDistanceKM_SelectedPath =
      0.0; // Remaining distance in the selected path


  // UI and Input Control Variables
  bool _isFullScreen = false; // Track fullscreen mode
  bool _isStop = false; // Stop control flag
  bool _isforwardPressed = false; // Track forward movement
  bool _isbackwardPressed = false; // Track backward movement
  bool _isMoving = false; // Track if vehicle is moving
  bool _isConfirmed = false; // Track if confirmation is done
  bool _ismanual = false; // Track if manual mode is enabled
  bool _isCustomMode = false; // Custom mode flag
  bool _isShapeClosed = false; // Check if shape (polygon) is closed
  //bool _isNAVGPS = false; // Check if shape (polygon) is closed

  // UI for Method and File Selection
  String? _selectedLocalFilePath; // Store local file path
  String _selectedMethod = 'N/A'; // Store selected method
  String? _selectedFileSource =
      'N/A in Manual Mode'; // Store file source (Local or Cloud)
  String? _selectedLocalFile =
      'N/A in Manual Mode'; // Store selected local file
  String? _selectedCloudFile =
      'N/A in Manual Mode'; // Store selected cloud file
  double _turnLength = 5.0; // Turn length for path calculation
  // Miscellaneous Variables
  final ScreenshotController _screenshotController =
      ScreenshotController(); // Screenshot controller
  final FocusNode _focusNode = FocusNode(); // Focus node for input controls
  Timer? _debounce; // Debounce timer for input throttling
  MarkerId? _selectedMarkerId; // Track the selected marker ID
  // Firebase Realtime Database and Weather Controller
  final DatabaseReference _databaseReference =
      FirebaseDatabase.instance.ref(); // Firebase reference
  final WeatherController weatherController =
      Get.put(WeatherController()); // Weather controller
  VoidCallback? _controllerButtonListener; // Button listener for the controller
  // Custom Icons
  late BitmapDescriptor ugv_active; // UGV active icon
  late BitmapDescriptor ugv_dead; // UGV dead icon
  late BitmapDescriptor uav_active; // UAV active icon
  late BitmapDescriptor uav_dead; // UAV dead icon
  late BitmapDescriptor spr_active; // UAV dead icon
  int _currentPointIndex = 0;
  List<LatLng> _dronepath = [];
  double updateInterval = 0.1; // seconds
  double pathWidth = 5.0;
  bool _isHorizontalDirection = false;
  //USER SELECTION RECEIPT
  LatLng? _selectedStartingPoint;
  String get message =>
      'Cannot place marker on Fields. Please select a plain area';
  late AnimationController _controller;
  double _offset = 0;
  StreamSubscription<Position>? _gpsStreamSubscription;
  double trackTolerance =
      0.01; // Define tolerance in kilometers, adjust as necessary
  late final List<LatLng> routePoints;
  late final List<dynamic> legs;


  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 20),
    )..addListener(() {
      setState(() {
        _offset = _controller.value * 300; // Adjust according to your text width
      });
    });
    _controller.repeat();
    // Show either input popup or ONMAPTAP based on ISSAAS mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Accessing the ISSAASProvider to check if ISSAAS mode is active
      // ISSAAS mode is false, show input selection popup
      _showInputSelectionPopup();
      _checkCityAndFetchData();
      _fetchCloudFiles();
    });
    _updateMarkersAndPolyline();
    _initializeFirebaseListener();
    _requestLocationPermission();
    _fetchLocationData();
    if (_markers.isNotEmpty) {
      selectedMarker = _markers.first.position;
    }
    _carPosition = LatLng(0, 0);
    _loadCarIcons();
    _loadCarIcons_UAV();
    _loadCarIcons_GPS();
  }



  @override
  void dispose() {
    // Cancel timers and cleanup listeners
    _debounce?.cancel(); // Cancel debounce timer if active
    _movementTimer?.cancel(); // Cancel movement timer if active
    _focusNode.dispose();
    _controller.dispose(); // Dispose focus node
    _markers.clear();
    super.dispose();
  }

  // Get the current location of the user

  // Move the map camera to the current position
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


  LatLng _lerpLatLng(LatLng a, LatLng b, double t)
  {
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
  } // Return dstance in kilometers
  int _findClosestPointIndex(List<LatLng> path, LatLng selectedPoint) {
    if (path.isEmpty) return -1; // Return -1 if the path is empty

    int closestIndex = 0;
    double closestDistance = double.infinity;

    for (int i = 0; i < path.length; i++) {
      double distance = calculateonelinedistance(path[i], selectedPoint);

      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = i;
      }
    }

    return closestIndex;
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
                      onPressed: () async {
                        _closePolygon(_turnLength);
                        if (_selectedStartingPoint == null) {
                          setState(() {
                            isStartingPointEmpty = true;
                          });
                        } else {
                          Navigator.of(context).pop();

                          LatLng initialPosition = _selectedStartingPoint!;
                          extractLatLngPoints();

                          // Generate path based on direction
                          if (_selectedDirection == PathDirection.vertical) {
                            _isHorizontalDirection = false;
                             dronepath_Vertical(polygonPoints, pathWidth, _selectedStartingPoint!);
                          } else {
                            _isHorizontalDirection = true;
                             dronepath_Horizontal(polygonPoints, pathWidth, _selectedStartingPoint!);
                          }

                          // Add a slight delay to ensure the map finishes rendering the path
                          await Future.delayed(Duration(milliseconds: 800)); // Adjust delay as needed

                          // Take the screenshot after path generation and delay
                          _screenshotController.capture().then((Uint8List? capturedBytes) {
                            if (capturedBytes != null) {
                              setup_hardware(capturedBytes); // Call the setup method with the screenshot
                            }
                          }).catchError((e) {
                            print('Error capturing screenshot: $e');
                          });
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
                    )
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
      if(widget.groundMode) {
        _markers
            .removeWhere((marker) => marker.markerId == const MarkerId('car'));
      }else{
        _markers
            .removeWhere((marker) => marker.markerId == const MarkerId('uav'));
      }
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
  bool _isSegmentSelected(List<LatLng> path, List<List<LatLng>> selectedSegments, int index, PathDirection direction) {
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
  Future<void> _loadCarIcons_UAV() async {
    // Load the image from your assets
    const ImageConfiguration imageConfiguration = ImageConfiguration(
      size: Size(20, 20),
    );
    uav_active = await BitmapDescriptor.fromAssetImage(
      imageConfiguration,

      'images/uav_active.png', // Replace with your actual asset path
    );
    uav_dead = await BitmapDescriptor.fromAssetImage(
      imageConfiguration,
      'images/uav_dead.png', // Replace with your actual asset path
      //'images/ugv_active.png', // Replace with your actual asset path
    );
  }
  Future<void> _loadCarIcons_GPS() async {
    // Load the image from your assets
    const ImageConfiguration imageConfiguration = ImageConfiguration(
      size: Size(20, 20),
    );
    spr_active = await BitmapDescriptor.fromAssetImage(
      imageConfiguration,

      'images/gps.png', // Replace with your actual asset path
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
  Future<void> Add_Car_Marker_UAV(bool isSelectedSegment) async {
    setState(() {
      _markers.add(Marker(
        markerId: const MarkerId('uav'),
        position: LatLng(_carPosition.latitude, _carPosition.longitude),
        icon: isSelectedSegment
            ? uav_active
            : uav_dead, // Set the car marker based on the segment selection
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
                  MaterialPageRoute(
                      builder: (context) => const MyHomePage(
                            deviceId: '',
                          )),
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
  void setup_hardware(Uint8List screenshotBytes) {
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
                              color: Colors.black,
                            ),
                          ),
                          TextSpan(
                            text: _selectedStartingPoint != null
                                ? 'Lat: ${_selectedStartingPoint!.latitude.toStringAsFixed(3)}, Lng: ${_selectedStartingPoint!.longitude.toStringAsFixed(3)}'
                                : 'None',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo[800],
                            ),
                          ),
                        ],
                      ),
                    ),


                const SizedBox(height: 5), // Space between image and button

                  Image.memory(screenshotBytes), // Display the screenshot
                  const SizedBox(height: 5), // Space between image and button

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
                      onPressed: () async {
                        if (selectedSegments.isEmpty) {
                          _showWarningDialog(context);
                          return;
                        } else {
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
                          double segmentDistance = calculate_selcted_segemnt_distance(segment);
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
                          _isCustomMode = false;
                          // Update polyline colors
                          _updatePolylineColors(selectedSegments);
                        });

                        // Run GPS-based movement if isSaas is true
                        if (context.read<ISSAASProvider>().isSaas) {
                         _startMovement_GPS(_dronepath,_selectedPathsQueue);
                         _updateMarkersAndPolyline();
                        } else {
                          // Proceed with UAV/UGV logic if isSaas is false
                          if (!_isMoving) {
                            if (widget.groundMode) {
                              if (widget.isManualControl) {
                                // Call manual movement function for UGV if manual control is enabled
                                _startManualMovement_UGV(_dronepath, _selectedPathsQueue, forward: true);
                              } else {
                                // Call the default movement function for UGV otherwise
                                _startMovement_UGV(_dronepath, _selectedPathsQueue);
                              }
                            } else {
                              if (widget.isManualControl) {
                                // Call manual movement function for UAV if manual control is enabled
                                _startManualMovement_UAV(_selectedPathsQueue, forward: true);
                              } else {
                                // Call the default movement function otherwise
                                _startMovement_UAV(_selectedPathsQueue);
                              }
                            }
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
                      onPressed: () async {
                        if (selectedSegments.isEmpty) {
                          _showWarningDialog(context);
                          return;
                        } else {
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
                          _updatePolylineColors(selectedSegments, isVertical: true);
                        });

                        if (context.read<ISSAASProvider>().isSaas) {
                          _startMovement_GPS(_dronepath,_selectedPathsQueue);
                          _updateMarkersAndPolyline();
                        } else {
                          // Proceed with UAV/UGV logic if isSaas is false
                          if (!_isMoving) {
                            if (widget.groundMode) {
                              if (widget.isManualControl) {
                                // Call manual movement function for UGV if manual control is enabled
                                _startManualMovement_UGV(_dronepath, _selectedPathsQueue, forward: true);
                              } else {
                                // Call the default movement function for UGV otherwise
                                _startMovement_UGV(_dronepath, _selectedPathsQueue);
                              }
                            } else {
                              if (widget.isManualControl) {
                                // Call manual movement function for UAV if manual control is enabled
                                _startManualMovement_UAV(_selectedPathsQueue, forward: true);
                              } else {
                                // Call the default movement function otherwise
                                _startMovement_UAV(_selectedPathsQueue);
                              }
                            }
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
  // Warning dialog when no routes are selecte
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

      _showSnackbar_connection(
          context, 'You are now connected with the Satellite');
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
    setState(() {_currentPosition = LatLng(lat, long);
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
                  _selectedMethod = 'Placing Markers Manually'; // Store selection
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
    List<String> cloudFiles =
        await _fetchCloudFiles(); // Get list of cloud files

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
                            _selectedCloudFile =
                                null; // Reset the other selection
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
                        FilePickerResult? result =
                            await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: [
                            'txt',
                            'kml'
                          ], // Only allow .txt and .kml files
                        );

                        // Check if the user selected a file
                        if (result != null) {
                          // Get the full file path and the file name
                          String filePath = result.files.single.path!;
                          String fileName = path
                              .basename(filePath); // Extract just the file name

                          setState(() {
                            _selectedLocalFilePath =
                                filePath; // Store the full file path
                            _selectedLocalFile =
                                fileName; // Store the file name to display in UI
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
                            _selectedCloudFile = null;
                            _fetchCloudFiles(); // Fetch cloud files when selected
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
                        'images/cloud.png',
                        width: 40,
                        height: 40,
                      ),
                    ],
                  ),
                  if (_selectedFileSource == 'Cloud')
                    GestureDetector(
                      onTap: () {
                        if (cloudFiles.isEmpty) {
                          // If no cloud files available, show a warning
                        }
                      },
                      child: Container(
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
                          onChanged: cloudFiles.isNotEmpty
                              ? (String? newValue) {
                                  setState(() {
                                    _selectedCloudFile = newValue;
                                  });
                                }
                              : null, // Disable the dropdown if no files
                          items: cloudFiles.isNotEmpty
                              ? cloudFiles
                                  .map<DropdownMenuItem<String>>((String file) {
                                  return DropdownMenuItem<String>(
                                    value: file,
                                    child: Text(file),
                                  );
                                }).toList()
                              : null,
                        ),
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
                  if (_selectedLocalFile != null) {
                    _loadMarkersFromFile(_selectedLocalFilePath!);
                  } else if (_selectedCloudFile != null) {
                    _loadMarkersFromCloudFile(_selectedCloudFile!);
                  }
                  Navigator.pop(context);
                } else {
                  _showSnackbar(context,
                      'Please Select At least One file from Local Or Cloud Source');
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
        final RegExp coordRegExp =
            RegExp(r'<coordinates>(.*?)<\/coordinates>', dotAll: true);
        final Iterable<RegExpMatch> matches = coordRegExp.allMatches(contents);
        for (var match in matches) {
          final String coordinateData = match.group(1)!.trim();
          final coordinatePairs = coordinateData.split(RegExp(r'\s+'));

          for (var pair in coordinatePairs) {
            final parts = pair.split(',');
            if (parts.length >= 2) {
              final lng = double.parse(parts[0].trim());
              final lat = double.parse(parts[1].trim());
              final latLng = LatLng(lat, lng);

              // Create marker only if not in restricted area
              final markerId = MarkerId('M${_markers.length + 1}');
              final newMarker = Marker(
                markerId: markerId,
                position: latLng,
                icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueAzure),
              );

              _markers.add(newMarker);
              _markerPositions.add(latLng);
            }
          }
        }

        setState(() {
          _updatePolylines();
          _updateRouteData();
          animateToFirstMarker();
        });
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

      final RegExp coordRegExp =
          RegExp(r'<coordinates>(.*?)<\/coordinates>', dotAll: true);
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

            // Check if the LatLng falls in a restricted Field area

            // Create marker only if not in restricted area
            final markerId = MarkerId('M${_markers.length + 1}');
            final newMarker = Marker(
              markerId: markerId,
              position: latLng,
              icon: BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueAzure),
            );

            _markers.add(newMarker);
            _markerPositions.add(latLng);
          }
        }

        //  if (restrictedAreaFound) break;
      }

      /* if (restrictedAreaFound) {
        _showRestrictedAreaSnackbar(context, 'KML file Have restricted markers on Field areas,PLease choose another File'); // Show snackbar if restricted area is found
      } else {
        // Update the UI if no restricted area was found

      } */
      setState(() {
        _updatePolylines();
        _updateRouteData();
        animateToFirstMarker();
      });
    } catch (e) {
      print("Error reading file: $e");
    }
  }
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
// Ensure this method is called when "Cloud" is selected
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
  void stopMovement() {
    _isMoving = false;
    _movementTimer?.cancel();
  }


  void _startMovement_UGV(List<LatLng> path, List<List<LatLng>> selectedSegments) {
    if (path.isEmpty || _selectedStartingPoint == null) {
      print(
          "Path is empty or starting point not selected, cannot start movement");
      return;
    }
    _isMoving = true;

    // Find the nearest point on the path to the selected starting point
    int startingPointIndex = _findClosestPointIndex(path, _selectedStartingPoint!);

    // Set the car's initial position to the selected starting point
    setState(() {
      _carPosition = path[startingPointIndex]; // Start from the closest point
      _currentPointIndex = startingPointIndex;
    });

    // Decide the direction-specific marker function
    Add_Car_Marker(_isSegmentSelected(path, selectedSegments, _currentPointIndex, PathDirection.horizontal));

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
            double distanceCoveredInThisTickKM = (speed * updateInterval) / 1000.0;
            segmentDistanceCoveredKM += distanceCoveredInThisTickKM;
            double segmentProgress = (segmentDistanceCoveredKM / segmentDistanceKM).clamp(0.0, 1.0);
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
              totalDistanceCoveredKM_SelectedPath += distanceCoveredInThisTickKM;
              double remainingDistanceKM_SelectedPath = _totalDistanceKM - totalDistanceCoveredKM_SelectedPath;
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
  void _startManualMovement_UGV(List<LatLng> path, List<List<LatLng>> selectedSegments, {required bool forward}) {
    if (path.isEmpty || _selectedStartingPoint == null) {
      print("Path is empty or starting point not selected, cannot start movement");
      return;
    }

    if (_movementTimer != null && _movementTimer!.isActive) {
      _isMoving = true;
      return;
    }

    // Determine the starting point in the path
    int startingPointIndex = _findClosestPointIndex(path, _selectedStartingPoint!);

    // Set the initial marker position based on the starting point
    if (!_isMoving) {
      setState(() {
        _carPosition = path[startingPointIndex];
        _currentPointIndex = startingPointIndex;
      });
    }

    // Decide the direction-specific marker function
    Add_Car_Marker(_isSegmentSelected(
        path,
        selectedSegments,
        _currentPointIndex,
        _isHorizontalDirection ? PathDirection.horizontal : PathDirection.vertical));

    double updateInterval = 0.1; // seconds
    double speed = 10.0; // meters per second

    // Start movement with timer
    _movementTimer = Timer.periodic(
        Duration(milliseconds: (updateInterval * 1000).toInt()), (timer) async {
      if (_isMoving) {
        // Forward movement logic
        if (forward) {
          // Traverse the path forward from the selected starting point
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
              totalDistanceCoveredKM_SelectedPath += distanceCoveredInThisTickKM;
              double remainingDistanceKM_SelectedPath = _totalDistanceKM - totalDistanceCoveredKM_SelectedPath;
              setState(() {
                _remainingDistanceKM_SelectedPath = remainingDistanceKM_SelectedPath.clamp(0.0, _totalDistanceKM);
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
            double distanceCoveredInThisTickKM = (speed * updateInterval) / 1000.0;
            segmentDistanceCoveredKM += distanceCoveredInThisTickKM;

            double segmentProgress = (segmentDistanceCoveredKM / segmentDistanceKM).clamp(0.0, 1.0);
            _carPosition = _lerpLatLng(start, end, segmentProgress);

            bool isSelectedSegment = _isSegmentSelected(
                path,
                selectedSegments,
                _currentPointIndex - 1,
                _isHorizontalDirection ? PathDirection.horizontal : PathDirection.vertical);

            setState(() {
              _markers.removeWhere((marker) => marker.markerId == const MarkerId('car'));
              Add_Car_Marker(isSelectedSegment);

              if (segmentProgress >= 1.0) {
                _currentPointIndex--;
                segmentDistanceCoveredKM = 0.0;
              }
            });

            // When the first point is reached, stop the movement
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
  void _startManualMovement_UAV(List<List<LatLng>> selectedSegments, {required bool forward}) {
    if (selectedSegments.isEmpty || _selectedStartingPoint == null) {
      print("Selected segments are empty or starting point not selected, cannot start movement");
      return;
    }

    if (_movementTimer != null && _movementTimer!.isActive) {
      _isMoving = true;
      return;
    }

    // Determine the starting point in the first segment
    int startingPointIndex = _findClosestPointIndex(selectedSegments[0], _selectedStartingPoint!);

    // Set the initial marker position based on the starting point
    if (!_isMoving) {
      setState(() {
        _carPosition = selectedSegments[0][startingPointIndex];
        _currentSegmentIndex = 0;
        _currentPointIndex = startingPointIndex;
      });
    }

    // Decide the direction-specific marker function
    Add_Car_Marker_UAV(_isSegmentSelected(
        selectedSegments[0],
        [selectedSegments[0]],
        _currentPointIndex,
        _isHorizontalDirection ? PathDirection.horizontal : PathDirection.vertical));

    double updateInterval = 0.1; // seconds
    double speed = 10.0; // meters per second

    _movementTimer = Timer.periodic(
        Duration(milliseconds: (updateInterval * 1000).toInt()), (timer) async {
      if (_isMoving) {
        // Forward movement logic
        if (forward) {
          // Traverse the selected segments forward
          if (_currentSegmentIndex < selectedSegments.length) {
            if (_currentPointIndex < selectedSegments[_currentSegmentIndex].length - 1) {
              LatLng start = selectedSegments[_currentSegmentIndex][_currentPointIndex];
              LatLng end = selectedSegments[_currentSegmentIndex][_currentPointIndex + 1];
              double segmentDistanceKM = calculateonelinedistance(start, end);
              double distanceCoveredInThisTickKM = (speed * updateInterval) / 1000.0;
              segmentDistanceCoveredKM += distanceCoveredInThisTickKM;
              double segmentProgress = (segmentDistanceCoveredKM / segmentDistanceKM).clamp(0.0, 1.0);
              _carPosition = _lerpLatLng(start, end, segmentProgress);
              bool isSelectedSegment = _isSegmentSelected(
                selectedSegments[_currentSegmentIndex],
                [selectedSegments[_currentSegmentIndex]],
                _currentPointIndex,
                _isHorizontalDirection ? PathDirection.horizontal : PathDirection.vertical,
              );
              distanceCoveredInWholeJourney += distanceCoveredInThisTickKM;
              if (isSelectedSegment) {
                totalDistanceCoveredKM_SelectedPath += distanceCoveredInThisTickKM;
                double remainingDistanceKM_SelectedPath = _totalDistanceKM - totalDistanceCoveredKM_SelectedPath;
                setState(() {
                  _remainingDistanceKM_SelectedPath = remainingDistanceKM_SelectedPath.clamp(0.0, _totalDistanceKM);
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
                _markers.removeWhere((marker) => marker.markerId == const MarkerId('uav'));
                Add_Car_Marker_UAV(isSelectedSegment);
                if (segmentProgress >= 1.0) {
                  _currentPointIndex++;
                  segmentDistanceCoveredKM = 0.0;
                }
              });
              if (_currentPointIndex >= selectedSegments[_currentSegmentIndex].length - 1) {
                if (_currentSegmentIndex == selectedSegments.length - 1) {
                  _movementTimer?.cancel();
                  _isMoving = false;
                  timer.cancel();
                  _onPathComplete();
                } else {
                  _currentSegmentIndex++;
                  _currentPointIndex = 0;
                }
              }
            } else {
              if (_currentSegmentIndex == selectedSegments.length - 1) {
                _movementTimer?.cancel();
                _isMoving = false;
                timer.cancel();
                _onPathComplete();
              } else {
                _currentSegmentIndex++;
                _currentPointIndex = 0;
              }
            }
          } else {
            _movementTimer?.cancel();
            _isMoving = false;
            timer.cancel();
            _onPathComplete();
          }
        }else {
          if (_currentSegmentIndex > 0) {
            if (_currentPointIndex > 0) {
              LatLng start = selectedSegments[_currentSegmentIndex][_currentPointIndex];
              LatLng end = selectedSegments[_currentSegmentIndex][_currentPointIndex - 1];
              double segmentDistanceKM = calculateonelinedistance(start, end);
              double distanceCoveredInThisTickKM = (speed * updateInterval) / 1000.0;
              segmentDistanceCoveredKM += distanceCoveredInThisTickKM;

              double segmentProgress = (segmentDistanceCoveredKM / segmentDistanceKM).clamp(0.0, 1.0);
              _carPosition = _lerpLatLng(start, end, segmentProgress);

              bool isSelectedSegment = _isSegmentSelected(
                  selectedSegments[_currentSegmentIndex],
                  [selectedSegments[_currentSegmentIndex]],
                  _currentPointIndex - 1,
                  _isHorizontalDirection ? PathDirection.horizontal : PathDirection.vertical);

              setState(() {
                _markers.removeWhere((marker) => marker.markerId == const MarkerId('uav'));
                Add_Car_Marker_UAV(isSelectedSegment);

                if (segmentProgress >= 1.0) {
                  _currentPointIndex--;
                  segmentDistanceCoveredKM = 0.0;
                }
              });

              // When the first point is reached, stop the movement
              if (_currentPointIndex <= 0) {
                _currentSegmentIndex--;
                _currentPointIndex = selectedSegments[_currentSegmentIndex].length - 1;
              }
            } else {
              _currentSegmentIndex--;
              _currentPointIndex = selectedSegments[_currentSegmentIndex].length - 1;
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
  void _startMovement_UAV(List<List<LatLng>> selectedSegmentsQueue) {
    if (selectedSegmentsQueue.isEmpty || _selectedStartingPoint == null) {
      print(
          "Selected segments are empty or starting point not selected, cannot start movement");
      return;
    }

    _isMoving = true;
    int currentSegmentIndex = 0;
    double totalDistanceCoveredKM_SelectedPath = 0.0;
    double segmentDistanceCoveredKM = 0.0;
    double distanceCoveredInWholeJourney = 0.0;

    void _moveToNextSegment() {
      if (currentSegmentIndex >= selectedSegmentsQueue.length) {
        _isMoving = false;
        _onPathComplete();
        return;
      }

      List<LatLng> currentSegment = selectedSegmentsQueue[currentSegmentIndex];
      int startingPointIndex = _findClosestPointIndex(currentSegment, _selectedStartingPoint!);

      setState(() {
        _carPosition = currentSegment[startingPointIndex];
        _currentPointIndex = startingPointIndex;
      });

      bool movingForward = startingPointIndex < currentSegment.length / 2;

      _movementTimer = Timer.periodic(
          Duration(milliseconds: (updateInterval * 1000).toInt()),
              (timer) async {
            if (_isMoving) {
              if (movingForward) {
                if (_currentPointIndex < currentSegment.length - 1) {
                  LatLng start = currentSegment[_currentPointIndex];
                  LatLng end = currentSegment[_currentPointIndex + 1];
                  double segmentDistanceKM = calculateonelinedistance(start, end);
                  double distanceCoveredInThisTickKM =
                      (speed * updateInterval) / 1000.0;
                  segmentDistanceCoveredKM += distanceCoveredInThisTickKM;
                  double segmentProgress =
                  (segmentDistanceCoveredKM / segmentDistanceKM)
                      .clamp(0.0, 1.0);
                  _carPosition = _lerpLatLng(start, end, segmentProgress);

                  distanceCoveredInWholeJourney += distanceCoveredInThisTickKM;
                  totalDistanceCoveredKM_SelectedPath +=
                      distanceCoveredInThisTickKM;
                  double remainingDistanceKM_SelectedPath =
                      _totalDistanceKM - totalDistanceCoveredKM_SelectedPath;

                  setState(() {
                    _remainingDistanceKM_SelectedPath =
                        remainingDistanceKM_SelectedPath.clamp(
                            0.0, _totalDistanceKM);
                    _remainingDistanceKM_TotalPath =
                        (totalZigzagPathKm - distanceCoveredInWholeJourney)
                            .clamp(0.0, totalZigzagPathKm);
                    _storeTimeLeftInDatabase(_remainingDistanceKM_SelectedPath);
                    _markers.removeWhere(
                            (marker) => marker.markerId == const MarkerId('uav'));
                    Add_Car_Marker_UAV(true);

                    if (segmentProgress >= 1.0) {
                      _currentPointIndex++;
                      segmentDistanceCoveredKM = 0.0;
                    }
                  });

                  if (_currentPointIndex >= currentSegment.length - 1) {
                    timer.cancel();
                    currentSegmentIndex++;
                    _moveToNextSegment();
                  }
                } else {
                  _isMoving = false;
                  timer.cancel();
                  _onPathComplete();
                }
              } else {
                if (_currentPointIndex > 0) {
                  LatLng start = currentSegment[_currentPointIndex];
                  LatLng end = currentSegment[_currentPointIndex - 1];
                  double segmentDistanceKM = calculateonelinedistance(start, end);
                  double distanceCoveredInThisTickKM =
                      (speed * updateInterval) / 1000.0;
                  segmentDistanceCoveredKM += distanceCoveredInThisTickKM;
                  double segmentProgress =
                  (segmentDistanceCoveredKM / segmentDistanceKM)
                      .clamp(0.0, 1.0);
                  _carPosition = _lerpLatLng(start, end, segmentProgress);

                  distanceCoveredInWholeJourney += distanceCoveredInThisTickKM;
                  totalDistanceCoveredKM_SelectedPath +=
                      distanceCoveredInThisTickKM;
                  double remainingDistanceKM_SelectedPath =
                      _totalDistanceKM - totalDistanceCoveredKM_SelectedPath;

                  setState(() {
                    _remainingDistanceKM_SelectedPath =
                        remainingDistanceKM_SelectedPath.clamp(
                            0.0, _totalDistanceKM);
                    _remainingDistanceKM_TotalPath =
                        (totalZigzagPathKm - distanceCoveredInWholeJourney)
                            .clamp(0.0, totalZigzagPathKm);
                    _storeTimeLeftInDatabase(_remainingDistanceKM_SelectedPath);
                    _markers.removeWhere(
                            (marker) => marker.markerId == const MarkerId('uav'));
                    Add_Car_Marker_UAV(true);

                    if (segmentProgress >= 1.0) {
                      _currentPointIndex--;
                      segmentDistanceCoveredKM = 0.0;
                    }
                  });

                  if (_currentPointIndex <= 0) {
                    timer.cancel();
                    currentSegmentIndex++;
                    _moveToNextSegment();
                  }
                } else {
                  _isMoving = false;
                  timer.cancel();
                  _onPathComplete();
                }
              }
            }
          });
    }

    _moveToNextSegment();
  }

  void _startMovement_GPS(List<LatLng> path, List<List<LatLng>> selectedSegments) {
    if (path.isEmpty || _selectedStartingPoint == null) {
      print("Path is empty or starting point not selected, cannot start movement");
      return;
    }
    _isMoving = true;

    // Track total distances
    double distanceCoveredInWholeJourney = 0.0;
    double totalDistanceCoveredKM_SelectedPath = 0.0;
    double segmentDistanceCoveredKM = 0.0; // Distance covered in current segment

    LatLng? _previousPosition;

    // Start GPS tracking
    _gpsStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: geo.LocationAccuracy.high,
      ),
    ).listen((Position position) {
      if (!_isMoving) return;

      // Use the exact current GPS position as the car marker position
      LatLng currentPosition = LatLng(position.latitude, position.longitude);

      // Check if the current position is within the allowed area
      if (!_isPointInsidePolygon(currentPosition, polygonPoints) &&
          !_isPointOnPath(currentPosition, _polylines)) {
       // _showSnackbar(context, 'You are outside the farm area, try to stay inside');
        return; // Stop processing if outside the area
      }

      // Check if current position matches the selected destination
      if (_isMoving && _isAtDestination(currentPosition)) {
        // Proceed with movement logic since the user has reached the selected destination
        // Smooth the movement if we have a previous position (optional)
        if (_previousPosition != null) {
          currentPosition = _smoothLocation(currentPosition, _previousPosition!, 0.3);
        }

        _previousPosition = currentPosition; // Store this as previous for the next tick

        // Find the nearest point on the path to the current position
        int closestPointIndex = _findClosestPointIndex(path, currentPosition);

        // Movement logic based on GPS data
        LatLng closestPoint = path[closestPointIndex];
        LatLng nextPoint = closestPointIndex < path.length - 1 ? path[closestPointIndex + 1] : closestPoint;

        // Calculate the distance between the current position and the next point
        double distanceToNextPoint = calculateonelinedistance(currentPosition, nextPoint);

        // Use the speed from GPS to calculate the distance covered
        double speedInMetersPerSecond = position.speed;
        double distanceCoveredInThisTickKM = (speedInMetersPerSecond * updateInterval) / 1000.0;
        segmentDistanceCoveredKM += distanceCoveredInThisTickKM;

        // If the distance covered exceeds the distance to the next point, update index
        if (segmentDistanceCoveredKM >= distanceToNextPoint) {
          _currentPointIndex = closestPointIndex + 1;
          segmentDistanceCoveredKM = 0.0; // Reset segment distance for the next point
        }

        distanceCoveredInWholeJourney += distanceCoveredInThisTickKM;

        // Check if the current segment is part of the selected spray path
        bool isSelectedSegment = _isSegmentSelected(path, selectedSegments, closestPointIndex, PathDirection.horizontal);

        if (isSelectedSegment) {
          totalDistanceCoveredKM_SelectedPath += distanceCoveredInThisTickKM;
          double remainingDistanceKM_SelectedPath = _totalDistanceKM - totalDistanceCoveredKM_SelectedPath;

          // Update distance and time for the selected segments
          setState(() {
            _remainingDistanceKM_SelectedPath = remainingDistanceKM_SelectedPath.clamp(0.0, _totalDistanceKM);
            _storeTimeLeftInDatabase(_remainingDistanceKM_SelectedPath);
          });

          // Sync selected path distance with Firebase if covered > 0.5km
          if (totalDistanceCoveredKM_SelectedPath % 0.5 == 0) {
            FirebaseDatabase.instance.ref().child('remainingDistance').set(_remainingDistanceKM_SelectedPath);
          }
        }

        // Update remaining total path distance
        setState(() {
          _remainingDistanceKM_TotalPath = (totalZigzagPathKm - distanceCoveredInWholeJourney)
              .clamp(0.0, totalZigzagPathKm);
        });

        // Update car marker position in real-time
        setState(() {
          _markers.removeWhere((marker) => marker.markerId == const MarkerId('car'));
          Add_Car_Marker(isSelectedSegment);

          // Ensure car marker stays exactly at the current GPS position
          _addLiveLocationMarker(true, currentPosition);
        });

        // End of path reached, stop movement
        if (_currentPointIndex >= path.length - 1) {
          _isMoving = false;
          _gpsStreamSubscription?.cancel();
          _onPathComplete();
        }
      }
    });

    // Timer to check Snackbar status every second
    Timer.periodic(const Duration(seconds: 45), (Timer timer) {
      if (!_isMoving) {
        timer.cancel(); // Stop the timer if not moving
        return;
      }

    });
  }

// Function to determine if the current position is at the destination
  bool _isAtDestination(LatLng currentPosition) {
    // Check if current position is close enough to the selected destination
    const double epsilon = 0.0001; // Adjust this value based on precision needed
    return (currentPosition.latitude - _selectedStartingPoint!.latitude).abs() < epsilon &&
        (currentPosition.longitude - _selectedStartingPoint!.longitude).abs() < epsilon;
  }
// Helper function to add live location marker exactly at current position
  void _addLiveLocationMarker(bool isSelectedSegment, LatLng currentPosition) {
    _markers.add(
      Marker(
        markerId: const MarkerId('gps'),
        position: currentPosition, // Marker now uses exact current GPS position
        icon: isSelectedSegment
            ? spr_active
            : spr_active,
        ),
    );
  }
// Helper function for smoothing GPS updates
  LatLng _smoothLocation(LatLng currentPosition, LatLng previousPosition, double alpha) {
    return LatLng(
      alpha * currentPosition.latitude + (1 - alpha) * previousPosition.latitude,
      alpha * currentPosition.longitude + (1 - alpha) * previousPosition.longitude,
    );
  }
/// Utility function to check if a point is near any of the polyline paths
  bool _isPointOnPath(LatLng point, Set<Polyline> polylines) {
    for (Polyline polyline in polylines) {
      List<LatLng> path = polyline.points;
      for (int i = 0; i < path.length - 1; i++) {
        if (calculateonelinedistance(point, path[i]) < trackTolerance) {
          return true;
        }
      }
    }
    return false;
  }
  bool _isPointInsidePolygon(LatLng point, List<LatLng> polygonPoints) {
    int i, j = polygonPoints.length - 1;
    bool inside = false;

    for (i = 0; i < polygonPoints.length; i++) {
      if ((polygonPoints[i].longitude < point.longitude &&
          polygonPoints[j].longitude >= point.longitude ||
          polygonPoints[j].longitude < point.longitude &&
              polygonPoints[i].longitude >= point.longitude) &&
          (polygonPoints[i].latitude <= point.latitude ||
              polygonPoints[j].latitude <= point.latitude)) {
        if (polygonPoints[i].latitude +
            (point.longitude - polygonPoints[i].longitude) /
                (polygonPoints[j].longitude - polygonPoints[i].longitude) *
                (polygonPoints[j].latitude - polygonPoints[i].latitude) <
            point.latitude) {
          inside = !inside;
        }
      }
      j = i;
    }

    return inside;
  }
  //NAV DATA LOGIC
  void _fetchLocationData() async {
    // Fetch the location data asynchronously
    _currentLocation = await _location.getLocation();
    if (_currentLocation != null && _selectedStartingPoint != null) {
      _updateMarkersAndPolyline();
    }
  }


  bool isNavigating = false; // Track navigation state
  String? instruction; // To hold navigation instruction
  double remainingDistance = 0; // To hold remaining distance
  int eta = 0; // To hold ETA

  String _formatInstruction(String instruction) {
    // Remove <b> tags
    instruction = instruction.replaceAll(RegExp(r'<b>|</b>'), '');

    // Append arrow symbols
    instruction += ' ';
    if (instruction.contains('north')) {
      instruction += '↑';
    } else if (instruction.contains('south')) {
      instruction += '↓';
    } else if (instruction.contains('east')) {
      instruction += '→';
    } else if (instruction.contains('west')) {
      instruction += '←';
    }

    return instruction;
  }


  // Filtered location storage and smoothing factor
  LatLng? _lastFilteredLocation;
   double _smoothingFactor = 0.9; // Adjust as needed

  LatLng _filterLocation(LocationData newLocation) {
    // Initialize the last filtered location if it is null
    if (_lastFilteredLocation == null) {
      _lastFilteredLocation = LatLng(newLocation.latitude!, newLocation.longitude!);
      return _lastFilteredLocation!;
    }

    // Check if the new location is valid (within a reasonable jump distance)
    if (!_isValidLocation(_lastFilteredLocation!, LatLng(newLocation.latitude!, newLocation.longitude!))) {
      print('Ignoring large jump in location');
      return _lastFilteredLocation!;
    }

    // Check the accuracy of the new location
    if (newLocation.accuracy != null && newLocation.accuracy! > 20.0) {
      print('Skipping inaccurate location data');
      return _lastFilteredLocation!;
    }

    // Apply smoothing filter
    double filteredLatitude = _lastFilteredLocation!.latitude * _smoothingFactor +
        newLocation.latitude! * (1 - _smoothingFactor);
    double filteredLongitude = _lastFilteredLocation!.longitude * _smoothingFactor +
        newLocation.longitude! * (1 - _smoothingFactor);

    // Update and return the filtered location
    _lastFilteredLocation = LatLng(filteredLatitude, filteredLongitude);
    return _lastFilteredLocation!;
  }

  bool _isValidLocation(LatLng oldLocation, LatLng newLocation) {
    const double maxDistance = 1000.0; // Max 1 km jump
    double distance = Geolocator.distanceBetween(
      oldLocation.latitude, oldLocation.longitude,
      newLocation.latitude, newLocation.longitude,
    );
    return distance < maxDistance;
  }

  void _updateMarkersAndPolyline() async {
    if (_currentLocation != null && _selectedStartingPoint != null) {
      LatLng currentLatLng = _filterLocation(_currentLocation!); // Filtered location

      // Fetch the route data from Google Directions API
      final response = await getRoutePoints(currentLatLng, _selectedStartingPoint!);

      if (response == null || response.isEmpty) {
        print('No route points available');
        return;
      }

      setState(() {
        // Create source marker
        Marker sourceMarker = Marker(
          markerId: const MarkerId('source'),
          position: currentLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        );

        // Create destination marker
        Marker destinationMarker = Marker(
          markerId: const MarkerId('destination'),
          position: _selectedStartingPoint!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        );

        // Clear and update markers
        navmarkers.clear();
        navmarkers.add(sourceMarker);
        navmarkers.add(destinationMarker);

        // Decode route points
        List<LatLng> routePoints = _decodeRoutePoints(response);

        // Ensure the destination point is included
        if (routePoints.isNotEmpty &&
            (routePoints.last.latitude != _selectedStartingPoint!.latitude ||
                routePoints.last.longitude != _selectedStartingPoint!.longitude)) {
          routePoints.add(_selectedStartingPoint!);
        } else if (routePoints.isEmpty) {
          routePoints.add(_selectedStartingPoint!);
        }

        // Create polyline for the route
        Polyline polyline = Polyline(
          polylineId: const PolylineId('navroute'),
          color: Colors.redAccent,
          width: 4,
          geodesic: true,
          points: routePoints,
        );

        // Clear and add new polyline
        navpolylines.clear();
        navpolylines.add(polyline);

        // Move camera to fit the route bounds
        _googleMapController.animateCamera(
          CameraUpdate.newLatLngBounds(
            _boundsFromLatLngList(routePoints),
            50,
          ),
        );
      });
    }
  }
  List<LatLng> _decodeRoutePoints(dynamic response) {
    var legs = response['routes'][0]['legs'] as List;
    var steps = legs[0]['steps'] as List;

    List<LatLng> routePoints = [];
    for (var step in steps) {
      String encodedPolyline = step['polyline']['points'];
      routePoints.addAll(_decodePolyline(encodedPolyline));
    }
    return routePoints;
  }

  void _startNavigation() async {
    setState(() {
      isNavigating = true; // Set navigation state to true
    });

    bool reachedDestination = false;
    LocationData? currentLocation;
    int stepIndex = 0;

    List<dynamic> steps = await _getNavigationSteps(
      LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
      _selectedStartingPoint!,
    );

    while (!reachedDestination) {
      currentLocation = await _location.getLocation();
      LatLng currentLatLng = _filterLocation(currentLocation); // Use filtered location

      double distanceToDestination = _calculateDistance(currentLatLng, _selectedStartingPoint!);

      if (distanceToDestination < 1) {
        reachedDestination = true;
        _showSnackbar_connection(context, 'You have reached your destination!');
        return;
      }

      LatLng nextStepLocation = _getStepLatLng(steps[stepIndex]);
      double distanceToStep = _calculateDistance(currentLatLng, nextStepLocation);

      if (distanceToStep < 10) {
        if (stepIndex < steps.length - 1) {
          stepIndex++;
        } else {
          reachedDestination = true;
           _showSnackbar_connection(context,'You have reached your destination!');

          return;
        }
      }

      instruction = _formatInstruction(steps[stepIndex]['html_instructions']);
      remainingDistance = _calculateRemainingDistance(steps, stepIndex, currentLatLng);
      eta = _calculateETA(remainingDistance);

      List<LatLng> remainingRoute = _getRemainingRoutePoints(steps, stepIndex, currentLatLng);
      setState(() {
        navpolylines.clear();
        navpolylines.add(Polyline(
          polylineId: const PolylineId('navroute'),
          color: Colors.redAccent,
          width: 4,
          points: remainingRoute,
        ));
      });

      await Future.delayed(const Duration(seconds: 2));
    }
  }







/*
  void _startNavigation() async {
    setState(() {
      isNavigating = true; // Set navigation state to true
    });

    bool reachedDestination = false;
    LocationData? currentLocation;
    int stepIndex = 0;

    List<dynamic> steps = await _getNavigationSteps(
      LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!),
      _selectedStartingPoint!,
    );

    while (!reachedDestination) {
      currentLocation = await _location.getLocation();
      LatLng currentLatLng =
      LatLng(currentLocation.latitude!, currentLocation.longitude!);

      double distanceToDestination =
      _calculateDistance(currentLatLng, _selectedStartingPoint!);

      if (distanceToDestination < 1) {
        reachedDestination = true;
       _showSnackbar_connection (context, 'You have reached your destination!');
        return;
      }

      LatLng nextStepLocation = _getStepLatLng(steps[stepIndex]);
      double distanceToStep = _calculateDistance(currentLatLng, nextStepLocation);

      if (distanceToStep < 10) {
        if (stepIndex < steps.length - 1) {
          stepIndex++;
        } else {
          reachedDestination = true;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have reached your destination!')),
          );
          return;
        }
      }

      instruction = _formatInstruction(steps[stepIndex]['html_instructions']);
      remainingDistance = _calculateRemainingDistance(steps, stepIndex, currentLatLng);
      eta = _calculateETA(remainingDistance);

      List<LatLng> remainingRoute = _getRemainingRoutePoints(steps, stepIndex, currentLatLng);
      setState(() {
        navpolylines.clear();
        navpolylines.add(Polyline(
          polylineId: const PolylineId('navroute'),
          color: Colors.redAccent,
          width: 4,
          points: remainingRoute,
        ));
      });

      await Future.delayed(const Duration(seconds: 2));
    }
  }
  void _updateMarkersAndPolyline() async {
    if (_currentLocation != null && _selectedStartingPoint != null) {
      LatLng currentLatLng = LatLng(
        _currentLocation!.latitude!,
        _currentLocation!.longitude!,
      );

      // Fetch the route data from Google Directions API
      final response = await getRoutePoints(currentLatLng, _selectedStartingPoint!);

      if (response == null || response.isEmpty) {
        print('No route points available');
        return; // Stop execution if no route data is available
      }

      setState(() {
        // Create source marker
        Marker sourceMarker = Marker(
          markerId: const MarkerId('source'),
          position: currentLatLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        );

        // Create destination marker
        Marker destinationMarker = Marker(
          markerId: const MarkerId('destination'),
          position: _selectedStartingPoint!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRose),
        );

        // Clear existing markers
        navmarkers.clear();
        navmarkers.add(sourceMarker);
        navmarkers.add(destinationMarker);

        // Get the route points from the response
        var legs = response['routes'][0]['legs'] as List;
        var steps = legs[0]['steps'] as List;

        // Decode and store all the route points
        List<LatLng> routePoints = [];
        for (var step in steps) {
          String encodedPolyline = step['polyline']['points'];
          routePoints.addAll(_decodePolyline(encodedPolyline));
        }

        // Ensure the last point in routePoints matches the destination
        if (routePoints.isNotEmpty) {
          LatLng lastPoint = routePoints.last;
          if (lastPoint.latitude != _selectedStartingPoint!.latitude ||
              lastPoint.longitude != _selectedStartingPoint!.longitude) {
            routePoints.add(_selectedStartingPoint!); // Add the destination to ensure it’s included
          }
        } else {
          // If there are no route points, add the destination directly
          routePoints.add(_selectedStartingPoint!);
        }

        // Create polyline with the route points
        Polyline polyline = Polyline(
          polylineId: const PolylineId('navroute'),
          color: Colors.redAccent,
          width: 4,
          geodesic: true,
          points: routePoints,
        );

        // Clear existing polylines and add the new one
        navpolylines.clear();
        navpolylines.add(polyline);

        // Move the camera to the route bounds
        _googleMapController.animateCamera(
          CameraUpdate.newLatLngBounds(
            _boundsFromLatLngList(routePoints),
            50,
          ),
        );
      });
    }
  }
*/
  Widget _showNavigationCard() {
    if (!isNavigating) return Container(); // Return empty container if not navigating

    return Card(
      color: Colors.white, // Set card background color to white
      //color: Colors.white70,
      margin: const EdgeInsets.all(6),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              instruction ?? '',
              style:  TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.indigo[800], // Set instruction text color to indigo
                fontFamily:
                GoogleFonts.poppins().fontFamily,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Distance: ${remainingDistance.toStringAsFixed(1)} m  ',
                  style:  TextStyle(
                    color: Colors.black87, // Set distance text color to black
                    fontWeight: FontWeight.w500,
                    fontFamily: GoogleFonts.poppins().fontFamily,
                  ),
                ),
                Text(
                  'ETA: ${eta ~/ 60} min',
                  style: const TextStyle(
                    color: Colors.black87, // Set ETA text color to black
                    fontFamily: 'Poppins', // Use Google Fonts Poppins
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  Future<List<dynamic>> _getNavigationSteps(LatLng origin, LatLng destination) async {final response = await getRoutePoints(origin, destination);

  if (response != null && response.isNotEmpty) {
    final legs = response['routes'][0]['legs'] as List;
    if (legs.isNotEmpty) {
      return legs[0]['steps']; // Extract steps from the first leg
    }
  }
  return [];
  }
  Future<Map<String, dynamic>?> getRoutePoints(LatLng origin, LatLng destination) async {
    const String apiKey = 'AIzaSyDNToFfTa1a7WqcxS1PlC382Oem1MpHeHA'; // Replace with your API key
    final String url =
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&mode=walking&key=$apiKey'; // Use walking mode


    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return data; // Return the entire response
        } else {
          print('API Error: ${data['status']}');
        }
      } else {
        print('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception: $e');
    }
    return null; // Return null if any error occurs
  }
  List<LatLng> _decodePolyline(String polyline) {
    List<LatLng> coordinates = [];
    int index = 0, len = polyline.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      final LatLng point = LatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble());
      coordinates.add(point);
    }

    // Add a small offset to the coordinates to ensure they are not exactly on the road
    for (int i = 0; i < coordinates.length; i++) {
      coordinates[i] = LatLng(coordinates[i].latitude + 0.00001, coordinates[i].longitude + 0.00001);
    }

    return coordinates;
  }
  LatLngBounds _boundsFromLatLngList(List<LatLng> list) {
    if (list.isEmpty) {
      throw Exception('LatLng list is empty. Cannot calculate bounds.');
    }

    double x0 = list.first.latitude, x1 = list.first.latitude;
    double y0 = list.first.longitude, y1 = list.first.longitude;

    for (LatLng latLng in list) {
      if (latLng.latitude > x1) x1 = latLng.latitude;
      if (latLng.latitude < x0) x0 = latLng.latitude;
      if (latLng.longitude > y1) y1 = latLng.longitude;
      if (latLng.longitude < y0) y0 = latLng.longitude;
    }

    return LatLngBounds(
      northeast: LatLng(x1, y1),
      southwest: LatLng(x0, y0),
    );
  }



// Helper: Extract LatLng from a step
  LatLng _getStepLatLng(dynamic step) {
    return LatLng(
      step['end_location']['lat'],
      step['end_location']['lng'],
    );
  }
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double R = 6371000; // Earth's radius in meters
    double dLat = _degreesToRadians(point2.latitude - point1.latitude);
    double dLng = _degreesToRadians(point2.longitude - point1.longitude);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(point1.latitude)) *
            cos(_degreesToRadians(point2.latitude)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }
// Helper: Calculate remaining distance from current position
  double _calculateRemainingDistance(List<dynamic> steps, int stepIndex, LatLng currentLocation) {
    double remainingDistance = _calculateDistance(
        currentLocation, _getStepLatLng(steps[stepIndex]));

    for (int i = stepIndex + 1; i < steps.length; i++) {
      remainingDistance += steps[i]['distance']['value'];
    }
    return remainingDistance;
  }
// Helper: Calculate estimated time of arrival (ETA) in seconds
  int _calculateETA(double remainingDistance) {
    const double averageWalkingSpeed = 1.4; // meters per second
    return (remainingDistance / averageWalkingSpeed).round();
  }
// Helper: Get remaining route points from the steps
  List<LatLng> _getRemainingRoutePoints(List<dynamic> steps, int stepIndex, LatLng currentLocation) {List<LatLng> points = [currentLocation];

    for (int i = stepIndex; i < steps.length; i++) {
      points.add(_getStepLatLng(steps[i]));
    }

    return points;
  }







// Add the markers to the set
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
        toolbarHeight: 170, // Increased height to accommodate marquee
        flexibleSpace: Padding(
          padding: const EdgeInsets.fromLTRB(10, 30, 10, 0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // First Row: Logo, Title, Notification Icon, Three Dots Icon
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
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
                        color: Colors.white,
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
                            color: Colors.black,
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
                            const SizedBox(width: 2),
                            IconButton(
                              icon: const Icon(
                                Icons.logout_outlined,
                                color: Colors.black,
                                size: 25,
                              ),
                              onPressed: () async {
                                context.read<ISSAASProvider>().setIsSaas(false);
                                try {
                                  await FirebaseAuth.instance.signOut();
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => LoginScreen(),
                                    ),
                                  );
                                } catch (e) {
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
                  if (!context.read<ISSAASProvider>().isSaas)
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
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 7),
                                    Center(
                                      child: Text(
                                        "Manual Mode",
                                        style: TextStyle(
                                          color: Colors.indigo[800],
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
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const SizedBox(width: 7),
                                    Center(
                                      child: Text(
                                        "Autonomous Mode",
                                        style: TextStyle(
                                          color: Colors.indigo[800],
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
                          ),

                  if (context.read<ISSAASProvider>().isSaas)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 5, 15, 5),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(5, 1, 0, 0),
                        width: 145,
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
                            borderRadius:
                                BorderRadius.circular(10), // Rounded corners
                          ),
                          child: Row(
                            children: [
                              Image.asset(
                                'images/mobile.png', // Path to your mobile image
                                height: 30,
                                width: 30,
                              ),
                              const SizedBox(width: 8),
                              Center(
                                child: Text(
                                  "SaaS Version",
                                  style: TextStyle(
                                    color: Colors.indigo[
                                        800], // Text color set to indigo
                                    fontWeight: FontWeight.w600,
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
                    ),
                ],
              ),
              // Add Marquee if in Manual Mode

              if (_isCustomMode) // Replace with your actual condition
                Container(
                  height: 40,
                  margin: const EdgeInsets.only(top: 10),
                  width: MediaQuery.of(context).size.width,
                  decoration: BoxDecoration(
                    color: Colors.red.shade900,
                    borderRadius: BorderRadius.circular(10),
                  ), // Make sure it fits the screen
                  child: ClipRect(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Transform.translate(
                          offset: Offset(-_offset, 0),
                          child: Row(
                            children: [
                              Consumer<ISSAASProvider>(
                                builder: (context, issaasProvider, child) {
                                  return Text(
                                    issaasProvider.isSaas
                                        ? 'Manual Sprayer Mode: Try to Stay Inside Your field'
                                        : 'Manual Coordinate Method: DO NOT PLACE MARKER OUTSIDE THE SHADED AREA',
                                    style: TextStyle(
                                      fontFamily: GoogleFonts.poppins().fontFamily,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  );
                                },
                              ),
                              SizedBox(
                                  width: 50), // Adding space between repeats
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [

            if (!Provider.of<ISSAASProvider>(context).isSaas)
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
                                value:
                                    '${_calculateSphericalPolygonArea(_markerPositions).toStringAsFixed(2)} ac',
                                color: Colors.indigo[800]!,
                                icon: Icons.location_on,
                              ),
                              _CardItem(
                                title: 'Total',
                                value:
                                    '${totalZigzagPathKm.toStringAsFixed(2)} Km',
                                color: Colors.deepPurple[800]!,
                                icon: Icons.directions,
                              ),
                              _CardItem(
                                title: 'Spray',
                                value:
                                    '${_totalDistanceKM.toStringAsFixed(2)} Km',
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
                                            Icons
                                                .shower_outlined, // replace with your desired icon
                                            color: Colors.black87,
                                            weight: 10,
                                          ),
                                          const SizedBox(
                                              width:
                                                  5), // space between icon and text
                                          Text(
                                            "Rem Spray:",
                                            style: TextStyle(
                                              color: Colors.amber[900],
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              fontFamily: GoogleFonts.poppins()
                                                  .fontFamily,
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
                                              height:
                                                  100, // Adjust size as needed
                                              width:
                                                  70, // Adjust size as needed
                                              fit: BoxFit.contain,
                                            ),
                                            // Remaining spray represented by a container
                                            Positioned(
                                              bottom:
                                                  16.3, // Align with the bottom of the bottle body
                                              left:
                                                  3.5, // Adjust left offset if necessary

                                              // Wrap the FractionallySizedBox inside a SizedBox with a fixed height
                                              child: SizedBox(
                                                height:
                                                    42, // Adjust to fit the height of the bottle body
                                                child: FractionallySizedBox(
                                                  alignment:
                                                      Alignment.bottomLeft,
                                                  heightFactor: (_totalDistanceKM !=
                                                          0)
                                                      ? _remainingDistanceKM_SelectedPath /
                                                          _totalDistanceKM
                                                      : 0.0, // Proportional height
                                                  child: Container(
                                                    width:
                                                        20, // Width matching the image or as needed
                                                    decoration: BoxDecoration(
                                                      gradient:
                                                          const LinearGradient(
                                                        colors: [
                                                          Colors.red,
                                                          Colors.green
                                                        ],
                                                        begin: Alignment
                                                            .bottomCenter,
                                                        end:
                                                            Alignment.topCenter,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6), // Rounded edges for the liquid
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
                                const SizedBox(
                                    width: 2), // spacing between rows

                                // Second row
                                Expanded(
                                  child: Row(
                                    children: [
                                      // Watch Icon with Circular Progress Indicator
                                      const Icon(
                                        Icons
                                            .timer_outlined, // replace with your desired icon
                                        color: Colors.black87,
                                        weight: 10,
                                      ),
                                      const SizedBox(
                                          width:
                                              5), // space between icon and text

                                      // "Rem Time" Text
                                      Text(
                                        "Rem Time:",
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          fontFamily:
                                              GoogleFonts.poppins().fontFamily,
                                        ),
                                      ),
                                      const SizedBox(
                                          width:
                                              0), // Spacing between icon and text

                                      SizedBox(
                                        width: 60, // Adjust width as needed
                                        height: 60, // Adjust height as needed
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            // Watch icon image
                                            Image.asset(
                                              'images/watch.png', // Your sprayer image asset path
                                              height:
                                                  100, // Adjust size as needed
                                              width:
                                                  70, // Adjust size as needed
                                              fit: BoxFit.contain,
                                            ),

                                            // Filled circle (inside the CircularProgressIndicator)
                                            Positioned(
                                              bottom:
                                                  18.5, // Align with the bottom of the watch body
                                              left:
                                                  25.3, // Adjust left offset if necessary
                                              child: SizedBox(
                                                width:
                                                    10, // Adjust size as needed
                                                height: 10,
                                                child: Stack(
                                                  alignment: Alignment.center,
                                                  children: [
                                                    // Filled background circle

                                                    // Circular progress indicator (on top of the filled circle)
                                                    CircularProgressIndicator(
                                                      value: (TLM != null &&
                                                              timeduration !=
                                                                  null &&
                                                              timeduration != 0)
                                                          ? 1 -
                                                              (TLM /
                                                                  timeduration) // Progress value based on remaining time, progressing clockwise
                                                          : 0.0, // No progress initially
                                                      strokeWidth:
                                                          31, // Adjust the stroke width for the progress bar
                                                      valueColor:
                                                          const AlwaysStoppedAnimation<
                                                                  Color>(
                                                              Colors
                                                                  .red), // Red progress color for the stroke
                                                      backgroundColor: Colors
                                                          .green, // Set background to transparent
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
                                      Icons
                                          .route_outlined, // replace with your desired icon
                                      color: Colors.black87,
                                    ),
                                    const SizedBox(
                                        width:
                                            5), // space between icon and text
                                    Text(
                                      "Rem Dis:",
                                      style: TextStyle(
                                        color: Colors.indigo[800],
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                        fontFamily:
                                            GoogleFonts.poppins().fontFamily,
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
                                        border: Border.all(
                                            color: Colors.black,
                                            width: 1.3), // Black border
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(10)),
                                      ),
                                      child: LinearPercentIndicator(
                                        lineHeight: 10,
                                        percent: (totalZigzagPathKm != 0)
                                            ? _remainingDistanceKM_TotalPath /
                                                totalZigzagPathKm
                                            : 0.0, // default to 0 if values are invalid
                                        linearGradient: const LinearGradient(
                                          colors: [
                                            Colors.red,
                                            Colors.green
                                          ], // White
                                        ),
                                        backgroundColor: Colors.grey[200],
                                        barRadius: const Radius.circular(10),
                                        padding: EdgeInsets
                                            .zero, // Remove extra padding
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
                  ? Column(
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
                                  _isMoving = true;
                                  if (widget.groundMode) {
                                    _startManualMovement_UGV(
                                        _dronepath, _selectedPathsQueue,
                                        forward:
                                            false); // Start backward movement
                                  } else {
                                    _startManualMovement_UAV(
                                        _selectedPathsQueue,
                                        forward:
                                            false); // Start backward movement
                                  }
                                });
                              },
                              onTapUp: (TapUpDetails details) {
                                setState(() {
                                  _isbackwardPressed = false;
                                  _isMoving = false;
                                });
                                stopMovement(); // Stop movement when button released
                              },
                              child: Image.asset(
                                _isbackwardPressed
                                    ? 'images/bwd_active.png'
                                    : 'images/bwd.png',
                                width: 50,
                                height: 50,
                              ),
                            ),
                            const SizedBox(width: 5),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  stopMovement(); // Stop movement function called
                                });
                              },
                              child: Image.asset(
                                'images/stop.png',
                                width: _isStop ? 45 : 35,
                                height: _isStop ? 45 : 35,
                              ),
                            ),
                            const SizedBox(width: 5),
                            GestureDetector(
                              onTapDown: (TapDownDetails details) {
                                setState(() {
                                  _isforwardPressed = true;
                                  _isMoving = true;
                                  if (widget.groundMode) {
                                    _startManualMovement_UGV(
                                        _dronepath, _selectedPathsQueue,
                                        forward:
                                            true); // Start forward movement
                                  } else {
                                    _startManualMovement_UAV(
                                        _selectedPathsQueue,
                                        forward:
                                            true); // Start forward movement
                                  }
                                });
                              },
                              onTapUp: (TapUpDetails details) {
                                setState(() {
                                  _isforwardPressed = false;
                                  _isMoving = false;
                                });
                                stopMovement(); // Stop movement when button released
                              },
                              child: Image.asset(
                                _isforwardPressed
                                    ? 'images/fwd_active.png'
                                    : 'images/fwd.png',
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
                          color: Colors.white, size: 18), // Reduced icon size
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), // Reduced padding
              child: ClipRRect(
                borderRadius: BorderRadius.circular(15.0), // Capsule shape
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white70,
                    border: Border.all(color: Colors.grey.shade300, width: 1.0), // Subtle border
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: Offset(0, 2), // Shadow for better visibility
                      ),
                    ],
                  ),
                  child: Column(

                    children: [
                      // TypeAheadField remains untouched
                      TypeAheadField<geocoding.Placemark>(
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
                              fontWeight: FontWeight.w600,
                              fontSize: 14.0,
                              color: const Color(0xFF037441),
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search, color: Colors.black),
                              onPressed: _hideKeyboard, // Hide keyboard on search button press
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          ),
                        ),
                        suggestionsCallback: (pattern) {
                          if (pattern.isEmpty) {
                            return Future.value(<geocoding.Placemark>[]);
                          }
                          _debounce?.cancel();
                          final completer = Completer<List<geocoding.Placemark>>();
                          _debounce = Timer(const Duration(milliseconds: 300), () async {
                            List<geocoding.Placemark> placemarks = [];
                            try {
                              List<geocoding.Location> locations = await geocoding.locationFromAddress(pattern);
                              if (locations.isNotEmpty) {
                                placemarks = await Future.wait(
                                  locations.map((location) => geocoding.placemarkFromCoordinates(
                                    location.latitude,
                                    location.longitude,
                                  )),
                                ).then((results) => results.expand((x) => x).toList());
                              }
                            } catch (e) {
                              // Handle error if needed
                            }
                            completer.complete(placemarks);
                          });
                          return completer.future;
                        },
                        itemBuilder: (context, geocoding.Placemark suggestion) {
                          return ListTile(
                            leading: const Icon(Icons.location_on, color: Colors.green),
                            title: Text(
                              suggestion.name ?? 'No Country/City Available',
                              style: TextStyle(
                                fontFamily: GoogleFonts.poppins().fontFamily,
                                fontSize: 16.0,
                                fontWeight: FontWeight.w400,
                                color: Colors.black,
                              ),
                            ),
                            subtitle: Text(
                              suggestion.locality ?? 'No locality Exists',
                              style: TextStyle(
                                fontFamily: GoogleFonts.poppins().fontFamily,
                                fontSize: 14.0,
                                color: Colors.black54,
                              ),
                            ),
                          );
                        },
                        onSuggestionSelected: (geocoding.Placemark suggestion) async {
                          final address = '${suggestion.name ?? ''}, ${suggestion.locality ?? ''}';
                          try {
                            List<geocoding.Location> locations = await geocoding.locationFromAddress(address);
                            if (locations.isNotEmpty) {
                              final location = locations.first;

                              // Set the selected destination point
                              setState(() {
                                _selectedStartingPoint = LatLng(location.latitude, location.longitude);
                              });

                              // Animate camera to selected location
                              _googleMapController.animateCamera(
                                CameraUpdate.newCameraPosition(
                                  CameraPosition(
                                    target: LatLng(location.latitude, location.longitude),
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


                      if (_currentLocation != null) Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 5.0),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.green, size: 20), // Icon for current location
                            const SizedBox(width: 5),
                            Text(
                              'Starting Point:',

                              style: TextStyle(
                                fontFamily: GoogleFonts.poppins().fontFamily,
                                fontSize: 14.0, // Smaller font
                                color: Colors.black,
                                fontWeight: FontWeight.w700, // Bold font
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.blueAccent),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  '${_currentLocation!.latitude?.toStringAsFixed(4)}, ${_currentLocation!.longitude?.toStringAsFixed(4)}',
                                  style: TextStyle(
                                    fontFamily: GoogleFonts.poppins().fontFamily,
                                    fontSize: 13.0, // Smaller font
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),

                              ),
                            ),
                          ],
                        ),
                      ),

                      if (_selectedStartingPoint != null) Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 25.0, vertical: 5.0),
                        child: Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.red, size: 20), // Icon for destination
                            const SizedBox(width: 5),
                            Text(
                              'Current Position:',

                              style: TextStyle(
                                fontFamily: GoogleFonts.poppins().fontFamily,
                                fontSize: 14.0, // Smaller font
                                color: Colors.black,
                                fontWeight: FontWeight.w700, // Bold font
                              ),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.blueAccent),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  '${_selectedStartingPoint!.latitude.toStringAsFixed(4)}, ${_selectedStartingPoint!.longitude.toStringAsFixed(4)}',
                                  style: TextStyle(
                                    fontFamily: GoogleFonts.poppins().fontFamily,
                                    fontSize: 13.0, // Smaller font
                                    color: Colors.black87,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedStartingPoint != null)
                        Center(
                          child: Container(
                            width: double.infinity, // custom width
                            child: Row(
                              children: [
                                if (isNavigating)
                                  Center(
                                    child: _showNavigationCard(), // Center the navigation card
                                  )
                                else
                                  Container(
                                    width: 130, // custom width for FAB
                                    height: 55, // custom height for FAB
                                    child: FloatingActionButton.extended(
                                      onPressed: () {
                                        _startNavigation(); // Call the function when FAB is pressed
                                      },
                                      backgroundColor: Colors.indigo[800], // FAB background color
                                      label: Text(
                                        'Navigate',
                                        style: TextStyle(
                                          fontFamily: GoogleFonts.poppins().fontFamily,
                                          fontSize: 14.0, // Smaller font
                                          color: Colors.white, // Text color
                                          fontWeight: FontWeight.w700, // Bold font
                                        ),
                                      ),
                                      icon: const Icon(Icons.navigation, color: Colors.white), // Icon color
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
                          :RepaintBoundary(
                        key: _googleMapKey, // Attach the key to GoogleMap
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: _currentLocation != null
                                ? LatLng(_currentLocation!.latitude!, _currentLocation!.longitude!)
                                : LatLng(0, 0), // Default fallback position
                            zoom: _currentLocation != null ? 25.0 : 4.0, // Zoom in when current location is available
                          ),
                          markers: {
                            ..._markers,
                            if (Provider.of<ISSAASProvider>(context).isSaas) ...navmarkers,
                          },
                          polylines: {
                            ..._polylines,
                            if (Provider.of<ISSAASProvider>(context).isSaas &&
                                _selectedStartingPoint != null &&
                                _currentLocation != null) ...navpolylines,
                          },
                          polygons: {
                            if (!Provider.of<ISSAASProvider>(context).isSaas)
                              ..._FieldPolygons, // Load field detection polygons only if not in SaaS mode
                            ...polygons, // Always load custom polygons
                          },
                          mapType: MapType.hybrid, // Set the map type to Satellite view
                          zoomGesturesEnabled: true,
                          rotateGesturesEnabled: true,
                          scrollGesturesEnabled: true,
                          buildingsEnabled: true,
                          onTap: _isCustomMode ? _onMapTap : null,
                          myLocationEnabled: true,
                          myLocationButtonEnabled: true,
                          onMapCreated: (controller) {
                            _googleMapController = controller;
                            // Camera animation is now handled separately.
                            _checkCityAndFetchData(); // Fetch and display Field data on map creation
                            _updateMarkersAndPolyline();
                          },
                          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                            Factory<OneSequenceGestureRecognizer>(
                                    () => EagerGestureRecognizer()),
                          },

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
    if (context.read<ISSAASProvider>().isSaas) {

        // Place subsequent markers - NO FIELD CHECK
        final markerId = MarkerId('M${_markers.length + 1}');
        final newMarker = Marker(
          markerId: markerId,
          position: latLng,
          icon: BitmapDescriptor.defaultMarkerWithHue(
              _selectedMarkerId == markerId
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

          if (_markers.length > 1) {
            _updatePolylines();
            _updateRouteData();
          }
        });
      } else {
      // If ISSAAS is false:
      // FIELD CHECK IS ENABLED for ALL markers
      bool isNotOnField = !_isPointInAnyPolygon(latLng);

      if (isNotOnField) {
        _showSnackbar(
            context, 'Cannot place marker. Please Tap On shaded areas');
        return;
      }

      final markerId = MarkerId('M${_markers.length + 1}');
      final newMarker = Marker(
        markerId: markerId,
        position: latLng,
        icon: BitmapDescriptor.defaultMarkerWithHue(
            _selectedMarkerId == markerId
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

        if (_markers.length > 1) {
          _updatePolylines();
          _updateRouteData();
        }
      });
    }
  }
  bool _isPointInAnyPolygon(LatLng point) {
    for (Polygon polygon in _FieldPolygons) {
      if (_isPointInPolygon(point, polygon)) {
        return true;
      }
    }
    return false;
  }
  bool _isPointInPolygon(LatLng point, Polygon polygon) {
    int intersections = 0;
    for (int i = 0; i < polygon.points.length - 1; i++) {
      LatLng p1 = polygon.points[i];
      LatLng p2 = polygon.points[i + 1];

      if (_rayCrossesSegment(point, p1, p2)) {
        intersections++;
      }
    }
    // If the number of intersections is odd, the point is inside the polygon
    return (intersections % 2 == 1);
  }
  bool _rayCrossesSegment(LatLng point, LatLng p1, LatLng p2) {
    // Ensure p1 has a smaller y-coordinate than p2
    if (p1.latitude > p2.latitude) {
      LatLng temp = p1;
      p1 = p2;
      p2 = temp;
    }

    // Check if the point is out of the vertical bounds of the segment
    if (point.latitude == p1.latitude || point.latitude == p2.latitude) {
      point = LatLng(point.latitude + 0.00001,
          point.longitude); // Small offset to avoid collinear points
    }

    if (point.latitude < p1.latitude || point.latitude > p2.latitude) {
      return false;
    }

    // Check if the point is to the right of the segment
    if (point.longitude >= max(p1.longitude, p2.longitude)) {
      return false;
    }

    if (point.longitude < min(p1.longitude, p2.longitude)) {
      return true;
    }

    double slope = (p2.longitude - p1.longitude) / (p2.latitude - p1.latitude);
    double intersectionLongitude =
        p1.longitude + (point.latitude - p1.latitude) * slope;

    return point.longitude < intersectionLongitude;
  }
  Future<void> _checkCityAndFetchData() async {
    String cityName = weatherController.weather.value.cityname;

    if (cityName.isEmpty) {
      print("City name is still loading...");
      return; // Wait until city name is loaded
    }

    switch (cityName.toLowerCase()) {
      case 'islamabad':
        await _fetchFieldData(
            'https://overpass-api.de/api/interpreter?data=[out:json];area["landuse"~"grass|meadow|farmland|orchard|village_green|recreation_ground|park|garden|allotments"](33.6600,73.1000,34.2000,73.3000);(._;>;);out;');
        break;
      case 'australia':
        await _fetchFieldData(
            'https://overpass-api.de/api/interpreter?data=[out:json];area["landuse"~"grass|meadow|farmland|orchard|village_green|recreation_ground|park|garden|allotments"](33.6600,73.1000,34.2000,73.3000);(._;>;);out;');
        break;
      case 'rawalpindi':
        await _fetchFieldData(
            'https://overpass-api.de/api/interpreter?data=[out:json];area["landuse"~"grass|meadow|farmland|orchard|village_green|recreation_ground|park|garden|allotments"](33.5667,73.0500,33.7167,73.2000);(._;>;);out;');
        break;
      case 'lahore':
        await _fetchFieldData(
            'https://overpass-api.de/api/interpreter?data=[out:json];area["landuse"~"grass|meadow|farmland|orchard|village_green|recreation_ground|park|garden|allotments"](31.4000,73.0300,31.6000,74.4000);(._;>;);out;');
        break;
      case 'karachi':
        await _fetchFieldData(
            'https://overpass-api.de/api/interpreter?data=[out:json];area["landuse"~"grass|meadow|farmland|orchard|village_green|recreation_ground|park|garden|allotments"](24.8500,66.8500,25.2000,67.2000);(._;>;);out;');
        break;
      case 'quetta':
        await _fetchFieldData(
            'https://overpass-api.de/api/interpreter?data=[out:json];area["landuse"~"grass|meadow|farmland|orchard|village_green|recreation_ground|park|garden|allotments"](30.1000,66.8500,30.3000,67.0000);(._;>;);out;');
        break;
      default:
        print('City not recognized for fetching Field data.');
        break;
    }
  }
  Future<void> _fetchFieldData(String url) async {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      try {
        final data = jsonDecode(response.body);
        _processFieldData(data);
      } catch (e) {
        print('Error decoding JSON: $e');
      }
    } else {
      throw Exception('Failed to fetch Field data');
    }
  }
  void _processFieldData(Map<String, dynamic> data) {
    Map<int, LatLng> nodes = {}; // To store all nodes with their coordinates
    List<Polygon> polygons = [];

    // First, extract all the nodes
    for (var element in data['elements']) {
      if (element['type'] == 'node') {
        nodes[element['id']] = LatLng(element['lat'], element['lon']);
      }
    }

    // Now, go through the ways and build polygons using the nodes
    for (var element in data['elements']) {
      if (element['type'] == 'way') {
        List<LatLng> polygonPoints = [];

        // Add points to the polygon by referencing the node IDs
        for (var nodeId in element['nodes']) {
          if (nodes.containsKey(nodeId)) {
            polygonPoints
                .add(nodes[nodeId]!); // Add the LatLng from the node map
          }
        }

        polygons.add(Polygon(
          polygonId: PolygonId('area_${element['id']}'),
          points: polygonPoints,
          strokeColor: Colors.purpleAccent.shade700,
          strokeWidth: 3,
          fillColor: Colors.purpleAccent.withOpacity(0.1),
        ));
      }
    }

    // Update the state to display the polygons
    setState(() {
      _FieldPolygons = polygons.toSet(); // Ensure you use Set<Polygon>
    });
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
void _showSnackbar_connection(BuildContext context, String message) {
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
      backgroundColor: Colors.green.withOpacity(0.8),
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
class _CardItem extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  _CardItem(
      {required this.title,
      required this.value,
      required this.color,
      required this.icon});

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
