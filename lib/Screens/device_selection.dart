import 'dart:async'; // For Timer
import 'dart:ui'; // For BackdropFilter
import 'package:cloud_firestore/cloud_firestore.dart'; // Add Firestore package
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'Fetch_Input.dart';
import 'SaaS.dart';
import 'homescreen.dart';

class DeviceSelection extends StatefulWidget {
  @override
  _DeviceSelectionState createState() => _DeviceSelectionState();
}

class _DeviceSelectionState extends State<DeviceSelection>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  late Timer _timer;
  List<Map<String, dynamic>> _devices = [];

  @override
  void initState() {
    super.initState();
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

    // Fetch devices from Firestore when the widget initializes
    _fetchDevices();

    // Set up a timer to refresh the device list every 5 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _fetchDevices();
    });
  }

  Map<String, dynamic>? _farmerData;

  Future<void> _fetchDevices() async {
    final FirebaseAuth _auth = FirebaseAuth.instance;
    final User? user = _auth.currentUser;

    // Ensure the user is logged in
    if (user != null) {
      try {
        // Fetch farmer's document from Firestore
        final DocumentSnapshot<
            Map<String, dynamic>> farmerDoc = await FirebaseFirestore.instance
            .collection('Farmer')
            .doc(user.uid) // Use user.uid to fetch the document
            .get();

        // Check if document exists
        if (farmerDoc.exists && farmerDoc.data() != null) {
          setState(() {
            _farmerData = farmerDoc.data(); // Store farmer's data
            _devices = List<Map<String, dynamic>>.from(
                _farmerData?['Purchased_Devices'] ?? []);
          });
        }
      } catch (e) {
        print('Error fetching devices: $e');
      }
    } else {
      print('No user is currently logged in.');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _timer.cancel(); // Cancel the timer when the widget is disposed
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'images/bg.jpeg',
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 1.0, sigmaY: 1.0),
                  child: Card(
                    color: Colors.white.withOpacity(0.55),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    elevation: 6,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          decoration: const BoxDecoration(
                            color: Color(0xFF037441),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(16.0),
                              topRight: Radius.circular(16.0),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Left Side: Avatar
                              CircleAvatar(
                                radius: 24,
                                backgroundImage: NetworkImage(
                                  _farmerData?['avatarUrl'] ??
                                      'https://firebasestorage.googleapis.com/v0/b/unisoft-tmp.appspot.com/o/Default%2Fdummy-profile.png?alt=media&token=ebbb29f7-0ab8-4437-b6d5-6b2e4cfeaaf7',
                                ),
                              ),
                              // Center: Name
                              Expanded(
                                child: Center(
                                  child: Text(
                                    'Welcome, ${_farmerData?['Name'] ?? ''}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              // Right Side: Email
                              Text(
                                _farmerData?['email'] ?? '',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Conditionally display content
                        _devices.isNotEmpty
                            ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Conditional text
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 15.0),
                              child: Center(
                                child: RichText(
                                  text: TextSpan(
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF037441),
                                    ),
                                    children: const [
                                      TextSpan(text: "You Have Purchased the Following Devices"),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            // Device Table
                            Padding(
                              padding: const EdgeInsets.all(15.0),
                              child: Table(
                                border: TableBorder.all(color: Colors.black87),
                                columnWidths: const {
                                  0: FlexColumnWidth(2),
                                  1: FlexColumnWidth(2),
                                  2: FlexColumnWidth(2),
                                  3: FlexColumnWidth(1),
                                },
                                children: [
                                  // Table header
                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[300],
                                    ),
                                    children: const [
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(5, 10, 5, 10),
                                        child: Center(
                                          child: Text(
                                            "Device ID",
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(5, 10, 5, 10),
                                        child: Center(
                                          child: Text(
                                            "Device Name",
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.fromLTRB(5, 10, 5, 10),
                                        child: Center(
                                          child: Text(
                                            "Device Type",
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Table rows with device data
                                  for (var device in _devices)
                                    TableRow(
                                      children: [
                                        Center(
                                          child: Padding(
                                            padding: EdgeInsets.fromLTRB(5, 10, 5, 10),
                                            child: Text(
                                              device['device_Id'],
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Center(
                                          child: Padding(
                                            padding: EdgeInsets.fromLTRB(5, 10, 5, 10),
                                            child: Text(
                                              device['device_Name'],
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Center(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Padding(
                                                padding: const EdgeInsets.all(2.0),
                                                child: Text(
                                                  device['device_Type'] ?? "Unknown",
                                                  style: GoogleFonts.poppins(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: Colors.black87,
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.fromLTRB(5, 2, 2, 2),
                                                child: ElevatedButton(
                                                  onPressed: () {
                                                    Navigator.pushReplacement(
                                                      context,
                                                      MaterialPageRoute(builder: (context) => const MyHomePage()),
                                                    );
                                                  },
                                                  style: ElevatedButton.styleFrom(
                                                    backgroundColor: const Color(0xFF037441),
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 20,
                                                      vertical: 10,
                                                    ),
                                                    shape: RoundedRectangleBorder(
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                  ),
                                                  child: Text(
                                                    "Connect",
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 13,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],
                        )
                            : Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              "You Do Not Have Purchased Any Device",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFC11927),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => SaaS_Home()), // Adjust the navigation as needed
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF037441),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                "Use Our Software Solution",
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                          ],
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