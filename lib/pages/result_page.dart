import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_svg/svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:permission_handler/permission_handler.dart';

class ResultPage extends StatefulWidget {
  final String videoUrl;
  final String? localFilePath;
  final String generatedText;

  const ResultPage({
    Key? key,
    required this.videoUrl,
    this.localFilePath,
    required this.generatedText,
  }) : super(key: key);

  @override
  State<ResultPage> createState() => _ResultPageState();
}

class _ResultPageState extends State<ResultPage> {
  late VideoPlayerController _videoController;
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _prepareVideo();
  }

  Future<void> _prepareVideo() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // First try to use the local file path if provided
      if (widget.localFilePath != null) {
        final file = File(widget.localFilePath!);
        if (await file.exists()) {
          print("Using provided local file: ${widget.localFilePath}");
          await _initializeVideoPlayerWithFile(widget.localFilePath!);
          return;
        } else {
          print("Provided local file doesn't exist: ${widget.localFilePath}");
        }
      }

      // If no local file or it doesn't exist, try to download
      print("No valid local file, attempting download");
      final filePath = await _downloadVideo(widget.videoUrl);
      if (filePath != null) {
        // Use the local file if download successful
        await _initializeVideoPlayerWithFile(filePath);
      } else {
        // Fall back to network streaming if download fails
        print("Download failed, falling back to network streaming");
        await _initializeVideoPlayer(widget.videoUrl);
      }
    } catch (e) {
      print('Error preparing video: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error preparing video: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Download video to local storage
  Future<String?> _downloadVideo(String videoUrl) async {
    try {
      // Create a unique filename
      final sessionId =
          RegExp(r'response-video/([^?]+)').firstMatch(videoUrl)?.group(1) ??
              DateTime.now().millisecondsSinceEpoch.toString();
      final directory = await getTemporaryDirectory();
      final filePath = '${directory.path}/trump_video_$sessionId.mp4';

      // Check if file already exists
      final file = File(filePath);
      if (await file.exists()) {
        print('Using existing downloaded file: $filePath');
        return filePath;
      }

      print('Downloading video from: $videoUrl');
      // Download the file
      final response = await http.get(Uri.parse(videoUrl));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        print('Video downloaded successfully to: $filePath');
        return filePath;
      } else {
        print('Error downloading video: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('Error downloading video: $e');
      return null;
    }
  }

  Future<void> _initializeVideoPlayerWithFile(String filePath) async {
    _videoController = VideoPlayerController.file(File(filePath));

    try {
      await _videoController.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = true;
        });
        _videoController.play();

        // Add listener to update play state
        _videoController.addListener(() {
          final isPlaying = _videoController.value.isPlaying;
          if (isPlaying != _isPlaying && mounted) {
            setState(() {
              _isPlaying = isPlaying;
            });
          }
        });
      }
    } catch (e) {
      print('Error initializing video player from file: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _initializeVideoPlayer(String videoUrl) async {
    _videoController = VideoPlayerController.network(videoUrl);

    try {
      await _videoController.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isPlaying = true;
        });
        _videoController.play();

        // Add listener to update play state
        _videoController.addListener(() {
          final isPlaying = _videoController.value.isPlaying;
          if (isPlaying != _isPlaying && mounted) {
            setState(() {
              _isPlaying = isPlaying;
            });
          }
        });
      }
    } catch (e) {
      print('Error initializing video player: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  Future<void> _saveVideoToGallery() async {
    try {
      // Request permissions based on Android version
      if (Platform.isAndroid) {
        // For Android 13 and above (API level 33+)
        if (await Permission.photos.request().isDenied &&
            await Permission.videos.request().isDenied &&
            await Permission.storage.request().isDenied) {
          // Show settings dialog if permission permanently denied
          if (await Permission.storage.isPermanentlyDenied ||
              await Permission.photos.isPermanentlyDenied ||
              await Permission.videos.isPermanentlyDenied) {
            // Show dialog to open settings
            final shouldOpenSettings = await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Permission Required'),
                content: const Text(
                    'Storage permission is required to save videos. Please enable it in settings.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Open Settings'),
                  ),
                ],
              ),
            );

            if (shouldOpenSettings == true) {
              await openAppSettings();
            }
          }
          throw Exception("Storage permission is required to save videos");
        }
      } else if (Platform.isIOS) {
        if (await Permission.photos.request().isDenied) {
          throw Exception("Photos permission is required to save videos");
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preparing video for gallery...'),
          backgroundColor: Color.fromRGBO(211, 74, 232, 1),
        ),
      );

      // Either use the existing local file or download it
      String? filePath = widget.localFilePath;
      if (filePath == null || !await File(filePath).exists()) {
        filePath = await _downloadVideo(widget.videoUrl);
        if (filePath == null) {
          throw Exception("Failed to download video");
        }
      }

      // Save to gallery using image_gallery_saver
      final result = await ImageGallerySaver.saveFile(
        filePath,
        name: "Trump_Video_${DateTime.now().millisecondsSinceEpoch}",
      );

      if (result['isSuccess'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video saved to gallery successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception(
            "Failed to save video to gallery: ${result['errorMessage']}");
      }
    } catch (e) {
      print("Error saving video to gallery: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving to gallery: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromRGBO(11, 2, 28, 1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: SvgPicture.asset(
          'assets/svg/deeptrump.svg',
          width: MediaQuery.of(context).size.width * 0.3,
          height: MediaQuery.of(context).size.height * 0.03,
          color: Colors.white,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Your Trump Video',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Kodchasan',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // Video Player
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color.fromRGBO(255, 255, 255, 0.1),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _isInitialized
                      ? AspectRatio(
                          aspectRatio: _videoController.value.aspectRatio,
                          child: VideoPlayer(_videoController),
                        )
                      : Center(
                          child: _isLoading
                              ? Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(
                                      color: Color.fromRGBO(211, 74, 232, 1),
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Preparing video...',
                                      style: TextStyle(color: Colors.white),
                                    )
                                  ],
                                )
                              : Text(
                                  'Failed to load video',
                                  style: TextStyle(color: Colors.white),
                                ),
                        ),
                ),
              ),

              // Video Controls
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Play/Pause button
                  IconButton(
                    icon: Icon(
                      _isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: Colors.white,
                      size: 40,
                    ),
                    onPressed: () {
                      if (_isInitialized) {
                        setState(() {
                          if (_isPlaying) {
                            _videoController.pause();
                          } else {
                            _videoController.play();
                          }
                          _isPlaying = !_isPlaying;
                        });
                      }
                    },
                  ),

                  // Replay button
                  IconButton(
                    icon: const Icon(
                      Icons.replay,
                      color: Colors.white,
                      size: 36,
                    ),
                    onPressed: () {
                      if (_isInitialized) {
                        _videoController.seekTo(Duration.zero);
                        _videoController.play();
                        setState(() {
                          _isPlaying = true;
                        });
                      }
                    },
                  ),

                  // Download button (you can implement actual download functionality later)
                  IconButton(
                    icon: const Icon(
                      Icons.download,
                      color: Colors.white,
                      size: 36,
                    ),
                    onPressed: _saveVideoToGallery,
                  ),
                ],
              ),

              // Transcript Display
              const SizedBox(height: 24),
              const Text(
                'Transcript',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Kodchasan',
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(30, 20, 50, 1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color.fromRGBO(255, 255, 255, 0.1),
                    width: 1,
                  ),
                ),
                child: Text(
                  widget.generatedText,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontFamily: 'Kodchasan',
                  ),
                ),
              ),

              // Create New Button
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: const Color.fromRGBO(211, 74, 232, 1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Create Another Video',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Kodchasan',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
