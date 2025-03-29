import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_deeptrump/pages/transcription_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'pages/transcript.dart';
import 'pages/result_page.dart';
import 'pages/transcript_input_page.dart';
import 'pages/home_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'DeepTrump',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        primaryColor: Colors.red.shade900,
        useMaterial3: true,
      ),
      home: const LandingPage(),
    );
  }
}

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Base color background
          Container(
            decoration: const BoxDecoration(
              color: Color.fromRGBO(11, 2, 28, 1),
            ),
          ),
          Positioned.fill(
            child: SvgPicture.asset(
              'assets/svg/Bg_color.svg',
              fit: BoxFit.cover,
            ),
          ),
          // Grid pattern overlay
          Positioned.fill(
            child: SvgPicture.asset(
              'assets/svg/Bg_grid.svg',
              fit: BoxFit.cover,
            ),
          ),
          // Glow effect at top
          // Positioned(
          //   top: 0,
          //   left: 0,
          //   right: 0,
          //   child: ImageFiltered(
          //     imageFilter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          //     child: SvgPicture.asset(
          //       'assets/svg/Glow_bg.svg',
          //       colorFilter: const ColorFilter.mode(
          //         Color.fromRGBO(236, 109, 255, 0.2),
          //         BlendMode.srcIn,
          //       ),
          //       fit: BoxFit.contain,
          //     ),
          //   ),
          // ),
          Positioned(
            top: -170,
            left: 0,
            right: 0,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: 300, sigmaY: 300),
              child: Container(
                width: 386,
                height: 386,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Color.fromARGB(60, 89, 39, 98),
                      Color.fromARGB(119, 89, 39, 98),
                      Color.fromARGB(99, 224, 143, 238),
                      // Colors.purpleAccent,
                      // Colors.purple,
                      Color.fromARGB(57, 155, 39, 176),
                      Color.fromARGB(69, 155, 39, 176),
                      Color.fromARGB(57, 155, 39, 176),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.all(32),
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.34),
                SvgPicture.asset(
                  'assets/svg/deeptrump.svg',
                  width: 212,
                  height: 43,
                  color: Colors.white,
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.2),
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        // MaterialPageRoute(
                        //   builder: (context) => const HomePage(),
                        // ),
                        MaterialPageRoute(
                          builder: (context) => TranscriptionPage(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red.shade900,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 48, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
