import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:project_drone/Screens/homescreen.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:location/location.dart';
import '../shared_state.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:latlong2/latlong.dart' as latlong;
import 'package:flutter_asset_manager/flutter_asset_manager.dart';
import 'package:http/http.dart' as http;

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
  bool _isConfirmed = false;
  bool _ismanual = false;
  late LatLng _carPosition;
  int _currentPointIndex = 0;
  late List<Marker> _markers = [];
  final List<LatLng> _markerPositions = [];
  Set<Polyline> _polylines = {};
  Set<Polygon> polygons = {};
  List<LatLng> _dronepath = [];
  double pathWidth = 10.0;
bool _isHorizontalDirection=false;
  late LatLng? selectedMarker =
  _markers.isNotEmpty ? _markers.first.position : null;

  late GoogleMapController _googleMapController;
  final DatabaseReference _databaseReference = FirebaseDatabase.instance.ref();
  Timer? _movementTimer;
  bool _isCustomMode = false;
  bool _isShapeClosed = false;
  double _remainingDistanceKM_TotalPath = 0.0;
  List<LatLng> polygonPoints = [];

  //USER SELECTION RECEIPT

  String _selectedMethod = 'N/A'; // Variable to store selected method
  String? _selectedFileSource =
      'N/A in Manual Mode'; // To store the file source (Local or Cloud)
  String? _selectedLocalFile =
      'N/A in Manual Mode'; // To store the selected local file
  String? _selectedCloudFile =
      'N/A in Manual Mode'; // To store the selected cloud file
  double _turnLength = 5.0; // To store turn length
  LatLng? _selectedStartingPoint; // To store the selected starting point

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
    if (path.isEmpty) {
      print("Path is empty, cannot start movement");
      return;
    }

    setState(() {
      _carPosition = path[0];
      _currentPointIndex = 0;
    });

    // Use the boolean to decide which marker function to call
    if (_isHorizontalDirection) {
      Add_Car_Marker_Horizantal(_isSegmentSelected(path, selectedSegments, 0));
    } else {
      Add_Car_Marker_Vertical(_isSegmentSelected(path, selectedSegments, 0));
    }

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

        bool isSelectedSegment = _isSegmentSelected(path, selectedSegments, _currentPointIndex);
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
          _remainingDistanceKM_TotalPath = (totalZigzagPathKm - distanceCoveredInWholeJourney)
              .clamp(0.0, totalZigzagPathKm);
        });

        setState(() {
          _markers.removeWhere((marker) => marker.markerId == const MarkerId('car'));

          // Use the boolean to decide which marker function to call
          if (_isHorizontalDirection) {
            Add_Car_Marker_Horizantal(isSelectedSegment);
          } else {
            Add_Car_Marker_Vertical(isSelectedSegment);
          }

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
                              _isHorizontalDirection = (value == PathDirection.horizontal);
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
                              _isHorizontalDirection = (value == PathDirection.horizontal);
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
                        ? _markers.sublist(0, _markers.length)
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
                        isStartingPointEmpty = false; // Reset error state
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

    // Trigger the success dialog after path completion
    ShowSuccessDialog();
  }

// Check if the current segment is part of the selected route
  bool _isSegmentSelected(List<LatLng> path, List<List<LatLng>> selectedSegments, int index) {
    if (index < path.length - 1) {
      LatLng start = path[index];
      LatLng end = path[index + 1];

      for (var segment in selectedSegments) {
        print("Checking Segment: $segment vs [$start, $end]"); // Debug log
        if (_isSegmentEqual([start, end], segment)) {
          return true;
        }
      }
    }
    return false;
  }
// Compare two segments for equality
  bool _isSegmentEqual(List<LatLng> segment1, List<LatLng> segment2) {
    return (segment1[0] == segment2[0] && segment1[1] == segment2[1]) ||
        (segment1[0] == segment2[1] && segment1[1] == segment2[0]);
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
  Future<void> Add_Car_Marker_Horizantal(bool isSelectedSegment) async {
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
  Future<void> Add_Car_Marker_Vertical(bool isSelectedSegment) async {
    setState(() {
      _markers.add(Marker(
        markerId: const MarkerId('car'),
        position: LatLng(_carPosition.latitude, _carPosition.longitude),
        icon: isSelectedSegment
            ? ugv_dead
            : ugv_active, // Set the car marker based on the segment selection
      ));
    });
  }
  void ShowSuccessDialog() {
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
              SvgPicture.asset(
                'images/success.svg', // Replace with your SVG image asset path
                width: 300,
                height: 300,
              ),
              const SizedBox(
                  height:
                  5), // Add some space between the image and the button
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
                  const SizedBox(
                      width:
                      10), // Add some space between the icon and the text
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
                      text: _selectedLocalFile ?? _selectedCloudFile ?? 'None',
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
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo[800],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Close the dialog

                _showRoutesDialog();
              },
              child: Text(
                'Proceed',
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
  void _showRoutesDialog() {
    List<int> selectedSegments = [];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              titlePadding: EdgeInsets.zero, // Remove default padding
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
                        // Validation: Ensure at least one route is selected
                        if (selectedSegments.isEmpty) {
                          _showWarningDialog(
                              context); // Show warning if no routes are selected
                          return;
                        }

                        Navigator.of(context)
                            .pop(); // Close the dialog if validation passes
                        List<List<LatLng>> selectedPaths = [];
                        double totalDistance = 0.0;

                        // Build the selected paths based on selected segments
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

                        // Update total distance and selected paths queue
                        _totalDistanceKM =
                            totalDistance; // Distance in kilometers
                        FirebaseDatabase.instance
                            .ref()
                            .child('totalDistance')
                            .set(_totalDistanceKM);
                        _storeTimeDurationInDatabase(_totalDistanceKM);

                        setState(() {
                          _selectedPathsQueue.clear();
                          _selectedPathsQueue.addAll(selectedPaths);
                        });

                        // Start movement if not already moving
                        if (!_isMoving) {
                          _startMovement(_dronepath,
                              _selectedPathsQueue); // Pass both full and selected paths
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

    // Sort points to get bounds
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

    // Convert path width to latitude degrees (rough approximation)
    double latIncrement = pathWidth / 111111; // 1 degree latitude ~= 111.1 km

    // Generate paths downwards from the starting point (towards maxLat)
    for (double lat = startLat; lat <= maxLat; lat += latIncrement) {
      List<LatLng> intersections = [];

      // Find intersections for this latitude with polygon edges
      for (int i = 0; i < polygon.length; i++) {
        LatLng p1 = polygon[i];
        LatLng p2 = polygon[(i + 1) % polygon.length];

        // Check if the latitude line intersects with the edge (p1 to p2)
        if ((p1.latitude <= lat && p2.latitude >= lat) ||
            (p1.latitude >= lat && p2.latitude <= lat)) {
          double lng = p1.longitude +
              (lat - p1.latitude) *
                  (p2.longitude - p1.longitude) /
                  (p2.latitude - p1.latitude);
          intersections.add(LatLng(lat, lng.clamp(minLng, maxLng)));
        }
      }

      // Process intersections: should have exactly two for a horizontal line
      if (intersections.length == 2) {
        intersections.sort((a, b) => a.longitude.compareTo(b.longitude));

        if (leftToRight) {
          straightPaths.add([intersections[0], intersections[1]]);
        } else {
          straightPaths.add([intersections[1], intersections[0]]);
        }

        leftToRight = !leftToRight; // Switch direction for zig-zag effect
      }
    }

    // Generate paths upwards from the starting point (towards minLat)
    for (double lat = startLat - latIncrement;
    lat >= minLat;
    lat -= latIncrement) {
      List<LatLng> intersections = [];

      // Find intersections for this latitude with polygon edges
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

        if (leftToRight) {
          straightPaths.add([intersections[0], intersections[1]]);
        } else {
          straightPaths.add([intersections[1], intersections[0]]);
        }

        leftToRight = !leftToRight;
      }
    }

    setState(() {
      _dronepath = straightPaths
          .expand((segment) => segment)
          .toList(); // Flatten straight paths into drone path
      _polylines.add(Polyline(
        polylineId: const PolylineId('dronepath'),
        points: _dronepath,
        color: Colors.red,
        width: 3,
      ));
    });
  }
  void dronepath_Vertical(List<LatLng> polygon, double pathWidth, LatLng startPoint) {
    if (polygon.isEmpty) return;

    // Sort the polygon points by longitude to get the bounds
    List<LatLng> sortedByLng = List.from(polygon)
      ..sort((a, b) => a.longitude.compareTo(b.longitude));

    double minLng = sortedByLng.first.longitude;
    double maxLng = sortedByLng.last.longitude;

    // Clamp the starting longitude to the bounds
    double startLng = startPoint.longitude.clamp(minLng, maxLng);

    List<List<LatLng>> straightPaths = [];
    bool bottomToTop = true;

    // Convert pathWidth to longitude degrees (rough approximation)
    double lngIncrement =
        pathWidth / 111111; // 1 degree longitude ~= 111.1 km at the equator

    // Generate paths to the right (towards maxLng)
    for (double lng = startLng; lng <= maxLng; lng += lngIncrement) {
      List<LatLng> intersections = [];

      // Find intersections for this longitude with polygon edges
      for (int i = 0; i < polygon.length; i++) {
        LatLng p1 = polygon[i];
        LatLng p2 = polygon[(i + 1) % polygon.length];

        // Check if the longitude line intersects with the edge (p1 to p2)
        if ((p1.longitude <= lng && p2.longitude >= lng) ||
            (p1.longitude >= lng && p2.longitude <= lng)) {
          double lat = p1.latitude +
              (lng - p1.longitude) *
                  (p2.latitude - p1.latitude) /
                  (p2.longitude - p1.longitude);
          intersections.add(LatLng(lat, lng));
        }
      }

      // Process intersections: should have exactly two for a vertical line
      if (intersections.length == 2) {
        intersections.sort((a, b) => a.latitude.compareTo(b.latitude));

        if (bottomToTop) {
          straightPaths.add([intersections[0], intersections[1]]);
        } else {
          straightPaths.add([intersections[1], intersections[0]]);
        }

        bottomToTop = !bottomToTop; // Switch direction for zig-zag effect
      }
    }

    // Generate paths to the left (towards minLng)
    for (double lng = startLng - lngIncrement;
    lng >= minLng;
    lng -= lngIncrement) {
      List<LatLng> intersections = [];

      // Find intersections for this longitude with polygon edges
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
          straightPaths.add([intersections[0], intersections[1]]);
        } else {
          straightPaths.add([intersections[1], intersections[0]]);
        }

        bottomToTop = !bottomToTop; // Switch direction for zig-zag effect
      }
    }

    // Flatten the list of straight paths and ensure the starting point is added first
    List<LatLng> dronePath =
    straightPaths.expand((segment) => segment).toList();
    dronePath.insert(0, startPoint);

    // Calculate the total zigzag path distance
    double totalDistancezigzagKm = _calculateTotalDistanceZIGAG(dronePath);

    setState(() {
      _dronepath = dronePath; // Update the state with the new drone path
      _polylines.add(Polyline(
        polylineId: const PolylineId('dronepath'),
        points: dronePath,
        color: Colors.red,
        width: 3,
      ));
      totalZigzagPathKm =
          totalDistancezigzagKm; // Update the total zigzag distance
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
                  _ismanual = true;
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
    List<String> localFiles = await _getAssetFiles(); // Get list of local files
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
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.indigo),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: DropdownButton<String>(
                        hint: Text(
                          'Choose File',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.black45,
                          ),
                        ),
                        value: _selectedLocalFile,
                        isExpanded: true,
                        underline: SizedBox(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedLocalFile = newValue;
                          });
                        },
                        items: localFiles
                            .map<DropdownMenuItem<String>>((String file) {
                          return DropdownMenuItem<String>(
                            value: file,
                            child: Text(file),
                          );
                        }).toList(),
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
                            _selectedCloudFile =
                            null; // Reset the other selection
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
                        items: cloudFiles
                            .map<DropdownMenuItem<String>>((String file) {
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
                    _loadMarkersFromFile(
                        _selectedLocalFile!); // Local file logic
                  } else if (_selectedCloudFile != null) {
                    _loadMarkersFromCloudFile(
                        _selectedCloudFile!); // Cloud file logic
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

        final lines = contents.split('\n');
        for (var line in lines) {
          final parts = line.split(',');
          if (parts.length >= 2) {
            final lat = double.parse(parts[0].trim());
            final lng = double.parse(parts[1].trim());
            final latLng = LatLng(lat, lng);

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

        setState(() {
          _updatePolylines();
          _updateRouteData();
          animateToFirstMarker();

//          Selecting_Path_Direction_and_Turn(); //Confirm  button Wdget should be shown and triger only isnted of this funtion ;
        });

        // Animate the camera to the first marker after loading markers
      } else {
        print('Error fetching cloud file: ${response.statusCode}');
      }
    } catch (e) {
      print('Error loading markers from cloud file: $e');
    }
  }
//Widget to make a button which will trigger the functions SELECTING_PATH_AND_DIRECTION()
  Future<void> _loadMarkersFromFile(String fileName) async {
    final contents = await rootBundle.loadString(fileName);

    _markers.clear();
    _markerPositions.clear();

    final lines = contents.split('\n');
    for (var line in lines) {
      final parts = line.split(',');
      if (parts.length >= 2) {
        final lat = double.parse(parts[0].trim());
        final lng = double.parse(parts[1].trim());
        final latLng = LatLng(lat, lng);

        final markerId = MarkerId('M${_markers.length + 1}');
        final newMarker = Marker(
          markerId: markerId,
          position: latLng,
          icon:
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        );

        _markers.add(newMarker);
        _markerPositions.add(latLng);
      }
    }

    setState(() {
      _updatePolylines();
      _updateRouteData();
      // Selecting_Path_Direction_and_Turn(); //Confirm  button Wdget should be shown and triger only isnted of this funtion ;
    });

    // Animate the camera to the first marker after loading markers
    animateToFirstMarker();
  }
// Function to fetch files from Firebase Storag
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
  Future<List<String>> _getAssetFiles() async {
    // Load the AssetManifest file
    final manifestContent = await rootBundle.loadString('AssetManifest.json');

    // Decode the JSON into a Map<String, dynamic>
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);

    // Filter the manifest for .txt files in the 'images/' directory
    final txtFiles = manifestMap.keys
        .where(
            (String key) => key.startsWith('images/') && key.endsWith('.kml'))
        .toList();

    return txtFiles;
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
//UI BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(30),
            bottomRight: Radius.circular(30),
          ),
        ),
        backgroundColor: Colors.indigo[800],
        toolbarHeight: 80, // Custom height for the AppBar
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: 25,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        flexibleSpace: Padding(
          padding:
          const EdgeInsets.only(top: 40.0), // Padding to control spacing
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // First Row: Logo, Title, Notification Icon, Three Dots Icon

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "Smart",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      fontFamily: GoogleFonts.poppins().fontFamily,
                    ),
                  ),
                  Text(
                    " Controller",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w400,
                      fontSize: 24,
                      fontFamily: GoogleFonts.poppins().fontFamily,
                    ),
                  ),
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
            Stack(
              children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      const Card(
                        //fields inside map comes here
                      ),
                      widget.isManualControl
                          ? Column(
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
                                      _updateValueInDatabase(
                                          drone_direct);
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
                                      _updateValueInDatabase(
                                          drone_direct);
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
                      )
                          : Card(),
                    ]),
              ],
            ),
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
                  child: Text(
                    'Reset Map',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
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
                if (_isConfirmed || _ismanual)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo[800],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => setup_hardware(),
                    child: Text(
                      'Confirm Setup',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),

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
                boxShadow: [],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  children: [
                    _currentLocation == null
                        ? const Center(child: CircularProgressIndicator())
                        : GoogleMap(
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
                      onTap: _isCustomMode ? _onMapTap : null,
                      onMapCreated: (controller) {
                        _googleMapController = controller;
                        // Camera animation is now handled separately.
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
                    if (polygons.isNotEmpty)
                      Positioned(
                        top: 70,
                        left: 5,
                        child: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: Colors.indigo,
                              width: 2.0,
                            ),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Area: ${_calculateSphericalPolygonArea(_markerPositions).toStringAsFixed(2)} acres",
                                style: TextStyle(
                                  color: Colors.teal,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  fontFamily: GoogleFonts.poppins().fontFamily,
                                ),
                              ),
                              Text(
                                "Total Dis.: ${totalZigzagPathKm.toStringAsFixed(2)} Km",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  fontFamily: GoogleFonts.poppins().fontFamily,
                                ),
                              ),
                              Text(
                                "Rem Dis.: ${_remainingDistanceKM_TotalPath.toStringAsFixed(2)} Km",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  fontFamily: GoogleFonts.poppins().fontFamily,
                                ),
                              ),
                              Text(
                                "Spray Dis.: ${_totalDistanceKM.toStringAsFixed(2)} Km",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  fontFamily: GoogleFonts.poppins().fontFamily,
                                ),
                              ),
                              Text(
                                "Rem Spray.: ${_remainingDistanceKM_SelectedPath.toStringAsFixed(2)} Km",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  fontFamily: GoogleFonts.poppins().fontFamily,
                                ),
                              ),
                              Text(
                                "Spray time: ${timeduration.toStringAsFixed(2)} min",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  fontFamily: GoogleFonts.poppins().fontFamily,
                                ),
                              ),
                              Text(
                                "Rem Time: ${TLM.toStringAsFixed(2)} min",
                                style: TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  fontFamily: GoogleFonts.poppins().fontFamily,
                                ),
                              ),
                              Text(
                                "UGV Speed: 10m/s",
                                style: TextStyle(
                                  color: Colors.deepPurple,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  fontFamily: GoogleFonts.poppins().fontFamily,
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
          ],
        ),
      ),
    );
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
