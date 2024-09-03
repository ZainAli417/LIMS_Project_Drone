/*import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoAnimationController;
  late AnimationController _firstButtonController;
  late AnimationController _secondButtonController;
  late AnimationController _thirdButtonController;
  late AnimationController _fourthButtonController;

  @override
  void initState() {
    super.initState();

    // Initialize the AnimationControllers for logo and buttons
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _firstButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _secondButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _thirdButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fourthButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    // Start staggered animations
    Future.delayed(const Duration(milliseconds: 600), () {
      _firstButtonController.forward();
    });
    Future.delayed(const Duration(milliseconds: 800), () {
      _secondButtonController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      _thirdButtonController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1400), () {
      _fourthButtonController.forward();
    });
  }

  @override
  void dispose() {
    // Dispose of the AnimationControllers to free resources
    _logoAnimationController.dispose();
    _firstButtonController.dispose();
    _secondButtonController.dispose();
    _thirdButtonController.dispose();
    _fourthButtonController.dispose();
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
            const SizedBox(height: 75),

            Transform.translate(
              offset: const Offset(0, -50),
              child: ScaleTransition(
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
            ),
            const SizedBox(height: 10),
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 8),
                end: const Offset(0, 0),
              ).animate(_firstButtonController),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                child: Card(
                  color: Colors.white,
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/home');
                    },
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: Image.asset(
                            'images/splash1.png', // Update with your actual image path
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10), // Add spacing between image and text
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Text(
                              "Software Only",
                              style: TextStyle(
                                color: Colors.indigo[800],
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                fontFamily: GoogleFonts.poppins().fontFamily,
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
            const SizedBox(height: 8),
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 7),
                end: const Offset(0, 0),
              ).animate(_secondButtonController),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                child: Card(
                  color: Colors.white,
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/home');
                    },
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: Image.asset(
                            'images/splash2.png', // Update with your actual image path
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10), // Add spacing between image and text
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Text(
                              "Software Sprayer",
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.indigo[800],
                                fontWeight: FontWeight.w600,
                                fontFamily: GoogleFonts.poppins().fontFamily,
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
            const SizedBox(height: 8),
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 7),
                end: const Offset(0, 0),
              ).animate(_thirdButtonController),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                child: Card(
                  color: Colors.white,
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/home');
                    },
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: Image.asset(
                            'images/splash2.png', // Update with your actual image path
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10), // Add spacing between image and text
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Text(
                              "Software + UGV",
                              style: TextStyle(
                                color: Colors.indigo[800],
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                fontFamily: GoogleFonts.poppins().fontFamily,
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
            const SizedBox(height: 8),
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 9),
                end: const Offset(0, 0),
              ).animate(_fourthButtonController),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 10.0),
                child: Card(
                  color: Colors.white,
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/home');
                    },
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: 80,
                          height: 80,
                          child: Image.asset(
                            'images/splash2.png', // Update with your actual image path
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(width: 10), // Add spacing between image and text
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Text(
                              "Software + UAV",
                              style: TextStyle(
                                color: Colors.indigo[800],
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                fontFamily: GoogleFonts.poppins().fontFamily,
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
          ],
        ),
      ),
    );
  }
}
*/