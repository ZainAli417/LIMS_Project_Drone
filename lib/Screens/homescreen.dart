import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:project_drone/Screens/KML_Load.dart';
import 'package:toggle_switch/toggle_switch.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

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
      home: SafeArea(
        child: Scaffold(
          backgroundColor: Colors.black,
          body: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.fromLTRB(5, 10, 10, 5),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        "Rawalpindi",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Container(
                        width: 40,
                        height: 25,
                        decoration: const BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.all(Radius.circular(3))),
                        child: const Icon(Icons.notifications),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        width: 25,
                        height: 25,
                        decoration: const BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.all(Radius.circular(3))),
                        child: const Icon(Icons.more_horiz_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 9, 10, 5),
                    width: 450,
                    height: 350,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.all(Radius.circular(15)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Text(
                              "Lims",
                              style: TextStyle(color: Colors.white),
                            ),
                            const SizedBox(width: 7),
                            const Text(
                              "Robo",
                              style: TextStyle(color: Colors.red),
                            ),
                            const SizedBox(width: 20),
                            Container(
                              padding: const EdgeInsets.fromLTRB(5, 1, 0, 0),
                              width: MediaQuery.of(context).size.width - 270,
                              height: 17,
                              decoration: const BoxDecoration(
                                color: Colors.lightBlue,
                                borderRadius:
                                    BorderRadius.all(Radius.circular(5)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.wifi,
                                    size: 15,
                                    color: Colors.red,
                                  ),
                                  SizedBox(width: 7),
                                  Text(
                                    "Connected",
                                    style: TextStyle(
                                        color: Colors.black87,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10),
                                  )
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        Expanded(
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(15)),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                YoutubePlayer(
                                  controller: _controller,
                                  showVideoProgressIndicator: true,
                                ),
                                Positioned(
                                  bottom: 10,
                                  right: 10,
                                  child: FloatingActionButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>KML
                                        /*
                                        MaterialPageRoute(
                                          builder: (context) => VideoScreen(
                                              controller: _controller),
                                        ),*/
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
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildInfoCapsule(Icons.area_chart, area, "Area"),
                            _buildInfoCapsule(Icons.compare_arrows_outlined,
                                totalDistance, "Total Dis."),
                            _buildInfoCapsule(Icons.compare_arrows_outlined,
                                remainingDistance, "Remaining Dis."),
                            _buildInfoCapsule(
                                Icons.watch_later, duration, "Duration"),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Center(
                          child: Row(
                            children: [
                              ElevatedButton(
                                onPressed: _resetData,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                child: const Text(
                                  'Reset Field',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.fromLTRB(11, 0, 0, 0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.cloud,
                          color: Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        const Text(
                          'Weather',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(
                          width: 200,
                        ),
                        Container(
                          width: 25,
                          height: 25,
                          decoration: const BoxDecoration(
                              color: Colors.grey,
                              borderRadius:
                                  BorderRadius.all(Radius.circular(3))),
                          child: const Icon(Icons.more_horiz_outlined),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(
                    height: 15,
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
                        child: SizedBox(
                          width: 100,
                          height: 100,
                          child: SfRadialGauge(
                            axes: <RadialAxis>[
                              RadialAxis(
                                  minimum: 0,
                                  maximum: 100,
                                  showLabels: false,
                                  showTicks: false,
                                  startAngle: 270,
                                  endAngle: 270,
                                  axisLineStyle: const AxisLineStyle(
                                    thickness: 1,
                                    color: Color.fromARGB(255, 0, 169, 181),
                                    thicknessUnit: GaugeSizeUnit.factor,
                                  ),
                                  pointers: const <GaugePointer>[
                                    RangePointer(
                                      value: 80,
                                      width: 0.15,
                                      color: Colors.white,
                                      pointerOffset: 0.1,
                                      cornerStyle: CornerStyle.bothCurve,
                                      sizeUnit: GaugeSizeUnit.factor,
                                    )
                                  ],
                                  annotations: const <GaugeAnnotation>[
                                    GaugeAnnotation(
                                        positionFactor: 0.1,
                                        angle: 90,
                                        widget: Padding(
                                          padding: EdgeInsets.only(top: 50),
                                          child: Text(
                                            "10 C",
                                            style: TextStyle(
                                                fontSize: 20,
                                                color: Colors.white),
                                          ),
                                        ))
                                  ]),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 0,
                      ),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.fromLTRB(0, 5, 0, 0),
                              width: 270,
                              height: 30,
                              decoration: const BoxDecoration(
                                  color: Colors.grey,
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(4))),
                              child: const Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.warning,
                                        color: Colors.red,
                                        size: 20,
                                      ),
                                      Text(
                                        "Don't drive UGV when wind is above 50mph",
                                        style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold),
                                      )
                                    ],
                                  )
                                ],
                              ),
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            const Row(
                              children: [
                                Icon(
                                  Icons.sunny,
                                  color: Colors.yellow,
                                ),
                                SizedBox(
                                  width: 5,
                                ),
                                Text(
                                  'Sunny Weather',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 25),
                                )
                              ],
                            ),
                            const SizedBox(
                              height: 10,
                            ),
                            Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: const BoxDecoration(
                                      color: Colors.grey,
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(5))),
                                  child: const Icon(
                                    Icons.wind_power,
                                    size: 35,
                                  ),
                                ),
                                const SizedBox(
                                  width: 10,
                                ),
                                const Column(
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          "36",
                                          style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.red),
                                        ),
                                        SizedBox(
                                          width: 3,
                                        ),
                                        Text(
                                          'm/h',
                                          style: TextStyle(
                                              color: Colors.grey, fontSize: 20),
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                      height: 10,
                                    ),
                                    Text(
                                      "UGV Speed",
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 14),
                                    )
                                  ],
                                ),
                                const SizedBox(
                                  width: 30,
                                ),
                                Container(
                                  width: 23,
                                  height: 23,
                                  decoration: const BoxDecoration(
                                      color: Colors.grey,
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(5))),
                                  child: const Icon(
                                    Icons.water,
                                    size: 15,
                                  ),
                                ),
                                const SizedBox(
                                  width: 4,
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
                                              annotations: const <GaugeAnnotation>[
                                                GaugeAnnotation(
                                                    positionFactor: 0.1,
                                                    angle: 90,
                                                    widget: Padding(
                                                      padding: EdgeInsets.only(
                                                          top: 15),
                                                      child: Text(
                                                        "80%",
                                                        style: TextStyle(
                                                            fontSize: 8,
                                                            color:
                                                                Colors.white),
                                                      ),
                                                    ))
                                              ]),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(
                                      height: 10,
                                    ),
                                    const Text(
                                      "Water Level",
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 15),
                                    ),
                                  ],
                                ),
                              ],
                            )
                          ])
                    ],
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: const BoxDecoration(
                        color: Colors.grey,
                        borderRadius: BorderRadius.all(Radius.circular(15))),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.solar_power,
                            color: Colors.grey,
                            size: 20,
                          ),
                          const SizedBox(
                            width: 10,
                          ),
                          const Text(
                            'Solar Status',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(
                            width: 60,
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const SizedBox(
                                width: 30,
                              ),
                              ToggleSwitch(
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
                  GestureDetector(
                    onDoubleTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MapScreen(),
                        ),
                      );
                      print('pressed]');
                    },
                    child: Container(
                      height: 200,
                      decoration: const BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.all(Radius.circular(1))),
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
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
                style: const TextStyle(
                  fontSize: 13,
                  fontFamily: 'sans',
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
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
