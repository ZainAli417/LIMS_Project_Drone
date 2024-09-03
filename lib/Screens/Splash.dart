import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'onBoarding.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _logoAnimationController;
  late AnimationController _textController;
  late AnimationController _taglineController;

  @override
  void initState() {
    super.initState();

    // Initialize all controllers
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );

    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    // Start animations in sequence
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        _textController.forward();
      }
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _taglineController.forward();
      }
    });

    // Navigate to OnBoarding screen after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => FirstOnBoardingScreen()), // Replace with your actual OnBoardingScreen widget
        );
      }
    });
  }

  @override
  void dispose() {
    // Dispose controllers to prevent memory leaks
    _logoAnimationController.dispose();
    _textController.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: Tween<double>(
                begin: 0.8,
                end: 1.0,
              ).animate(CurvedAnimation(
                parent: _logoAnimationController,
                curve: Curves.easeOut,
              )),
              child: Image.asset(
                'images/logo.png', // Update with your actual image path
                width: 300,
                height: 300,
              ),
            ),
            const SizedBox(height: 40),
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-2, 0), // Start off-screen (left side)
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: _textController,
                curve: Curves.easeOut,
              )),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'LIMS ',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 30,
                        fontWeight: FontWeight.w500,
                        fontFamily: GoogleFonts.poppins().fontFamily,
                      ),
                    ),
                    TextSpan(
                      text: 'Robo',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 32,
                        fontWeight: FontWeight.w600,
                        fontFamily: GoogleFonts.poppins().fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            FadeTransition(
              opacity: _taglineController,
              child: Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(
                  "Application of drones in precision agriculture",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.indigo[800],
                    fontSize: 18,
                    fontFamily: GoogleFonts.poppins().fontFamily,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


