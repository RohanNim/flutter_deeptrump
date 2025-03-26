import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:logging/logging.dart';

class ResultPage extends StatefulWidget {
  final String generatedText;
  final String videoUrl;
  
  const ResultPage({
    super.key,
    required this.generatedText,
    required this.videoUrl,
  });

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  bool _isPlaying = false;
  double _playbackProgress = 0.0;
  int _selectedIndex = 0;
  late VideoPlayerController _videoController;
  bool _isInitialized = false;
  final _logger = Logger('ResultPage');

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.network(widget.videoUrl);
      await _videoController.initialize();
      _videoController.addListener(_videoListener);
      setState(() {
        _isInitialized = true;
      });
      _videoController.play();
    } catch (e) {
      _logger.severe('Error initializing video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading video: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _videoListener() {
    if (_videoController.value.isInitialized) {
      setState(() {
        _isPlaying = _videoController.value.isPlaying;
        _playbackProgress = _videoController.value.position.inMilliseconds /
            _videoController.value.duration.inMilliseconds;
      });
    }
  }

  @override
  void dispose() {
    _videoController.removeListener(_videoListener);
    _videoController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // TODO: Implement navigation between different sections
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Trump Voice'),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            // Video Player
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _isInitialized
                      ? VideoPlayer(_videoController)
                      : const Center(
                          child: CircularProgressIndicator(),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Generated Text Display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.generatedText,
                style: const TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 30),
            // Playback Controls
            if (_isInitialized) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      final newPosition = _videoController.value.position - 
                          const Duration(seconds: 10);
                      _videoController.seekTo(newPosition);
                    },
                    icon: const Icon(Icons.replay_10, size: 40),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _isPlaying = !_isPlaying;
                        _isPlaying 
                            ? _videoController.play()
                            : _videoController.pause();
                      });
                    },
                    icon: Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      size: 60,
                      color: Colors.red.shade900,
                    ),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    onPressed: () {
                      final newPosition = _videoController.value.position + 
                          const Duration(seconds: 10);
                      _videoController.seekTo(newPosition);
                    },
                    icon: const Icon(Icons.forward_10, size: 40),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Progress Bar
              Slider(
                value: _playbackProgress,
                onChanged: (value) {
                  final newPosition = Duration(
                    milliseconds: (value * _videoController.value.duration.inMilliseconds).toInt(),
                  );
                  _videoController.seekTo(newPosition);
                },
                activeColor: Colors.red.shade900,
              ),
            ],
            const SizedBox(height: 20),
            // Share Button
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement share functionality
              },
              icon: const Icon(Icons.share),
              label: const Text('Share'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade900,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.red.shade900,
        onTap: _onItemTapped,
      ),
    );
  }
} 