import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';

void main() => runApp(const UtsurikomiApp());

class UtsurikomiApp extends StatelessWidget {
  const UtsurikomiApp({super.key});

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFF171513);
    const cream = Color(0xFFF2E8D5);
    const amber = Color(0xFFC99A5B);
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData.dark().textTheme,
    );

    return MaterialApp(
      title: 'Utsurikomi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ink,
        colorScheme: const ColorScheme.dark(
          surface: ink,
          primary: cream,
          secondary: amber,
        ),
        textTheme: baseTextTheme.apply(
          bodyColor: cream,
          displayColor: cream,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: ink,
          elevation: 0,
          titleTextStyle: TextStyle(
              color: cream, fontSize: 20, fontWeight: FontWeight.w700),
          iconTheme: IconThemeData(color: cream),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.white.withValues(alpha: 0.08),
          selectedColor: amber,
          labelStyle: const TextStyle(color: cream),
          secondaryLabelStyle: const TextStyle(color: ink),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: BorderSide.none,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: cream,
            foregroundColor: ink,
            elevation: 4,
            shadowColor: amber.withValues(alpha: 0.25),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.06),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: amber),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
