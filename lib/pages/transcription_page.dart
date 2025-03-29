import 'dart:ui';
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_deeptrump/pages/result_page.dart';
import 'package:flutter_deeptrump/pages/widget/transcription_options.dart';

import 'package:flutter_deeptrump/pages/widget/trump_style.dart';
import 'package:flutter_svg/svg.dart';
import 'package:video_player/video_player.dart';
import '../services/trump_api_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class TranscriptionPage extends StatefulWidget {
  TranscriptionPage({super.key});

  @override
  State<TranscriptionPage> createState() => _TranscriptionPageState();
}

class _TranscriptionPageState extends State<TranscriptionPage> {
  String _selectedStyle = "";
  TextEditingController _textController = TextEditingController();
  bool _isGenerating = false;
  double _progressPercent = 0;
  bool _videoReady = false;
  String? _videoUrl;
  String? _generatedText;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  // Variables to track user selections
  String _selectedLanguage = "en";
  String _selectedVideoChoice = "video2";
  String _selectedVoiceStyle = "confident";
  String _selectedVideoQuality = "medium";
  String _selectedVideoEffect = "none";

  // For progress tracking
  Timer? _progressTimer;
  String? _currentSessionId;

  final _apiService = TrumpApiService();
  List<Map<String, dynamic>> _videosList = [];
  bool _isLoadingVideos = false;
  bool _videoListError = false;

  @override
  void initState() {
    super.initState();
    _loadVideosForDrawer();
  }

  @override
  void dispose() {
    _textController.dispose();
    _progressTimer?.cancel();
    _videoController?.dispose();
    super.dispose();
  }

  // Add method to generate video
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

              // Fix for iOS video playback - use HTTPS URL and ensure proper format
              if (videoUrl.contains('response-video')) {
                // Special handling for response-video endpoint with fixed URL format
                final sessionId = RegExp(r'response-video/([^?]+)')
                        .firstMatch(videoUrl)
                        ?.group(1) ??
                    '';
                if (sessionId.isNotEmpty) {
                  _videoUrl =
                      'https://deeptrump.ai/api/response-video/$sessionId';
                } else {
                  _videoUrl = videoUrl;
                }
              } else if (videoUrl.startsWith('http')) {
                _videoUrl = videoUrl;
              } else {
                _videoUrl = 'https://www.deeptrump.ai$videoUrl';
              }

              _generatedText =
                  videoData['response_text'] ?? _textController.text;
            });

            // Download the video first and then navigate to result page
            try {
              print("Video ready, initiating download before navigation");
              final downloadedFilePath = await _downloadVideo(_videoUrl!);

              // Show success message
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Your Trump video is ready!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );

              // Navigate to the result page with proper URL and file path
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResultPage(
                      videoUrl: _videoUrl!,
                      localFilePath: downloadedFilePath,
                      generatedText: _generatedText ?? "",
                    ),
                  ),
                );
              }
            } catch (e) {
              print("Error downloading video: $e");
              // Still navigate but without downloaded file
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error downloading video: $e'),
                    backgroundColor: Colors.orange,
                  ),
                );

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ResultPage(
                      videoUrl: _videoUrl!,
                      generatedText: _generatedText ?? "",
                    ),
                  ),
                );
              }
            }
          }
          return;
        }

        // Otherwise check progress percentage
        final progress = await _apiService.checkVideoProgress(sessionId);

        if (progress != null && mounted) {
          setState(() {
            _progressPercent = progress;
          });
        }
      } catch (e) {
        print('Error checking progress: $e');
      }
    });
  }

  // Add method to download the video file
  Future<String?> _downloadVideo(String videoUrl) async {
    try {
      print("Attempting to download video from URL: $videoUrl");

      // Create a unique filename
      final sessionId =
          RegExp(r'response-video/([^?]+)').firstMatch(videoUrl)?.group(1) ??
              DateTime.now().millisecondsSinceEpoch.toString();
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/trump_video_$sessionId.mp4';

      print("Download destination: $filePath");

      // Check if file already exists
      final file = File(filePath);
      if (await file.exists()) {
        print("File already exists, using cached version");
        return filePath;
      }

      // Download the file with detailed logging
      print("Starting HTTP GET request to: $videoUrl");
      final response = await http.get(
        Uri.parse(videoUrl),
        headers: {
          'Accept': '*/*',
          'User-Agent': 'DeepTrump-App',
        },
      );

      print("HTTP response status code: ${response.statusCode}");
      if (response.statusCode >= 200 && response.statusCode < 300) {
        // Print response headers for debugging
        print("Response headers: ${response.headers}");
        print("Response content length: ${response.contentLength}");

        // Save the file
        await file.writeAsBytes(response.bodyBytes);
        print("File written successfully to: $filePath");

        // Verify file exists and has content
        if (await file.exists()) {
          final fileSize = await file.length();
          print("Verified file exists with size: $fileSize bytes");
          return filePath;
        } else {
          print("Error: File doesn't exist after writing");
          return null;
        }
      } else {
        print("Error downloading video: HTTP ${response.statusCode}");
        print(
            "Response body: ${response.body.substring(0, min(200, response.body.length))}");
        return null;
      }
    } catch (e, stackTrace) {
      print("Exception during video download: $e");
      print("Stack trace: $stackTrace");
      return null;
    }
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

  // Add method to initialize with a file
  Future<void> _initializeVideoPlayerWithFile(String filePath) async {
    _videoController = VideoPlayerController.file(File(filePath));

    try {
      await _videoController!.initialize();
      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
        _videoController!.play();
      }
    } catch (e) {
      print('Error initializing video player from file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Update this method to load all videos with pagination
  Future<void> _loadVideosForDrawer({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _videosList = [];
        _isLoadingVideos = true;
        _videoListError = false;
      });
    } else if (_isLoadingVideos) {
      // Already loading, prevent duplicate calls
      return;
    } else {
      setState(() {
        _isLoadingVideos = true;
        _videoListError = false;
      });
    }

    try {
      // If refreshing, start from page 1, otherwise use the next page
      final currentPage =
          refresh || _videosList.isEmpty ? 1 : (_videosList.length ~/ 10) + 1;
      final videoLibrary = await _apiService.getVideoLibrary(page: currentPage);

      setState(() {
        if (refresh) {
          _videosList = videoLibrary['videos'];
        } else {
          _videosList.addAll(videoLibrary['videos']);
        }
        _isLoadingVideos = false;
      });

      // Check if there are more pages to load
      final pagination = videoLibrary['pagination'] ?? {};
      final totalPages = pagination['total_pages'] ?? 1;
      final currentPageFromAPI = pagination['current_page'] ?? 1;

      // If there are more pages, load them after a short delay
      if (currentPageFromAPI < totalPages && _videosList.length < 20) {
        // Limit to 20 videos total to avoid too much loading
        Future.delayed(const Duration(milliseconds: 500), () {
          _loadVideosForDrawer();
        });
      }
    } catch (e) {
      print("Error loading videos for drawer: $e");
      setState(() {
        _videoListError = true;
        _isLoadingVideos = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leadingWidth:
            MediaQuery.of(context).size.width * 0.1, // Responsive width
        title: SvgPicture.asset(
          'assets/svg/deeptrump.svg',
          width: MediaQuery.of(context).size.width * 0.3, // Responsive width
          height:
              MediaQuery.of(context).size.height * 0.03, // Responsive height
          color: Colors.white,
        ),
        actions: [
          GestureDetector(
            onTap: () {},
            child: Container(
              width: MediaQuery.of(context).size.width * 0.17,
              height: MediaQuery.of(context).size.height * 0.035,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(255, 255, 255, 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color.fromRGBO(255, 255, 255, 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/svg/eagle.svg',
                    width: MediaQuery.of(context).size.width * 0.04,
                    height: MediaQuery.of(context).size.height * 0.02,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Pump',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () {},
            child: Container(
              width: MediaQuery.of(context).size.width * 0.17,
              height: MediaQuery.of(context).size.height * 0.035,
              decoration: BoxDecoration(
                color: const Color.fromRGBO(255, 255, 255, 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color.fromRGBO(255, 255, 255, 0.5),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    'assets/svg/eagle.svg',
                    width: MediaQuery.of(context).size.width * 0.04,
                    height: MediaQuery.of(context).size.height * 0.02,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'DEX',
                    style: TextStyle(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Builder(builder: (context) {
            return GestureDetector(
              onTap: () {
                Scaffold.of(context).openEndDrawer();
              },
              child: Container(
                width: MediaQuery.of(context).size.width * 0.1,
                height: MediaQuery.of(context).size.height * 0.05,
                decoration: const BoxDecoration(
                  color: Color.fromRGBO(11, 2, 28, 1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: SvgPicture.asset(
                    'assets/svg/play_button.svg',
                    width: MediaQuery.of(context).size.width * 0.06,
                    height: MediaQuery.of(context).size.height * 0.03,
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 10),
        ],
      ),
      endDrawer: Drawer(
        backgroundColor: const Color.fromRGBO(11, 2, 28, 1),
        child: Column(
          children: [
            // Drawer header - more compact
            Container(
              height: MediaQuery.of(context).size.height * 0.15,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.fromRGBO(211, 74, 232, 1),
                    Color.fromRGBO(237, 116, 255, 1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Your Trump Videos",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Kodchasan',
                        ),
                      ),
                      Text(
                        "Tap to play or view",
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontFamily: 'Kodchasan',
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () => _loadVideosForDrawer(refresh: true),
                  ),
                ],
              ),
            ),

            // Videos list - expanded to take full available space
            Expanded(
              child: _isLoadingVideos && _videosList.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color.fromRGBO(211, 74, 232, 1),
                        ),
                      ),
                    )
                  : _videoListError
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              const Text(
                                "Could not load videos",
                                style: TextStyle(color: Colors.white),
                              ),
                              TextButton(
                                onPressed: () =>
                                    _loadVideosForDrawer(refresh: true),
                                child: const Text("Try Again"),
                              ),
                            ],
                          ),
                        )
                      : _videosList.isEmpty
                          ? const Center(
                              child: Text(
                                "No videos found",
                                style: TextStyle(color: Colors.white),
                              ),
                            )
                          : Stack(
                              children: [
                                ListView.builder(
                                  itemCount: _videosList.length +
                                      1, // +1 for load more indicator
                                  itemBuilder: (context, index) {
                                    // If we're at the end, show loading or load more button
                                    if (index == _videosList.length) {
                                      return _isLoadingVideos
                                          ? const Center(
                                              child: Padding(
                                                padding: EdgeInsets.all(16.0),
                                                child:
                                                    CircularProgressIndicator(
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(
                                                    Color.fromRGBO(
                                                        211, 74, 232, 1),
                                                  ),
                                                ),
                                              ),
                                            )
                                          : Center(
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.all(16.0),
                                                child: TextButton.icon(
                                                  icon: const Icon(
                                                      Icons.refresh,
                                                      color: Color.fromRGBO(
                                                          211, 74, 232, 1)),
                                                  label: const Text(
                                                    "Load More",
                                                    style: TextStyle(
                                                        color: Color.fromRGBO(
                                                            211, 74, 232, 1)),
                                                  ),
                                                  onPressed:
                                                      _loadVideosForDrawer,
                                                ),
                                              ),
                                            );
                                    }

                                    final video = _videosList[index];
                                    // Get timestamp or use current date as fallback
                                    late final DateTime timestamp;
                                    try {
                                      timestamp = DateTime.parse(
                                          video['timestamp'] ?? '');
                                    } catch (e) {
                                      timestamp = DateTime.now();
                                    }

                                    final formattedDate =
                                        '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';

                                    // Get response text with fallback
                                    final responseText =
                                        video['response_text'] ??
                                            video['text'] ??
                                            'Trump Video';

                                    return Card(
                                      color:
                                          const Color.fromRGBO(30, 20, 50, 1),
                                      margin: const EdgeInsets.symmetric(
                                          vertical: 6, horizontal: 8),
                                      child: ListTile(
                                        title: Text(
                                          responseText.length > 30
                                              ? '${responseText.substring(0, 30)}...'
                                              : responseText,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        subtitle: Text(
                                          'Created: $formattedDate',
                                          style: TextStyle(
                                            color: Colors.grey[400],
                                            fontSize: 12,
                                          ),
                                        ),
                                        trailing: const Icon(
                                          Icons.play_circle_outline,
                                          color:
                                              Color.fromRGBO(211, 74, 232, 1),
                                        ),
                                        onTap: () {
                                          // Close the drawer
                                          Navigator.pop(context);

                                          // Extract session ID from various possible fields
                                          String sessionId =
                                              video['session_id'] ??
                                                  video['id'] ??
                                                  '';

                                          // If there's no session ID but there's a video_url, extract it from there
                                          if (sessionId.isEmpty &&
                                              video['video_url'] != null) {
                                            final videoUrl = video['video_url'];
                                            final match = RegExp(
                                                    r'response-video/([^?]+)')
                                                .firstMatch(videoUrl);
                                            if (match != null &&
                                                match.groupCount >= 1) {
                                              sessionId = match.group(1) ?? '';
                                            }
                                          }

                                          if (sessionId.isNotEmpty) {
                                            final videoUrl =
                                                'https://deeptrump.ai/api/response-video/$sessionId';
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ResultPage(
                                                  videoUrl: videoUrl,
                                                  generatedText: responseText,
                                                ),
                                              ),
                                            );
                                          } else {
                                            // Show error if session ID couldn't be found
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'Could not play this video (missing ID)'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        },
                                      ),
                                    );
                                  },
                                ),
                                // Show small loading indicator at top when refreshing
                                if (_isLoadingVideos && _videosList.isNotEmpty)
                                  const Positioned(
                                    top: 0,
                                    left: 0,
                                    right: 0,
                                    child: LinearProgressIndicator(
                                      backgroundColor: Colors.transparent,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color.fromRGBO(211, 74, 232, 1),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
            ),
          ],
        ),
      ),
      body: Container(
        color: const Color.fromRGBO(11, 2, 28, 1),
        child: Stack(
          children: [
            // Background elements
            Positioned.fill(
              child: SvgPicture.asset(
                'assets/svg/Bg_color.svg',
                fit: BoxFit.cover,
              ),
            ),
            Positioned.fill(
              child: SvgPicture.asset(
                'assets/svg/Bg_grid.svg',
                fit: BoxFit.cover,
              ),
            ),
            // Glow effect
            Positioned(
              top: -MediaQuery.of(context).size.height * 0.2,
              left: 0,
              right: 0,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                    sigmaX: MediaQuery.of(context).size.width * 0.3,
                    sigmaY: MediaQuery.of(context).size.width * 0.3),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8,
                  height: MediaQuery.of(context).size.width * 0.8,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Color.fromARGB(60, 89, 39, 98),
                        Color.fromARGB(119, 89, 39, 98),
                        Color.fromARGB(99, 224, 143, 238),
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

            // Content area - now inside the Stack for proper layering
            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Spacer for top padding to push content below app bar
                    SizedBox(height: MediaQuery.of(context).size.height * 0.1),

                    // Trump image and text
                    Image.asset(
                      'assets/svg/trump.png',
                      width: MediaQuery.of(context).size.width * 0.6,
                      height: MediaQuery.of(context).size.width * 0.35,
                    ),


                    SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                    RichText(
                      text: TextSpan(
                        children: [
                          const TextSpan(
                            text: 'Make Trump Say',
                            style: TextStyle(
                              fontSize: 18,
                              fontFamily: 'Kodchasan',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextSpan(
                            text: ' What You Think',
                            style: TextStyle(
                              foreground: Paint()
                                ..shader = const LinearGradient(
                                  colors: [
                                    Color.fromARGB(255, 211, 74, 232),
                                    Color.fromARGB(255, 237, 116, 255),
                                    Color.fromARGB(255, 240, 138, 255),
                                    Color.fromARGB(255, 232, 81, 255),
                                    Color.fromARGB(255, 211, 74, 232),
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ).createShader(
                                    const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
                              fontFamily: 'Kodchasan',
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    const Text(
                      'Type your script, and watch AI Trump bring your ideas to life - fun, engaging, and shareable!',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Kodchasan',
                        fontWeight: FontWeight.w400,
                        color: Color.fromRGBO(255, 255, 255, 1),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.1),
                    // Trump style selector
                    TrumpStyleSelector(
                      selectedStyle: _selectedStyle,
                      onStyleSelected: (style) {
                        setState(() {
                          _selectedStyle = style;
                        });
                      },
                    ),
                    SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    // Text input container
                    Container(
                      width: MediaQuery.of(context).size.width,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 20),
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(11, 2, 28, 1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(36),
                          topRight: Radius.circular(36),
                        ),
                        border: Border.all(
                          color: const Color.fromRGBO(255, 255, 255, 0.1),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 150, // Fixed height for text field
                            child: TextField(
                              controller: _textController,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText:
                                    'Enter your script and create your vision......',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  fontFamily: 'Kodchasan',
                                  fontWeight: FontWeight.w400,
                                  color: Color.fromRGBO(255, 255, 255, 0.5),
                                ),
                              ),
                              maxLines: null,
                              expands: true,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              TranscriptionOptions(
                                onLanguageChanged: (language) {
                                  setState(() {
                                    _selectedLanguage = language;
                                  });
                                  print("Selected language: $language");
                                },
                                onVideoStyleChanged: (videoStyle) {
                                  setState(() {
                                    _selectedVideoChoice = videoStyle;
                                  });
                                  print("Selected video style: $videoStyle");
                                },
                                onVoiceStyleChanged: (voiceStyle) {
                                  setState(() {
                                    _selectedVoiceStyle = voiceStyle;
                                  });
                                  print("Selected voice style: $voiceStyle");
                                },
                                onQualityChanged: (quality) {
                                  setState(() {
                                    _selectedVideoQuality = quality;
                                  });
                                  print("Selected quality: $quality");
                                },
                                onEffectChanged: (effect) {
                                  setState(() {
                                    _selectedVideoEffect = effect;
                                  });
                                  print("Selected effect: $effect");
                                },
                              ),
                              const Spacer(),
                              _isGenerating
                                  ? SizedBox(
                                      width: MediaQuery.of(context).size.width *
                                          0.6,
                                      child: Column(
                                        children: [
                                          LinearProgressIndicator(
                                            value: _progressPercent,
                                            backgroundColor:
                                                Colors.grey.shade300,
                                            valueColor:
                                                const AlwaysStoppedAnimation<
                                                        Color>(
                                                    Color.fromRGBO(
                                                        211, 74, 232, 1)),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            minHeight: 8,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'Generating: ${(_progressPercent * 100).toInt()}%',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : GestureDetector(
                                      onTap: _generateVideo,
                                      child: Container(
                                        width:
                                            MediaQuery.of(context).size.width *
                                                0.1,
                                        height:
                                            MediaQuery.of(context).size.width *
                                                0.1,
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              Color.fromRGBO(211, 74, 232, 1),
                                              Color.fromRGBO(222, 92, 242, 1),
                                              Color.fromRGBO(237, 116, 255, 1),
                                            ],
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: SvgPicture.asset(
                                            'assets/svg/stars.svg',
                                            width: 16,
                                            height: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                            ],
                          ),
                          // Add padding at the bottom to ensure space for keyboard
                          // SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      resizeToAvoidBottomInset: true,
    );
  }
}
