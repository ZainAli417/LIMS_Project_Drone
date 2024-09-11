import 'dart:async'; // For Timer
import 'dart:ui'; // For BackdropFilter
import 'package:cloud_firestore/cloud_firestore.dart'; // Add Firestore package
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../Constant/ISSAASProvider.dart';
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
        final DocumentSnapshot<Map<String, dynamic>> farmerDoc =
            await FirebaseFirestore.instance
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
            child: Column(
              children: [
                SizedBox(height: 50), // Add space above the logo
                Image.asset(
                  'images/logo.png', // Your logo image
                  width: 230,
                  height: 230,
                ),
                SizedBox(height: 20), // Add space above the logo

                SlideTransition(
                  position: _slideAnimation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
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
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 10),
                              decoration: const BoxDecoration(
                                color: Color(0xFF037441),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(16.0),
                                  topRight: Radius.circular(16.0),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
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
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 15.0),
                                        child: Center(
                                          child: RichText(
                                            text: TextSpan(
                                              style: GoogleFonts.poppins(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF037441),
                                              ),
                                              children: const [
                                                TextSpan(
                                                    text:
                                                        "The following LIMS devices are registered with this account"),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      // Device Table
                                      Padding(
                                        padding: const EdgeInsets.all(7.0),
                                        child: Column(
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  width: 1,
                                                  color: Colors.black87,
                                                ),
                                                borderRadius: const BorderRadius.only(
                                                  topLeft: Radius.circular(15),
                                                  topRight: Radius.circular(15),
                                                ),
                                              ),
                                              child: Table(
                                                border: const TableBorder(
                                                  top: BorderSide.none,
                                                  bottom: BorderSide.none,
                                                  left: BorderSide.none,
                                                  right: BorderSide.none,
                                                  horizontalInside: BorderSide(
                                                      width: 1,
                                                      color: Colors.black87),
                                                ),
                                                children: [
                                                  // Table header with curved top border and green color
                                                  TableRow(
                                                    decoration:
                                                        const BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.only(
                                                        topLeft:
                                                            Radius.circular(15),
                                                        topRight:
                                                            Radius.circular(15),
                                                      ),
                                                      color: Color(
                                                          0xFF037441), // Green header color
                                                    ),
                                                    children: [
                                                      Padding(
                                                        padding: const EdgeInsets
                                                            .fromLTRB(5, 10, 5,
                                                            10), // Reduced padding
                                                        child: Center(
                                                          child: Text(
                                                            "ID",
                                                            style: GoogleFonts
                                                                .poppins(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding: const EdgeInsets
                                                            .fromLTRB(5, 10, 5, 10), // Reduced padding
                                                        child: Center(
                                                          child: Text(
                                                            "Name",
                                                            style: GoogleFonts
                                                                .poppins(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding: const EdgeInsets
                                                            .fromLTRB(5, 10, 5,
                                                            10), // Reduced padding
                                                        child: Center(
                                                          child: Text(
                                                            "Type",
                                                            style: GoogleFonts
                                                                .poppins(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Padding(
                                                        padding: const EdgeInsets
                                                            .fromLTRB(5, 10, 5,
                                                            10), // Reduced padding
                                                        child: Center(
                                                          child: Text(
                                                            "Status",
                                                            style: GoogleFonts
                                                                .poppins(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  // Table rows with device data and alternating row colors
                                                  for (int i = 0;
                                                      i < _devices.length;
                                                      i++)
                                                    TableRow(
                                                      decoration: i % 2 == 0
                                                          ? const BoxDecoration(
                                                               color: Color(
                                                                   0xFFC3FFD6),) // Light green for odd rows
                                                          : const BoxDecoration(
                                                              color:
                                                                  Colors.white),
                                                      children: [
                                                        Padding(
                                                          padding: const EdgeInsets
                                                              .fromLTRB(5, 10, 5,
                                                              10), // Reduced padding
                                                          child: Center(
                                                            child: Text(
                                                              _devices[i]
                                                                  ['device_Id'],
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets
                                                              .fromLTRB(5, 10, 5,
                                                              10),  // Reduced padding
                                                          child: Center(
                                                            child: Text(
                                                              _devices[i][
                                                                  'device_Name'],
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets
                                                              .fromLTRB(5, 10, 5,
                                                              10), // Reduced padding
                                                          child: Center(
                                                            child: Text(
                                                              _devices[i][
                                                                      'device_Type'] ??
                                                                  "Unknown",
                                                              style: GoogleFonts
                                                                  .poppins(
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding: const EdgeInsets.all(4),// Reduced padding
                                                          child: Center(
                                                            child:
                                                                ElevatedButton(
                                                              onPressed: () {
                                                                Navigator
                                                                    .pushReplacement(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                      builder:
                                                                          (context) =>
                                                                              const MyHomePage()),
                                                                );
                                                              },
                                                              style:
                                                                  ElevatedButton
                                                                      .styleFrom(
                                                                backgroundColor:
                                                                    const Color(
                                                                        0xFF037441),
                                                                    padding: const EdgeInsets
                                                                        .fromLTRB(5, 10, 5,
                                                                        10),
                                                                    shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                            10)),
                                                              ),
                                                              child: Text(
                                                                "Connect",
                                                                style: GoogleFonts.poppins(
                                                                    fontSize:
                                                                        13,
                                                                    color: Colors
                                                                        .white),
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      const SizedBox(height: 30),

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
                                          context.read<ISSAASProvider>().setIsSaas(
                                              true); // Set ISSAAS state to true
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  const MyHomePage(), // Pass the boolean value
                                            ),
                                          );
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFF037441),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}
