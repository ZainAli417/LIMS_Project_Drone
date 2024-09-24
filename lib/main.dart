// main.dart
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
import 'Screens/coustom.dart';
import 'Screens/onBoarding.dart';
import 'Screens/homescreen.dart';
import 'Screens/splashScreen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseDatabase.instance.setPersistenceEnabled(true);
  FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10000000);  // Check if user is logged in
  User? user = FirebaseAuth.instance.currentUser;

  runApp(MyApp(user: user)); // Pass the user object to MyApp
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
        //  home:  SplashScreen() ,
        home: user == null ? SplashScreen() :  DeviceSelection(), // Navigate based on login state
        routes: {
          '/home': (context) => const MyHomePage(deviceId: '',),
        },
      ),
    );
  }
}
