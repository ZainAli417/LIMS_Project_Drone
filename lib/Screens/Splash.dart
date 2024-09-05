import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../Constant/splash_provider.dart';
import 'LoginScreen.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Ensure Firebase is set up in your project.

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late SplashProvider splashProvider;

  @override
  void initState() {
    super.initState();
    splashProvider = SplashProvider();
    splashProvider.initControllers(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    splashProvider.startAnimations();
    precacheImage(const AssetImage('images/bg.jpeg'), context);
    precacheImage(const AssetImage('images/logo.png'), context);
  }

  @override
  void dispose() {
    splashProvider.disposeControllers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SplashProvider>(
      create: (_) => splashProvider,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'images/bg.jpeg',
                fit: BoxFit.cover,
              ),
            ),
            Consumer<SplashProvider>(
              builder: (context, provider, child) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: provider.logoController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, provider.logoAnimation.value),
                            child: child,
                          );
                        },
                        child: Column(
                          children: [
                            Image.asset(
                              'images/logo.png',
                              width: 200,
                              height: 200,
                            ),
                            const SizedBox(height: 10),
                            RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'LIMS ',
                                    style: GoogleFonts.poppins(
                                      color: Colors.black,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'Robo',
                                    style: GoogleFonts.poppins(
                                      color: Colors.red,
                                      fontSize: 32,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      FadeTransition(
                        opacity: provider.buttonFadeAnimation,
                        child: Column(
                          children: [
                            ElevatedButton.icon(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (context) => LoginScreen()),
                                );
                              },
                              icon: const Icon(
                                Icons.email,
                                color: Colors.white,
                                size: 24,
                              ),
                              label: Text(
                                'Continue with Email',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 18,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0A8C52),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                  horizontal: 32,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await _handleGoogleSignIn();
                              },
                              icon: Image.asset(
                                'images/cart.png',
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              ),
                              label: Text(
                                'Purchase Devices',
                                style: GoogleFonts.poppins(
                                  color: Color(0xFF0A8C52),
                                  fontSize: 18,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                              ),
                            ),
                            const SizedBox(height: 150),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      UserCredential userCredential =
      await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
      print(userCredential.user?.displayName);
    } catch (e) {
      print("Error during Google Sign-In: $e");
    }
  }
}
