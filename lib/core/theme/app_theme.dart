import 'package:flutter/material.dart';

// Central place to define app-wide visual styling.
class AppTheme {
  // Brand/primary accent color used to seed the color scheme.
  static const _abbRed = Color(0xFFE60000);

  // Light theme configuration applied across the app.
  // Uses Material 3 and a seeded color scheme for consistent tones.
  static ThemeData get light => ThemeData(
        useMaterial3: true,               
        colorSchemeSeed: _abbRed,          
        scaffoldBackgroundColor: const Color(0xFFF5F5F7), 
        textTheme: const TextTheme(
          headlineMedium: TextStyle(fontWeight: FontWeight.w700), 
        ),
      );

  // Public accent color reference to keep usage consistent.
  static const Color accent = _abbRed;
}
