import 'package:flutter/material.dart';
import 'package:flutter_starter/presenter/themes/colors.dart';
import 'package:flutter_starter/presenter/themes/themes.dart';

class LightAppTheme extends AppTheme {
  const LightAppTheme()
    : super(
        name: 'light',
        brightness: Brightness.light,
        colors: const AppThemeColors(
          primarySwatch: Colors.blue,
          primary: Color(0xFF0061A4),
          secondary: Color(0xFF526070),
          accent: Color(0xFF4A627B),
          background: Color(0xFFF8F9FF),
          backgroundDark: Color(0xFFF2F3FA),
          disabled: Color(0x64303943),
          information: Color(0xFF0061A4),
          success: Color(0xFF146C2E),
          alert: Color(0xFF765A00),
          warning: Color(0xFF765A00),
          error: Color(0xFFBA1A1A),
          text: Color(0xFF191C20),
          textOnPrimary: Color(0xFFFFFFFF),
          border: Color(0xFF73777F),
          hint: Color(0xFF42474E),
        ),
      );
}
