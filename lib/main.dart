import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:location/location.dart';
import 'package:project_drone/Screens/device_selection.dart';
import 'package:provider/provider.dart';
import 'Constant/ISSAASProvider.dart';
import 'Constant/forget_password_provider.dart';
import 'Constant/login_provider.dart';
import 'Constant/splash_provider.dart';
import 'Screens/Splash.dart';
import 'Screens/homescreen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ISSAASProvider().init();
  await Firebase.initializeApp();
  FirebaseDatabase.instance.setPersistenceEnabled(true);
  FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10000000);

  // Check if user is logged in
  User? user = FirebaseAuth.instance.currentUser;

  // Request location permission
  await requestLocationPermission();

  runApp(MyApp(user: user)); // Pass the user object to MyApp
}

Future<void> requestLocationPermission() async {
  Location location = Location();

  // Check if location service is enabled
  bool _serviceEnabled;
  PermissionStatus _permissionGranted;

  _serviceEnabled = await location.serviceEnabled();
  if (!_serviceEnabled) {
    // Location services are not enabled, you can show a dialog or a message to the user
    _serviceEnabled = await location.requestService();
    if (!_serviceEnabled) {
      return; // Service not enabled, exit the function
    }
  }

  // Check for location permission
  _permissionGranted = await location.hasPermission();
  if (_permissionGranted == PermissionStatus.denied) {
    _permissionGranted = await location.requestPermission();
    if (_permissionGranted != PermissionStatus.granted) {
      return; // Permission denied, exit the function
    }
  }
  // Location permission granted, proceed with your logic
}

class MyApp extends StatelessWidget {
  final User? user; // Add this field

  const MyApp({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SplashProvider()),
        ChangeNotifierProvider(create: (_) => LoginProvider()),
        ChangeNotifierProvider(create: (_) => ForgotPasswordProvider()),
        ChangeNotifierProvider(create: (_) => ISSAASProvider()),
      ],
      child: MaterialApp(
        title: 'Project Drone',
        home: user == null ? SplashScreen() : DeviceSelection(), // Navigate based on login state
        routes: {
          '/home': (context) => const MyHomePage(deviceId: '',),
        },
      ),
    );
  }
}
