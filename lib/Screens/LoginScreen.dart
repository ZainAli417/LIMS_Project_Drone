import 'dart:ui'; // For BackdropFilter

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:location/location.dart' as gps; // Prefixed location
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../Constant/login_provider.dart';
import 'ForgetPasswordScreen.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  bool _passwordVisible = false;

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    requestLocationPermission();
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );

    _slideAnimation = Tween<Offset>(
      begin: Offset(1.0, 0.0),
      end: Offset(0.0, 0.0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  final gps.Location _location = gps.Location();

  Future<void> requestLocationPermission() async {

    // Check if location service is enabled
    bool _serviceEnabled;
    PermissionStatus _permissionGranted;

    _serviceEnabled = await _location.serviceEnabled();
    if (!_serviceEnabled) {
      // Location services are not enabled, you can show a dialog or a message to the user
      _serviceEnabled = await _location.requestService();
      if (!_serviceEnabled) {
        return; // Service not enabled, exit the function
      }
    }

    // Check for location permission
    _permissionGranted = await _location.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await _location.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return; // Permission denied, exit the function
      }
    }
    // Location permission granted, proceed with your logic
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'images/bg.jpeg', // Ensure the image is placed correctly in your assets folder.
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.0), // Slight blur effect
                  child: Card(
                    color: Colors.white.withOpacity(0.55), // Slight opacity for the blur effect
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    elevation: 6,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 30,horizontal: 10),
                          decoration:  const BoxDecoration(
                            color: Color(0xFF037441), // Indigo header
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16.0),
                              topRight: Radius.circular(16.0),
                            ),
                          ),
                          child: Center(
                            child: RichText(
                              text: TextSpan(
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                                children: const [
                                  TextSpan(text: "Let's Sign in, Welcome back"),

                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                SizedBox(height: 20),
                                TextFormField(
                                  controller: Provider.of<LoginProvider>(context).emailController,
                                  style: TextStyle(color: Colors.black87),
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    labelStyle: GoogleFonts.poppins(color: Colors.black87),
                                    hintText: 'johndoe@mail.com',
                                    hintStyle: GoogleFonts.poppins(color: Colors.black87),
                                    prefixIcon: Icon(Icons.email, color: Colors.black87),
                                    filled: true,
                                    border: OutlineInputBorder(

                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: 20),
                                TextFormField(
                                  controller: Provider.of<LoginProvider>(context).passwordController,
                                  obscureText: !_passwordVisible,
                                  style: const TextStyle(color: Colors.black87),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    labelStyle: GoogleFonts.poppins(color: Colors.black87),
                                    hintText: '********',
                                    hintStyle: GoogleFonts.poppins(color: Colors.black87),
                                    prefixIcon: const Icon(Icons.lock, color: Colors.black87),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _passwordVisible ? Icons.visibility : Icons.visibility_off,
                                        color: Colors.black87,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _passwordVisible = !_passwordVisible;
                                        });
                                      },
                                    ),
                                    filled: true,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: false,
                                        builder: (context) => ForgotPasswordScreen(),
                                      );
                                    },
                                    child: Text(
                                      'Forgot password?',
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xFF037441),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: 20),
                                Center(
                                  child: Consumer<LoginProvider>(
                                    builder: (context, loginProvider, child) {
                                      return ElevatedButton(
                                        onPressed: () {
                                          if (_formKey.currentState!.validate()) {
                                            loginProvider.login(context);
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Color(0xFF037441),
                                          padding: const EdgeInsets.symmetric(horizontal: 75, vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: loginProvider.isLoading
                                            ? const CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(Colors.white),
                                        )
                                            : Text(
                                          'Sign in',
                                          style: GoogleFonts.poppins(
                                            fontSize: 18,
                                            color: Colors.white,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(height: 20),
                                Center(
                                  child: Column(
                                    children: [
                                      Text(
                                        "By logging in, you agree to our",
                                        style: GoogleFonts.poppins(fontSize: 13, color: Colors.black87,fontWeight: FontWeight.w500),
                                      ),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          TextButton(
                                            onPressed: () async {
                                              const url = '';
                                              if (await launchUrl(url as Uri)) {
                                                await launchUrl(url as Uri);
                                              } else {
                                                throw 'Could not launch $url';
                                              }
                                            },
                                            child: Text(
                                              'Terms & Condition',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: Colors.black87,
                                                fontWeight: FontWeight.w500,
                                                decoration: TextDecoration.underline,

                                              ),
                                            ),
                                          ),
                                          Text(' & ', style: GoogleFonts.poppins(fontSize: 13)),
                                          TextButton(
                                            onPressed: () async {
                                              const url = '';
                                              if (await canLaunch(url)) {
                                                await launch(url);
                                              } else {
                                                throw 'Could not launch $url';
                                              }
                                            },
                                            child: Text(
                                              'Privacy Policy',
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                color: Colors.black87,

                                                fontWeight: FontWeight.w500,
                                                decoration: TextDecoration.underline,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
