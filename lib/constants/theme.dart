import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF1e5955);
  static const Color secondaryColor = Color(0xFF2c847e);
  
  static const LinearGradient mainGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1e5955),
      Color(0xFF2c847e),
      Color(0xFF1e5955),
    ],
  );

  static BoxDecoration inputDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(15),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 10,
        offset: const Offset(0, 5),
      ),
    ],
  );

  static BoxDecoration buttonDecoration = BoxDecoration(
    borderRadius: BorderRadius.circular(15),
    boxShadow: [
      BoxShadow(
        color: secondaryColor.withOpacity(0.3),
        blurRadius: 10,
        offset: const Offset(0, 5),
      ),
    ],
  );

  static InputDecoration textFieldDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      hintText: hintText,
      prefixIcon: Icon(prefixIcon, color: primaryColor),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
    );
  }

  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: secondaryColor,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15),
    ),
    padding: const EdgeInsets.symmetric(vertical: 15),
  );
} 