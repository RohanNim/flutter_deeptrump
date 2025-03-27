import 'package:flutter/material.dart';
import '../services/trump_api_service.dart';
import 'result_page.dart';
import 'videos_page.dart';
import '../bottom_nav_bar.dart';
import 'package:flutter/rendering.dart';
import 'dart:async';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';

class TranscriptInputPage extends StatefulWidget {
  final bool showBottomNav;

  const TranscriptInputPage({
    super.key,
    this.showBottomNav = true,
  });

  @override
  State<TranscriptInputPage> createState() => _TranscriptInputPageState();
}

class _TranscriptInputPageState extends State<TranscriptInputPage> {
  final TextEditingController _textController = TextEditingController();
  bool _isGenerating = false;
  int _selectedIndex = 0;
  final _apiService = TrumpApiService();
  final _dio = Dio();

  // Add variables for progress tracking and video display
  String? _currentSessionId;
  double _progressPercent = 0;
  bool _videoReady = false;
  String? _videoUrl;
  String? _generatedText;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  // Progress checking timer
  Timer? _progressTimer;

  // Add variables to track user selections
  String _selectedLanguage = "en";
  String _selectedVideoChoice = "video2";
  String _selectedVoiceStyle = "confident";
  String _selectedVideoQuality = "medium";
  String _selectedVideoEffect = "none";

  // Define the option maps
  final Map<String, String> _languages = {
    "en": "English",
    "es": "Spanish",
    "fr": "French",
    "de": "German",
    "zh": "Chinese",
    "ja": "Japanese",
    "ko": "Korean",
    "hi": "Hindi (हिन्दी)"
  };

  final Map<String, String> _videoChoices = {
    "video1": "Presidential Speech",
    "video2": "Trump at Desk",
    "video3": "Trump Interview Style"
  };

  final Map<String, String> _voiceStyles = {
    "confident": "Confident (Default)",
    "angry": "Angry",
    "calm": "Calm",
    "enthusiastic": "Enthusiastic"
  };

  final Map<String, String> _videoQualities = {
    "medium": "Medium (Default)",
    "high": "High"
  };

  final Map<String, String> _videoEffects = {
    "none": "None (Default)",
    "vintage": "Vintage",
    "black_white": "Black & White",
    "sepia": "Sepia",
    "dramatic": "Dramatic"
  };

  @override
  void dispose() {
    _textController.dispose();
    _progressTimer?.cancel();
    _videoController?.dispose();
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

  // Add method to check progress
  void _startProgressChecking(String sessionId) {
    _currentSessionId = sessionId;

    // Cancel any existing timer
    _progressTimer?.cancel();

    // Create a new timer that checks progress every 2 seconds
    _progressTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        // First check if video is ready
        final videoData = await _apiService.checkVideoStatus(sessionId);

        if (videoData != null) {
          // Video is ready, stop timer and update UI
          timer.cancel();

          if (mounted) {
            setState(() {
              _videoReady = true;
              _isGenerating = false;
              _progressPercent = 100;

              // Extract the video URL and properly format it
              final String videoUrl = videoData['video_url'];
              // Handle /response-video/ format specifically
              if (videoUrl.startsWith('/response-video/')) {
                _videoUrl = 'https://deeptrump.ai$videoUrl';
                // Log the URL for debugging
                print('Using direct response-video URL: $_videoUrl');
              } else if (videoUrl.startsWith('http')) {
                _videoUrl = videoUrl;
              } else {
                _videoUrl = 'https://www.deeptrump.ai$videoUrl';
              }

              _generatedText =
                  videoData['response_text'] ?? _textController.text;
            });

            // Initialize the video player
            _initializeVideoPlayer(_videoUrl!);

            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Your Trump video is ready!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }

        // Otherwise check progress percentage - direct endpoint instead of query params
        final response = await _dio.get(
          'https://www.deeptrump.ai/api/progress/$sessionId',
          options: Options(
            validateStatus: (status) => true,
          ),
        );

        if (response.statusCode == 200 && response.data is Map) {
          final data = response.data as Map<String, dynamic>;
          if (data.containsKey('percent')) {
            double percent = 0;
            if (data['percent'] is int) {
              percent = data['percent'] / 100;
            } else if (data['percent'] is double) {
              percent = data['percent'] / 100;
            } else if (data['percent'] is String) {
              percent = double.tryParse(data['percent']) ?? 0 / 100;
            }

            // Update progress in UI
            if (mounted) {
              setState(() {
                _progressPercent = percent;
              });
            }

            // Log status if available
            if (data['status'] != null) {
              print('Video status: ${data['status']}');

              // If status is completed, try to get the video URL directly
              if (data['status'] == 'completed') {
                // Try to get the video directly
                final readyResponse = await _dio.get(
                  'https://www.deeptrump.ai/api/is-video-ready',
                  queryParameters: {'session_id': sessionId},
                  options: Options(
                    validateStatus: (status) => true,
                  ),
                );

                if (readyResponse.statusCode == 200 &&
                    readyResponse.data is Map &&
                    readyResponse.data['ready'] == true) {
                  timer.cancel();

                  final videoUrl = readyResponse.data['video_url'];
                  final responseText =
                      readyResponse.data['response_text'] ?? '';

                  if (mounted) {
                    setState(() {
                      _videoReady = true;
                      _isGenerating = false;
                      _progressPercent = 100;

                      // Update URL handling to match the format in the API response
                      if (videoUrl.startsWith('/response-video/')) {
                        _videoUrl = 'https://deeptrump.ai$videoUrl';
                        print(
                            'Using direct response-video URL from ready check: $_videoUrl');
                      } else if (videoUrl.startsWith('http')) {
                        _videoUrl = videoUrl;
                      } else {
                        _videoUrl = 'https://www.deeptrump.ai$videoUrl';
                      }

                      _generatedText = responseText.isNotEmpty
                          ? responseText
                          : _textController.text;
                    });

                    // Initialize the video player
                    _initializeVideoPlayer(_videoUrl!);

                    // Show success message
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Your Trump video is ready!'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        print('Error checking progress: $e');
      }
    });
  }

  // Initialize video player
  Future<void> _initializeVideoPlayer(String videoUrl) async {
    _videoController = VideoPlayerController.network(videoUrl);

    try {
      await _videoController!.initialize();
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
        _videoController!.play();
      }
    } catch (e) {
      print('Error initializing video player: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading video: $e'),
          backgroundColor: Colors.red,
        ),
      );
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

    // Reset video state for new generation
    setState(() {
      _isGenerating = true;
      _videoReady = false;
      _videoUrl = null;
      _generatedText = null;
      _progressPercent = 0;
      _isVideoInitialized = false;
      _videoController?.dispose();
      _videoController = null;
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

      print(
          "DEBUG: About to submit transcript: ${_textController.text.substring(0, _textController.text.length > 20 ? 20 : _textController.text.length)}...");

      // Use the advanced API endpoint with the user-selected fields
      final sessionId = await _apiService.submitTranscriptAdvanced(
        _textController.text,
        targetLang: _selectedLanguage,
        videoChoice: _selectedVideoChoice,
        voiceStyle: _selectedVoiceStyle,
        videoQuality: _selectedVideoQuality,
        videoEffect: _selectedVideoEffect,
      );

      print("DEBUG: Got session ID: $sessionId");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Processing your video. This may take up to a minute...'),
            duration: Duration(seconds: 5),
          ),
        );

        // Start checking progress with the new session ID
        _startProgressChecking(sessionId);
      }
    } catch (e) {
      print("DEBUG: Error in _generateVideo: $e");
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });

        String errorMessage = e.toString();

        // Make error messages more user-friendly
        if (errorMessage.contains('timeout')) {
          errorMessage =
              'The video is taking too long to generate. Please try again with a shorter text.';
        } else if (errorMessage.contains('Network error')) {
          errorMessage =
              'Network connection problem. Please check your internet and try again.';
        } else if (errorMessage.contains('Session ID not found')) {
          errorMessage =
              'Server problem processing your request. Please try again later.';
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
            const Text(
              'What would you like Trump to say?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Text input field
            Expanded(
              flex: 3, // Give more space to the text input
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

            const SizedBox(height: 16),

            // Options section
            Expanded(
              flex: 4,
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _videoReady && _videoUrl != null
                          ? Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Your Trump Video',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: _isVideoInitialized
                                          ? AspectRatio(
                                              aspectRatio: _videoController!
                                                  .value.aspectRatio,
                                              child: VideoPlayer(
                                                  _videoController!),
                                            )
                                          : const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                    ),
                                  ),
                                  if (_generatedText != null) ...[
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Generated Text:',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Expanded(
                                      flex: 1,
                                      child: SingleChildScrollView(
                                        child: Text(_generatedText!),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : Expanded(
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Advanced Options',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    // Language dropdown
                                    _buildDropdown(
                                      label: 'Language',
                                      value: _selectedLanguage,
                                      items: _languages,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedLanguage = value!;
                                        });
                                      },
                                    ),
                                    // Video Style dropdown
                                    _buildDropdown(
                                      label: 'Video Style',
                                      value: _selectedVideoChoice,
                                      items: _videoChoices,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedVideoChoice = value!;
                                        });
                                      },
                                    ),
                                    // Voice Style dropdown
                                    _buildDropdown(
                                      label: 'Voice Style',
                                      value: _selectedVoiceStyle,
                                      items: _voiceStyles,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedVoiceStyle = value!;
                                        });
                                      },
                                    ),
                                    // Video Quality dropdown
                                    _buildDropdown(
                                      label: 'Video Quality',
                                      value: _selectedVideoQuality,
                                      items: _videoQualities,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedVideoQuality = value!;
                                        });
                                      },
                                    ),
                                    // Video Effect dropdown
                                    _buildDropdown(
                                      label: 'Video Effect',
                                      value: _selectedVideoEffect,
                                      items: _videoEffects,
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedVideoEffect = value!;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Generate button with progress indicator
            _isGenerating
                ? Column(
                    children: [
                      // Linear progress indicator
                      LinearProgressIndicator(
                        value: _progressPercent,
                        backgroundColor: Colors.grey.shade300,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.red.shade900),
                        borderRadius: BorderRadius.circular(8),
                        minHeight: 10,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Generating video: ${(_progressPercent * 100).toInt()}%',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade900,
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  )
                : _videoReady
                    ? Row(
                        children: [
                          // Playback control buttons if video is ready
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  if (_videoController!.value.isPlaying) {
                                    _videoController!.pause();
                                  } else {
                                    _videoController!.play();
                                  }
                                });
                              },
                              icon: Icon(
                                _isVideoInitialized &&
                                        _videoController!.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                              ),
                              label: Text(
                                _isVideoInitialized &&
                                        _videoController!.value.isPlaying
                                    ? 'Pause'
                                    : 'Play',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _generateVideo,
                              icon: const Icon(Icons.refresh),
                              label: const Text('New Video'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade900,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ElevatedButton(
                        onPressed: _generateVideo,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade900,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Generate Trump Video',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
          ],
        ),
      ),
      bottomNavigationBar: widget.showBottomNav
          ? BottomNavBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
            )
          : null,
    );
  }

  // Helper method to build consistent dropdowns
  Widget _buildDropdown({
    required String label,
    required String value,
    required Map<String, String> items,
    required void Function(String?) onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                borderRadius: BorderRadius.circular(8),
                items: items.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
