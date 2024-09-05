import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Constant/forget_password_provider.dart';

class ForgotPasswordScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      constraints: BoxConstraints(
        maxWidth: 400,
        maxHeight: viewInsets.bottom == 0 ? 200 : 800,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: const BoxDecoration(
                color: Color(0xFF0A8C52), // Green header
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Forgot Password',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                      color: Colors.white, // White text
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_outlined, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Body Section

            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 5, 20, 1),

                child: SingleChildScrollView(
                  reverse: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TextField(
                        onChanged: Provider.of<ForgotPasswordProvider>(context, listen: false).setEmail,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Email',
                          labelStyle: GoogleFonts.poppins(color: Colors.black87),
                          hintText: 'johndoe@mail.com',
                          hintStyle: GoogleFonts.poppins(color: Colors.black87),
                          prefixIcon: const Icon(Icons.email, color: Colors.black87),
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: 120,
                        child: ElevatedButton(
                          onPressed: Provider.of<ForgotPasswordProvider>(context, listen: false).isLoading
                              ? null
                              : () async {
                            await Provider.of<ForgotPasswordProvider>(context, listen: false)
                                .submitForgotPassword(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0A8C52),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Provider.of<ForgotPasswordProvider>(context, listen: true).isLoading
                              ? const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          )
                              : Text(
                            'Submit',
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w400,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),

                      ),
                      const SizedBox(height: 3),

                    ],
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
