import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:project_drone/Screens/Fetch_Input.dart';
import 'package:project_drone/Screens/LoginScreen.dart';
import 'package:toggle_switch/toggle_switch.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../Constant/controller_weather.dart';
import '../Constant/weather.dart';
import '../shared_state.dart';
import 'coustom.dart';
import 'mapscreen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:location/location.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final WeatherController weatherController = Get.put(WeatherController());
  static const LatLng pGooglePlex = LatLng(33.5923397, 73.0476774);
  final videourl = "https://www.youtube.com/watch?v=WhAfZhFxHTs";
  late YoutubePlayerController _controller;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  String area = '0.00';
  String totalDistance = '0.00';
  String remainingDistance = '0.00';
  String duration = '0.00';
  String temperature = "10 C";
  String weatherDescription = "NA";
  String waterLevel = "80 %";
  String city = "N/A";
  String cityName = "N/A";
  bool _isSolarOn = true;
  @override
  void initState() {
    super.initState();
    _getPositionAndWeather();
    _fetchData();

    final videoid = YoutubePlayer.convertUrlToId(videourl);
    _controller = YoutubePlayerController(
      initialVideoId: videoid!,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
      ),
    )..addListener(() {});
  }

  Future<void> _getPositionAndWeather() async {
    try {
      Position position = await getPosition();
      await weatherController.fetchWeatherData(
          position.latitude, position.longitude);
    } catch (e) {
      print('Error fetching location or weather data: $e');
    }
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
          toolbarHeight: 160, // Custom height for the AppBar
          flexibleSpace: Padding(
            padding: const EdgeInsets.fromLTRB(
                10, 50, 10, 0), // Padding to control spacing
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
                        color:
                            Colors.black12, // Optional shadow for better look
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
                                 SizedBox(width: 2), // Reduced spacing between icon and text


                                 IconButton(
                                   icon: const Icon(
                                     Icons.logout_outlined,
                                     color: Colors.black,
                                     size: 25,
                                   ),
                                   onPressed: () async {
                                     try {
                                       await FirebaseAuth.instance.signOut();
                                       Navigator.pushReplacement(
                                         context,
                                         MaterialPageRoute(builder: (context) => LoginScreen()), // Adjust the navigation to your Login page
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

                    // UGV Connected Section
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 5, 15, 5),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(5, 1, 0, 0),
                        width: 170,
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
                              const CustomUGVIcon(), // Custom UGV connected icon
                              const SizedBox(width: 7),
                              Center(
                                child: Text(
                                  "UGV Connected ",
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
            padding: const EdgeInsets.fromLTRB(3, 10, 1, 0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 9, 12, 5),
                  width: 700,
                  height: 615,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(15)),
                  ),
                  child: Column(
                    // Enclose everything in a Column

                    children: [
                      Row(
                        // First Row

                        children: [
                          SvgPicture.asset(
                            'images/sunny.svg', // Path to your SVG file
                            height: 20, // Optional: Set the height as needed
                            width: 20, // Optional: Set the width as needed
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Text(
                            "Weather Stats",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              fontFamily: GoogleFonts.poppins().fontFamily,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15), // Spacing between rows

                      Row(
                        // Second Row (Warning message)

                        mainAxisAlignment: MainAxisAlignment.center,

                        children: [
                          const Icon(Icons.warning,
                              color: Colors.red, size: 20),
                          Expanded(
                            child: Text(
                              "Don't Drive UGV when wind speed is above 50Mph",
                              style: TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                                fontFamily: GoogleFonts.poppins().fontFamily,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15), // Spacing between rows

                     /* Row(
                        children: [
                          Expanded(
                            child: Text(
                              "Today There Are Chances Of ${weatherController.weather.value.condition.isEmpty ? "N/A..." : weatherController.weather.value.condition}",
                              style: TextStyle(
                                color: Colors.teal,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                fontFamily: GoogleFonts.poppins().fontFamily,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),*/

                      const SizedBox(height: 15), // Spacing between rows

                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 3,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          children: [
                            Obx(() {
                              return WeatherCard(
                                icon: Icons.wind_power_outlined,
                                label: 'Wind Speed',
                                value:
                                    '${weatherController.weather.value.windspeed.toStringAsFixed(1)} m/s',
                                cardColor: Colors.teal,
                                textColor: Colors.white,
                              );
                            }),

                            Obx(() {
                              return WeatherCard(
                                icon: Icons.water_drop_outlined,
                                label: 'Water Level',
                                value:
                                    '${weatherController.weather.value.humidity}%',
                                cardColor: Colors.blue,
                                textColor: Colors.white,
                              );
                            }),

                            Obx(() {
                              return WeatherCard(
                                icon: Icons.thermostat_auto_outlined,
                                label: 'Temperature',
                                value:
                                    '${weatherController.weather.value.temp.toStringAsFixed(1)} °C',
                                cardColor: Colors.purple,
                                textColor: Colors.white,
                              );
                            }),

                            // Widget spanning two columns

                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        Fetch_Input(controller: _controller),
                                  ),
                                );
                              },
                              child: Card(
                                elevation: 8,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                color: Colors.white,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Image.asset(
                                      'images/controll.png', // Replace with your image path
                                      height: 85,
                                      width: 100,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      'Smart Controller',
                                      style: TextStyle(
                                        color: Colors.indigo,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        fontFamily:
                                            GoogleFonts.poppins().fontFamily,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        // First Row

                        children: [
                          Image.asset(
                            'images/field.png', // Path to your SVG file
                            height: 35, // Optional: Set the height as needed
                            width: 35, // Optional: Set the width as needed
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          Text(
                            "Field Stats",
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w700,
                              fontSize: 17,
                              fontFamily: GoogleFonts.poppins().fontFamily,
                            ),
                          ),
                        ],
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
                /*

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
                            child: Obx(() {
                              return SfRadialGauge(
                                axes: <RadialAxis>[
                                  RadialAxis(
                                    minimum:
                                        -30, // Adjust minimum based on your expected temperature range
                                    maximum:
                                        50, // Adjust maximum based on your expected temperature range
                                    showLabels: false,
                                    showTicks: false,
                                    startAngle: 270,
                                    endAngle: 270,
                                    axisLineStyle: AxisLineStyle(
                                      thickness: 1,
                                      color: Colors.indigo[800],
                                      thicknessUnit: GaugeSizeUnit.factor,
                                    ),
                                    pointers: <GaugePointer>[
                                      RangePointer(
                                        value: weatherController.weather.value
                                            .temp, // Use fetched temperature
                                        width: 0.15,
                                        color: Colors.white,
                                        pointerOffset: 0.1,
                                        cornerStyle: CornerStyle.bothCurve,
                                        sizeUnit: GaugeSizeUnit.factor,
                                      ),
                                    ],
                                    annotations: <GaugeAnnotation>[
                                      GaugeAnnotation(
                                        positionFactor: 0.1,
                                        angle: 90,
                                        widget: Padding(
                                          padding:
                                              const EdgeInsets.only(top: 30),
                                          child: Text(
                                            "${weatherController.weather.value.temp.toStringAsFixed(1)}°C", // Display temperature with °C
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                              fontSize: 20,
                                              fontFamily: GoogleFonts.poppins()
                                                  .fontFamily,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            }),
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

                              const SizedBox(height: 15),

                              // Weather Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Obx(() {
                                    return Row(
                                      children: [
                                        SvgPicture.asset(
                                          'images/${weatherController.weather.value.condition.toLowerCase()}.svg',
                                          height: 24,
                                          width: 24,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          weatherController.weather.value
                                                  .condition.isEmpty
                                              ? "Loading..." // Display "Loading..." until the data is fetched
                                              : weatherController.weather.value
                                                  .condition, // Display fetched condition like RAINY, SUNNY, CLOUDY
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 15,
                                            fontFamily: GoogleFonts.poppins()
                                                .fontFamily,
                                          ),
                                        ),
                                      ],
                                    );
                                  }),
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
                                          Obx(() {
                                            return Text(
                                              weatherController
                                                  .weather.value.windspeed
                                                  .toStringAsFixed(
                                                      0), // Display the wind speed
                                              style: TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                                fontFamily:
                                                    GoogleFonts.poppins()
                                                        .fontFamily,
                                              ),
                                            );
                                          }),
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
                                        child: Obx(() {
                                          return SfRadialGauge(
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
                                                pointers: <GaugePointer>[
                                                  RangePointer(
                                                    value: weatherController
                                                        .weather.value.humidity
                                                        .toDouble(), // Set the humidity value dynamically
                                                    width: 0.15,
                                                    color: Colors.white,
                                                    pointerOffset: 0.1,
                                                    cornerStyle:
                                                        CornerStyle.bothCurve,
                                                    sizeUnit:
                                                        GaugeSizeUnit.factor,
                                                  ),
                                                ],
                                                annotations: <GaugeAnnotation>[
                                                  GaugeAnnotation(
                                                    positionFactor: 0.1,
                                                    angle: 90,
                                                    widget: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                              top: 15),
                                                      child: Text(
                                                        "${weatherController.weather.value.humidity}%", // Display fetched humidity
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontSize: 13,
                                                          fontFamily:
                                                              GoogleFonts
                                                                      .poppins()
                                                                  .fontFamily,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          );
                                        }),
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        "Humidity",
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
                ),*/

                const SizedBox(height: 20),
                Center(

                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10,5,10,5),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.solar_power,
                                color: Colors.black,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "Solar Status",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  fontFamily: GoogleFonts.poppins().fontFamily,
                                ),
                              ),
                              const SizedBox(width: 50),
                              ToggleSwitch(
                                activeBgColor: [Colors.indigo],
                                initialLabelIndex: _isSolarOn ? 0 : 1,
                                totalSwitches: 2,
                                labels: const ['Yes', 'No'],
                                onToggle: (index) {
                                  setState(() {
                                    _isSolarOn = index == 0;
                                  });
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _isSolarOn
                              ? Image.asset(
                                  'images/solar_day.png',
                                  width: 200,
                                  height: 200,
                                ) // Replace with your image path
                              : Image.asset(
                                  'images/solar_night.png', width: 200,
                            height: 200,), // Replace with your image path
                        ],
                      ),
                    ),
                  ),

                const SizedBox(
                  height: 5,
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
