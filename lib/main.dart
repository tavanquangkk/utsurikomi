import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() => runApp(const UtsurikomiApp());

class UtsurikomiApp extends StatelessWidget {
  const UtsurikomiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Utsurikomi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.black,
          elevation: 0,
          titleTextStyle: TextStyle(
              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        fontFamily: 'Inter',
      ),
      home: const HomeScreen(),
    );
  }
}
