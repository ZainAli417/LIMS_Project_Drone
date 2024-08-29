import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:project_drone/Screens/Fetch_Input.dart';
import 'package:toggle_switch/toggle_switch.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../shared_state.dart';
import 'mapscreen.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const LatLng pGooglePlex = LatLng(33.5923397, 73.0476774);
  final videourl = "https://www.youtube.com/watch?v=WhAfZhFxHTs";
  late YoutubePlayerController _controller;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  String area = '0.00';
  String totalDistance = '0.00';
  String remainingDistance = '0.00';
  String duration = '0.00';

  @override
  void initState() {
    super.initState();
    _fetchData();
    final videoid = YoutubePlayer.convertUrlToId(videourl);
    _controller = YoutubePlayerController(
      initialVideoId: videoid!,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
      ),
    )..addListener(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
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
          toolbarHeight: 135, // Custom height for the AppBar
          flexibleSpace: Padding(
            padding:
                const EdgeInsets.only(top: 40.0), // Padding to control spacing
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // First Row: Logo, Title, Notification Icon, Three Dots Icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            Colors.white, // Set the background color to white
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(1),
                        child: ClipOval(
                          child: Image.asset(
                            fit: BoxFit.fill,
                            'images/logo.png',
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
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            fontFamily: GoogleFonts.poppins().fontFamily,
                          ),
                        ),
                        Text(
                          " Robo",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w400,
                            fontSize: 24,
                            fontFamily: GoogleFonts.poppins().fontFamily,
                          ),
                        ),
                      ],
                    ),
                    const Row(
                      children: [
                        Icon(Icons.notifications_active_outlined,
                            color: Colors.white),
                        SizedBox(width: 10),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Second Row: UGV Connected Widget, Rawalpindi Text, Location Icon
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                      child: Row(
                        children: [
                          Text(
                            "Rawalpindi",
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
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(5, 1, 0, 0),
                        width: 170,
                        height: 40,
                        decoration:  BoxDecoration(
                          color: Colors.indigo[800],
                          borderRadius: BorderRadius.all(Radius.circular(5)),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors
                                .white, // Set the background color to white
                            borderRadius: BorderRadius.circular(
                                10), // Add a 10 radius rounded corner
                          ),
                          child: Row(
                            children: [
                              const CustomUGVIcon(), // Custom UGV connected icon
                              const SizedBox(width: 7),
                              Center(
                                child: Text(
                                  "UGV Connected ",
                                  style: TextStyle(
                                    color: Colors
                                        .indigo[800], // Update the text color to indigo
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    fontFamily:
                                        GoogleFonts.poppins().fontFamily,
                                  ),
                                ),
                              ),
                              const GreenBlinkingDot(), // Custom green blinking dot
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: SingleChildScrollView(

          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [

                Container(
                  padding: const EdgeInsets.fromLTRB(10, 9, 10, 5),
                  width: 450,
                  height: 500,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(height: 15),
                      Expanded(
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Card(
                                elevation: 5, // Add a slight elevation to the card
                                child: GestureDetector(
                                  onDoubleTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => MapScreen(),
                                      ),
                                    );
                                    print('pressed');
                                  },
                                  child: Container(
                                    height: 500,
                                    width: double.infinity, // Make the map wider by setting width to infinity
                                    child: Padding(
                                      padding: const EdgeInsets.all(5.0),
                                      child: GoogleMap(
                                        initialCameraPosition: const CameraPosition(
                                          target: pGooglePlex,
                                          zoom: 15,
                                        ),
                                        markers: {
                                          const Marker(
                                            markerId: MarkerId('GooglePlex'),
                                            position: pGooglePlex,
                                          ),
                                        },
                                        // Enable zooming in and out
                                        zoomGesturesEnabled: true,
                                        // Enable rotating gestures
                                        rotateGesturesEnabled: true,
                                        // Enable tilting gestures
                                        tiltGesturesEnabled: true,
                                        // Enable scrolling gestures
                                        scrollGesturesEnabled: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 10,
                                right: 10,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors
                                        .white, // Color of the rounded container
                                    shape: BoxShape
                                        .circle, // Makes the container round
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey, // Optional shadow
                                        blurRadius: 8,
                                        offset: Offset(2, 2),
                                      ),
                                    ],
                                  ),
                                  child: FloatingActionButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => Fetch_Input(
                                              controller: _controller),
                                        ),
                                      );
                                    },
                                    backgroundColor: Colors.white,
                                    mini: true,
                                    child: Image.asset(
                                      'images/control.png',
                                      width: 35,
                                      height: 35,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(5.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: _buildInfoCapsule(
                                        Icons.landscape_outlined, area, "Area"),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildInfoCapsule(
                                        Icons.access_time_outlined,
                                        duration,
                                        "Duration"),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: _buildInfoCapsule(
                                        Icons.straighten_outlined,
                                        totalDistance,
                                        "Total Dis."),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _buildInfoCapsule(
                                        Icons.route_outlined,
                                        remainingDistance,
                                        "Remaining Dis."),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Center(
                                child: ElevatedButton(
                                  onPressed: _resetData,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo[800],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  child: Text(
                                    "Reset Field",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontFamily:
                                          GoogleFonts.poppins().fontFamily,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(11, 0, 0, 0),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cloud_outlined,
                        color: Colors.black,
                        size: 20,
                      ),
                      const SizedBox(
                        width: 10,
                      ),
                      Text(
                        "Weather",
                        style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          fontFamily: GoogleFonts.poppins().fontFamily,
                        ),
                      ),
                      const SizedBox(
                        width: 200,
                      ),
                     /* Container(
                        width: 25,
                        height: 25,
                        decoration: const BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.all(Radius.circular(3))),
                        child: const Icon(Icons.more_horiz_outlined),
                      ),*/
                    ],
                  ),
                ),
                const SizedBox(
                  height: 15,
                ),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Circular Temperature Widget inside Card
                        Container(
                          padding: const EdgeInsets.all(10),
                          child: SizedBox(
                            width: 80,
                            height: 80,
                            child: SfRadialGauge(
                              axes: <RadialAxis>[
                                RadialAxis(
                                    minimum: 0,
                                    maximum: 100,
                                    showLabels: false,
                                    showTicks: false,
                                    startAngle: 270,
                                    endAngle: 270,
                                    axisLineStyle:  AxisLineStyle(
                                      thickness: 1,
                                      color: Colors.indigo[800],
                                      thicknessUnit: GaugeSizeUnit.factor,
                                    ),
                                    pointers: const <GaugePointer>[
                                      RangePointer(
                                        value: 70,
                                        width: 0.15,
                                        color: Colors.white,
                                        pointerOffset: 0.1,
                                        cornerStyle: CornerStyle.bothCurve,
                                        sizeUnit: GaugeSizeUnit.factor,
                                      )
                                    ],
                                    annotations: <GaugeAnnotation>[
                                      GaugeAnnotation(
                                        positionFactor: 0.1,
                                        angle: 90,
                                        widget: Padding(
                                            padding: EdgeInsets.only(top: 30),
                                            child: Text("10 °C",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 20,
                                                  fontFamily:
                                                      GoogleFonts.poppins()
                                                          .fontFamily,
                                                ))),
                                      ),
                                    ]),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(
                            width:
                                10), // Spacer between temperature and content

                        // Main Card Content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Warning Text
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8.0),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.warning,
                                        color: Colors.red, size: 20),
                                    const SizedBox(width: 5),
                                    Expanded(
                                      child: Text(
                                        "Don't Drive UGV when wind speed is above 50Mph",
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 11,
                                          fontFamily:
                                              GoogleFonts.poppins().fontFamily,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 15),

                              // Weather Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    'images/sunny.svg',
                                    height: 24,
                                    width: 24,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    "Sunny Weather",
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      fontFamily:
                                          GoogleFonts.poppins().fontFamily,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Icon(Icons.wind_power,
                                            size: 30),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Text(
                                            "36",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                              fontFamily: GoogleFonts.poppins()
                                                  .fontFamily,
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            "m/h",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: GoogleFonts.poppins()
                                                  .fontFamily,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Text(
                                        "UGV Speed",
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                          fontFamily:
                                              GoogleFonts.poppins().fontFamily,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    children: [
                                      SizedBox(
                                        width: 60,
                                        height: 60,
                                        child: SfRadialGauge(
                                          axes: <RadialAxis>[
                                            RadialAxis(
                                              minimum: 0,
                                              maximum: 100,
                                              showLabels: false,
                                              showTicks: false,
                                              startAngle: 270,
                                              endAngle: 270,
                                              axisLineStyle:
                                                  const AxisLineStyle(
                                                thickness: 1,
                                                color: Colors.blue,
                                                thicknessUnit:
                                                    GaugeSizeUnit.factor,
                                              ),
                                              pointers: const <GaugePointer>[
                                                RangePointer(
                                                  value: 80,
                                                  width: 0.15,
                                                  color: Colors.white,
                                                  pointerOffset: 0.1,
                                                  cornerStyle:
                                                      CornerStyle.bothCurve,
                                                  sizeUnit:
                                                      GaugeSizeUnit.factor,
                                                )
                                              ],
                                              annotations: <GaugeAnnotation>[
                                                GaugeAnnotation(
                                                  positionFactor: 0.1,
                                                  angle: 90,
                                                  widget: Padding(
                                                    padding: EdgeInsets.only(
                                                        top: 15),
                                                    child: Text("80%",
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontSize: 13,
                                                          fontFamily:
                                                              GoogleFonts
                                                                      .poppins()
                                                                  .fontFamily,
                                                        )),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        "Water Level",
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w400,
                                          fontFamily:
                                              GoogleFonts.poppins().fontFamily,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.all(Radius.circular(15))),
                  child: Padding(
                    padding: const EdgeInsets.all(9.0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.solar_power,
                          color: Colors.black,
                          size: 20,
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Text(
                          "Solar Status",
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            fontFamily: GoogleFonts.poppins().fontFamily,
                          ),
                        ),
                        const SizedBox(
                          width: 50,
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const SizedBox(
                              width: 25,
                            ),
                            ToggleSwitch(
                              activeBgColor:  [Colors.indigo],
                              initialLabelIndex: 0,
                              totalSwitches: 2,
                              labels: const [
                                'Yes',
                                'No',
                              ],
                              onToggle: (index) {
                                print('switched to: $index');
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  height: 25,
                ),

              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCapsule(IconData icon, String value, String label) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black),
          const SizedBox(width: 5),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  fontFamily: GoogleFonts.poppins().fontFamily,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _resetData() async {
    await _dbRef.child('Area').remove();
    await _dbRef.child('totalDistance').remove();
    await _dbRef.child('remainingDistance').remove();
    await _dbRef.child('TimeDuration').remove();

    setState(() {
      area = '0.00';
      totalDistance = '0.00';
      remainingDistance = '0.00';
      duration = '0.00';
    });
  }

  void _fetchData() {
    _dbRef.child('Area').onValue.listen((event) {
      final double fetchedArea =
          double.tryParse(event.snapshot.value.toString()) ?? 0.0;
      setState(() {
        area = fetchedArea.toStringAsFixed(2);
      });
    });

    _dbRef.child('totalDistance').onValue.listen((event) {
      final double fetchedTotalDistance =
          double.tryParse(event.snapshot.value.toString()) ?? 0.0;
      setState(() {
        totalDistance = fetchedTotalDistance.toStringAsFixed(2);
      });
    });

    _dbRef.child('remainingDistance').onValue.listen((event) {
      final double fetchedRemainingDistance =
          double.tryParse(event.snapshot.value.toString()) ?? 0.0;
      setState(() {
        remainingDistance = fetchedRemainingDistance.toStringAsFixed(2);
      });
    });

    _dbRef.child('TimeDuration').onValue.listen((event) {
      final double fetchedDuration =
          double.tryParse(event.snapshot.value.toString()) ?? 0.0;
      setState(() {
        duration = fetchedDuration.toStringAsFixed(2);
      });
    });
  }
}

class CustomUGVIcon extends StatelessWidget {
  const CustomUGVIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40, // Updated to 40x40 size
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(width: 2, color: Colors.white),
      ),
      child: ClipOval(
        child: Image.asset(
          'images/ugv.png', // Path to the PNG image
          fit: BoxFit.cover, // Ensures the image covers the circle
        ),
      ),
    );
  }
}

class GreenBlinkingDot extends StatefulWidget {
  const GreenBlinkingDot({super.key});

  @override
  _GreenBlinkingDotState createState() => _GreenBlinkingDotState();
}

class _GreenBlinkingDotState extends State<GreenBlinkingDot>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Color?> _colorAnimation; // Change to Animation<Color?>

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat();
    _colorAnimation = ColorTween(
      begin: Colors.green,
      end: Colors.greenAccent,
    ).animate(_controller);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, child) {
        return Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color:
                _colorAnimation.value ?? Colors.green, // Handle nullable color
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
