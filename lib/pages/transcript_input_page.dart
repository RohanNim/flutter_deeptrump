import 'package:flutter/material.dart';
import '../services/trump_api_service.dart';
import 'result_page.dart';
import 'videos_page.dart';

class TranscriptInputPage extends StatefulWidget {
  const TranscriptInputPage({super.key});

  @override
  State<TranscriptInputPage> createState() => _TranscriptInputPageState();
}

class _TranscriptInputPageState extends State<TranscriptInputPage> {
  final TextEditingController _textController = TextEditingController();
  bool _isGenerating = false;
  int _selectedIndex = 0;
  final _apiService = TrumpApiService();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const VideosPage()),
        );
        break;
      case 2:
        // TODO: Implement history page navigation
        break;
      case 3:
        // TODO: Implement settings page navigation
        break;
    }
  }

  void _generateVideo() async {
    if (_textController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter some text first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    // Clear any existing snackbars
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    try {
      // Show loading message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Submitting your text to DeepTrump...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Submit the transcript and get a session ID
      final sessionId = await _apiService.submitTranscript(_textController.text);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing your video. This may take up to a minute...'),
            duration: Duration(seconds: 5),
          ),
        );
      }

      // Show progress updates
      int waitTime = 0;
      bool showUpdateMessage = true;
      
      // Wait for the video to be ready
      final videoData = await _apiService.waitForVideoCompletion(
        sessionId,
        maxAttempts: 40,  // Increase max attempts (80 seconds)
        delaySeconds: 2,
        onProgress: (int attempt, int max) {
          waitTime = attempt * 2; // 2 seconds per attempt
          
          // Show update message at 10, 20, 40 seconds
          if ((waitTime == 10 || waitTime == 20 || waitTime == 40) && 
              mounted && 
              showUpdateMessage) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Still waiting for video... ($waitTime seconds)'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
      );
      
      // Clear any existing snackbars before navigating
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      
      // Navigate to the result page
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResultPage(
              generatedText: videoData['response_text'] ?? _textController.text,
              videoUrl: videoData['video_url'],
            ),
          ),
        ).then((_) {
          // Reset generating state after returning from result page
          if (mounted) {
            setState(() {
              _isGenerating = false;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        
        // Make error messages more user-friendly
        if (errorMessage.contains('timeout')) {
          errorMessage = 'The video is taking too long to generate. Please try again with a shorter text.';
        } else if (errorMessage.contains('Network error')) {
          errorMessage = 'Network connection problem. Please check your internet and try again.';
        } else if (errorMessage.contains('Session ID not found')) {
          errorMessage = 'Server problem processing your request. Please try again later.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Try Again',
              onPressed: () {
                _generateVideo();
              },
              textColor: Colors.white,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enter Your Text'),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            const Text(
              'What would you like Trump to say?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: TextField(
                controller: _textController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Enter your text here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isGenerating ? null : _generateVideo,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade900,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isGenerating
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Generate Trump Video',
                      style: TextStyle(fontSize: 18),
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.video_library), label: 'Videos'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.red.shade900,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
} 