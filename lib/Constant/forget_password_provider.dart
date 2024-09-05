import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ForgotPasswordProvider with ChangeNotifier {
  String _email = '';
  bool _isLoading = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get email => _email;
  bool get isLoading => _isLoading;

  void setEmail(String email) {
    _email = email;
    notifyListeners();
  }

  Future<void> submitForgotPassword(BuildContext context) async {
    notifyListeners();

    try {
      await _auth.sendPasswordResetEmail(email: _email);
      _showSuccessDialog(context);
    } catch (error) {
      _showErrorSnackbar(context, error.toString());
    }
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Center(
          child: Text(
            'Password Reset',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: Colors.black,
            ),
          ),
        ),

        content: Column(

          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/success.png',
              height: 170,
              width: 170,
            ), // Ensure this image exists in your assets
            const SizedBox(height: 10),
            const SizedBox(width: 20),
            Text(
              'Password reset link sent.',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Colors.indigo[800],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.contains('user-not-found')
            ? 'Email does not exist.'
            : 'Error: $message'),
      ),
    );
  }
}
