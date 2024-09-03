import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:google_fonts/google_fonts.dart';

import '../Constant/controller_weather.dart';

/*class WeatherDashboard extends StatelessWidget {
  final WeatherController weatherController = Get.put(WeatherController());
  final String avatarUrl = 'https://firebasestorage.googleapis.com/v0/b/unisoft-tmp.appspot.com/o/Default%2Fdummy-profile.png?alt=media&token=ebbb29f7-0ab8-4437-b6d5-6b2e4cfeaaf7';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green[100], // Adjust background color as needed
      body: Column(
        children: [
          // Top Section with Avatar, Notification, and User Greeting
       Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(avatarUrl),
            radius: 30,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Hello\n Zain Ali',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.notifications),
            onPressed: () {},
          ),
        ],
      ),
    ),

          // Location Capsule
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.5),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
              child: Row(
                children: [
                  // Display the weather condition image dynamically
                  Obx(() {
                    String iconUrl = weatherController.weather.value.icon;
                    String iconName = iconUrl.split('/').last.split('.').first; // Extract icon name without extension
                    return SvgPicture.asset(
                      'images/$iconName.svg', // Use dynamic icon name
                      width: 50,
                      height: 50,
                    );
                  }),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Obx(() {
                      return Text(
                        'Location\n${weatherController.weather.value.cityname}', // Display dynamic location name
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          fontFamily: GoogleFonts.poppins().fontFamily,
                        ),
                      );
                    }),
                  ),
                  // Display a fixed image or another dynamic image as needed
                  Image.asset('images/splash3.png', width: 50, height: 50), // Example fixed image
                ],
              ),

          ),

          SizedBox(height: 20),

          // Weather Cards
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Wind Speed Card
                  Obx(() {
                    return WeatherCard(
                      icon: Icons.air,
                      label: 'Wind Speed',
                      value: '${weatherController.weather.value.windspeed.toStringAsFixed(1)} m/s',
                    );
                  }),
                  // Humidity Card
                  Obx(() {
                    return WeatherCard(
                      icon: Icons.water_drop,
                      label: 'Humidity',
                      value: '${weatherController.weather.value.humidity}%',
                    );
                  }),
                ],
              ),

          ),
        ],
      ),
      // BottomAppBar with V-shape
    );
  }
}*/
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class WeatherCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color cardColor; // Color of the card
  final Color textColor; // Color of the text

  WeatherCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.cardColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(

      padding: EdgeInsets.fromLTRB(10,15,10,15),
      decoration: BoxDecoration(
        color: cardColor, // Set card color
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            spreadRadius: 2,
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 24, color: textColor), // Set icon color
          const SizedBox(height: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor, // Set label text color
              fontFamily: GoogleFonts.poppins().fontFamily,
            ),
          ),
          SizedBox(height: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: textColor, // Set value text color
              fontFamily: GoogleFonts.poppins().fontFamily,
            ),
          ),
        ],
      ),
    );
  }
}
