import 'package:flutter/material.dart';
import '../bottom_nav_bar.dart';
import '../services/trump_api_service.dart';
import 'package:video_player/video_player.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';


class VideosPage extends StatefulWidget {
  final bool showBottomNav;

  const VideosPage({
    super.key,
    this.showBottomNav = true,
  });

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> {
  int _selectedIndex = 1; // Videos tab is selected by default
  final _apiService = TrumpApiService();

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _videos = [];
  int _currentPage = 1;
  int _totalPages = 1;

  // Track currently playing video
  VideoPlayerController? _activeVideoController;
  int? _activeVideoIndex;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  @override
  void dispose() {
    _activeVideoController?.dispose();
    super.dispose();
  }

  Future<void> _loadVideos({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final videoLibrary =
          await _apiService.getVideoLibrary(page: _currentPage);

      setState(() {
        if (refresh || _currentPage == 1) {
          _videos = videoLibrary['videos'];
        } else {
          _videos.addAll(videoLibrary['videos']);
        }

        _totalPages = videoLibrary['pagination']['total_pages'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to load videos: $e';
        _isLoading = false;
      });
    }
  }

  void _loadMoreVideos() {
    if (_currentPage < _totalPages) {
      setState(() {
        _currentPage++;
        _isLoading = true;
      });
      _loadVideos();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Add navigation logic here as needed
  }

  Future<void> _playVideo(int index, String sessionId) async {
    // If same video is tapped again, toggle play/pause
    if (_activeVideoIndex == index && _isVideoInitialized) {
      if (_activeVideoController!.value.isPlaying) {
        _activeVideoController!.pause();
      } else {
        _activeVideoController!.play();
      }
      setState(() {});
      return;
    }

    // Dispose previous controller if there was one
    _activeVideoController?.dispose();

    // Initialize new controller
    setState(() {
      _activeVideoIndex = index;
      _isVideoInitialized = false;
    });

    try {
      final videoUrl = 'https://deeptrump.ai/api/response-video/$sessionId';
      _activeVideoController = VideoPlayerController.network(videoUrl);

      await _activeVideoController!.initialize();
      _activeVideoController!.addListener(_videoListener);

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
        _activeVideoController!.play();
      }
    } catch (e) {
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

  void _videoListener() {
    // This forces a rebuild when the video state changes
    if (mounted) setState(() {});
  }

  Future<void> _downloadVideo(String url, String fileName) async {
    try {
      // Request permissions based on Android version
      bool permissionGranted = false;

      if (Platform.isAndroid) {
        // Request all necessary permissions
        final storagePermission = await Permission.storage.request();
        final photosPermission = await Permission.photos.request();
        final videosPermission = await Permission.videos.request();

        if (storagePermission.isGranted ||
            photosPermission.isGranted ||
            videosPermission.isGranted) {
          permissionGranted = true;
        } else {
          // Show settings dialog if permission permanently denied
          if (await Permission.storage.isPermanentlyDenied ||
              await Permission.photos.isPermanentlyDenied ||
              await Permission.videos.isPermanentlyDenied) {
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
              return;
            }
          }
        }
      } else if (Platform.isIOS) {
        if (await Permission.photos.request().isGranted) {
          permissionGranted = true;
        }
      }

      if (!permissionGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission denied. Cannot save video.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show download starting notification
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Starting download...')),
      );

      // Download video to temporary file first
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/$fileName';

      // Download the file
      await Dio().download(
        url,
        tempPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            // Update download progress
            final progress = (received / total * 100).toStringAsFixed(0);
            if (int.parse(progress) % 20 == 0) {
              // Show progress at 20% increments
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Downloading: $progress%')),
              );
            }
          }
        },
      );

      // Save to gallery using image_gallery_saver
      final result = await ImageGallerySaver.saveFile(
        tempPath,
        name: "Trump_Video_${DateTime.now().millisecondsSinceEpoch}",
      );

      // Show result
      if (result['isSuccess'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video saved to gallery successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        throw Exception("Failed to save to gallery: ${result['errorMessage']}");
      }
    } catch (e) {
      print("Error downloading or saving video: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trump Videos'),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _loadVideos(refresh: true),
          ),
        ],
      ),
      body: _hasError
          ? _buildErrorView()
          : RefreshIndicator(
              onRefresh: () => _loadVideos(refresh: true),
              child: _buildVideoList(),
            ),
      bottomNavigationBar: widget.showBottomNav
          ? BottomNavBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
            )
          : null,
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _loadVideos(refresh: true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade900,
              foregroundColor: Colors.white,
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoList() {
    if (_isLoading && _videos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _videos.length + (_currentPage < _totalPages ? 1 : 0),
      itemBuilder: (context, index) {
        // Load more indicator at the end
        if (index == _videos.length) {
          _loadMoreVideos();
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final video = _videos[index];
        final timestamp = DateTime.parse(video['timestamp']);
        final formattedDate =
            '${timestamp.year}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';

        final bool isActive = _activeVideoIndex == index;

        return Stack(children: [
          Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              children: [
                // Video container
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isActive && _isVideoInitialized)
                          AspectRatio(
                            aspectRatio:
                                _activeVideoController!.value.aspectRatio,
                            child: VideoPlayer(_activeVideoController!),
                          )
                        else
                          Container(
                            color: Colors.grey.shade300,
                            child: Center(
                              child: isActive && !_isVideoInitialized
                                  ? const CircularProgressIndicator()
                                  : Icon(
                                      Icons.play_circle_fill,
                                      size: 48,
                                      color: Colors.red.shade900,
                                    ),
                            ),
                          ),
                        // Play/pause button overlay
                        if (isActive && _isVideoInitialized)
                          GestureDetector(
                            onTap: () {
                              if (_activeVideoController!.value.isPlaying) {
                                _activeVideoController!.pause();
                              } else {
                                _activeVideoController!.play();
                              }
                              setState(() {});
                            },
                            child: Container(
                              color: Colors.transparent,
                              child: Center(
                                child: Icon(
                                  _activeVideoController!.value.isPlaying
                                      ? Icons.pause_circle_outline
                                      : Icons.play_circle_outline,
                                  size: 60,
                                  color: Colors.white.withOpacity(0.7),
                                ),
                              ),
                            ),
                          )
                        else
                          // Play button for inactive videos
                          GestureDetector(
                            onTap: () => _playVideo(index, video['session_id']),
                            child: Container(
                              color: Colors.transparent,
                              child: Center(
                                child: Icon(
                                  Icons.play_circle_fill,
                                  size: 48,
                                  color: Colors.red.shade900,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Video controls (only for active video)
                if (isActive && _isVideoInitialized)
                  Column(
                    children: [
                      // Progress bar
                      SizedBox(
                        height: 10,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                            trackHeight: 4,
                            trackShape: const RoundedRectSliderTrackShape(),
                            activeTrackColor: Colors.red.shade900,
                            inactiveTrackColor: Colors.grey.shade300,
                            thumbColor: Colors.red.shade900,
                            overlayColor: Colors.red.withOpacity(0.2),
                          ),
                          child: Slider(
                            value: _activeVideoController!
                                .value.position.inMilliseconds
                                .toDouble(),
                            min: 0,
                            max: _activeVideoController!
                                .value.duration.inMilliseconds
                                .toDouble(),
                            onChanged: (value) {
                              _activeVideoController!.seekTo(
                                  Duration(milliseconds: value.toInt()));
                            },
                          ),
                        ),
                      ),

                      // Time display and additional controls
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(
                                  _activeVideoController!.value.position),
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            Row(
                              children: [
                                // IconButton(
                                //   icon: const Icon(Icons.replay_10, size: 24),
                                //   onPressed: () {
                                //     final newPosition =
                                //         _activeVideoController!.value.position -
                                //             const Duration(seconds: 10);
                                //     _activeVideoController!.seekTo(newPosition);
                                //   },
                                // ),
                                // IconButton(
                                //   icon: const Icon(Icons.forward_10, size: 24),
                                //   onPressed: () {
                                //     final newPosition =
                                //         _activeVideoController!.value.position +
                                //             const Duration(seconds: 10);
                                //     _activeVideoController!.seekTo(newPosition);
                                //   },
                                // ),
                                // IconButton(
                                //   icon: const Icon(Icons.download, size: 24),
                                //   onPressed: () {
                                //     final videoData = _videos[_activeVideoIndex!];
                                //     final sessionId = videoData['session_id'] ??
                                //         videoData['id'] ??
                                //         'video';
                                //     final videoUrl =
                                //         'https://deeptrump.ai/api/response-video/$sessionId';
                                //     _downloadVideo(
                                //         videoUrl, 'trump_video_$sessionId.mp4');
                                //   },
                                // ),
                              ],
                            ),
                            Text(
                              _formatDuration(
                                  _activeVideoController!.value.duration),
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                // Video details
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video['response_text'].length > 50
                            ? '${video['response_text'].substring(0, 50)}...'
                            : video['response_text'],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Generated on $formattedDate',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Full transcript:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          video['response_text'],
                          style: TextStyle(
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.download, color: Colors.white, size: 24),
            onPressed: () {
              final videoData = _videos[_activeVideoIndex!];
              final sessionId =
                  videoData['session_id'] ?? videoData['id'] ?? 'video';
              final videoUrl =
                  'https://deeptrump.ai/api/response-video/$sessionId';
              _downloadVideo(videoUrl, 'trump_video_$sessionId.mp4');
            },
          ),
        ]);
      },
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }
}
