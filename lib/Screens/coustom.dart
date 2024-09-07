import 'package:flutter/material.dart';
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
