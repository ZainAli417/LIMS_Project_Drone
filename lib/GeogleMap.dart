import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'Screens/mapscreen.dart';
import 'Screens/vedioscreen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: MapPage(),
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.green, // Slightly darker background
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.grey[900], // Darker app bar
        ),
        hintColor: Colors.greenAccent,
        primaryColor: Colors.greenAccent,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          titleLarge: TextStyle(
            color: Colors.greenAccent,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
    );
  }
}

class MapPage extends StatefulWidget {
  const MapPage({Key? key}) : super(key: key);

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const LatLng pGooglePlex = LatLng(33.5923397, 73.0476774);
  final videourl = "https://www.youtube.com/watch?v=RPzzchBCuas";
  late YoutubePlayerController _controller;
  int? batteryPercentage = 74;
  int? tankCapacity = 50;
  double speed = 60.0;
  late Timer _timer;
  int _timeRemaining = 300; // Initial time remaining in seconds

  @override
  void initState() {
    super.initState();
    final videoid = YoutubePlayer.convertUrlToId(videourl);
    _controller = YoutubePlayerController(
      initialVideoId: videoid!,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
      ),
    )..addListener(() {
      if (_controller.value.playerState == PlayerState.ended) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoScreen(controller: _controller),
          ),
        );
      }
    });

    // Set up a timer to update the screen every second
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _timeRemaining--; // Decrease the time remaining every second
      });
    });
  }

  @override
  void dispose() {
    // Dispose of the timer when the widget is disposed
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(
            "LIMS-Robo",
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      backgroundColor: Colors.grey[800], // Slightly darker background
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
              ),
              child: GestureDetector(
                onDoubleTap: (){
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          MapScreen(),
                    ),
                  );
                  print('pressed]');
                },
                child: GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: pGooglePlex,
                    zoom: 10,
                  ),
                  markers: {
                    Marker(
                      markerId: MarkerId('carMarker'),
                      position: pGooglePlex,
                      infoWindow: InfoWindow(title: 'Car Marker'),
                ),
                },
                ),


              ),
            ),
            SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        VideoScreen(controller: _controller),
                  ),
                );
              },
              child: Container(
                margin: EdgeInsets.only(bottom: 16.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.0),
                  color: Colors.grey[700], // Adjusted color
                ),
                height: 200,
                child: Stack(
                  alignment: AlignmentDirectional.bottomEnd,
                  children: [
                    YoutubePlayer(
                      controller: _controller!,
                      showVideoProgressIndicator: true,
                    ),
                    FloatingActionButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                VideoScreen(controller: _controller),
                          ),
                        );
                      },
                      child: Image.asset('images/control.png',width: 30,height: 20,),
                      backgroundColor: Colors.white,
                      mini: true,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                buildSpeedometer(speed),
                SizedBox(width: 10),
                Column(
                  children: [
                    Icon(
                      Icons.timer,
                      color: Colors.greenAccent,
                      size: 24,
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Time Remaining',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      formatTime(_timeRemaining),
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 20),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                buildAnimatedBatteryIndicator(batteryPercentage!),
                SizedBox(width: 20),
                buildAnimatedTankCapacityIndicator(tankCapacity!),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget buildAnimatedBatteryIndicator(int batteryPercentage) {
    return Column(
      children: [
        CircularProgressIndicator(
          value: batteryPercentage / 100,
          backgroundColor: Colors.grey,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.greenAccent),
          strokeWidth: 10,
        ),
        SizedBox(height: 8),
        Text(
          'Battery: $batteryPercentage%',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget buildAnimatedTankCapacityIndicator(int tankCapacity) {
    return Column(
      children: [
        CircularProgressIndicator(
          value: tankCapacity / 100,
          backgroundColor: Colors.grey,
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
          strokeWidth: 10,
        ),
        SizedBox(height: 8),
        Text(
          'Capacity: $tankCapacity%',
          style: TextStyle(
            fontSize: 18,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget buildSpeedometer(double speed) {
    return SleekCircularSlider(
      appearance: CircularSliderAppearance(
        startAngle: 150,
        angleRange: 240,
        customWidths: CustomSliderWidths(progressBarWidth: 10),
        customColors: CustomSliderColors(
          progressBarColors: [Colors.blueAccent, Colors.greenAccent],
          trackColor: Colors.grey,
          dotColor: Colors.white,
        ),
        infoProperties: InfoProperties(
          mainLabelStyle: TextStyle(fontSize: 20, color: Colors.white),
          modifier: (double value) {
            return '${value.toStringAsFixed(1)} km/h';
          },
        ),
      ),
      min: 0,
      max: 120,
      initialValue: speed,
    );
  }

  // Helper method to format seconds into HH:MM:SS
  String formatTime(int seconds) {
    Duration duration = Duration(seconds: seconds);
    return "${duration.inHours}:${(duration.inMinutes % 60).toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}";
  }
}
