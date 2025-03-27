import 'package:flutter/material.dart';
import '../bottom_nav_bar.dart';
import 'transcript_input_page.dart';
import 'videos_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  // List of pages to display in the bottom navigation
  final List<Widget> _pages = [
    const TranscriptInputPage(showBottomNav: false),
    const VideosPage(showBottomNav: false),
    const Center(child: Text('History - Coming Soon')), // Placeholder
    const Center(child: Text('Settings - Coming Soon')), // Placeholder
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
