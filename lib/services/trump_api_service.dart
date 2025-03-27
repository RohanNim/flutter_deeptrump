import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'dart:math' show min;

class TrumpApiService {
  final _logger = Logger('TrumpApiService');
  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://www.deeptrump.ai',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Accept': 'application/json',
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
      'Origin': 'https://www.deeptrump.ai',
      'Referer': 'https://www.deeptrump.ai/generate',
    },
  ));

  TrumpApiService() {
    // Setup logging
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      debugPrint('${record.level.name}: ${record.time}: ${record.message}');
    });
  }

  /// Submits a transcript to generate a Trump video
  /// Returns a session ID that can be used to check the video status
  Future<String> submitTranscript(String transcript) async {
    _logger.info(
        'Submitting transcript: ${transcript.substring(0, transcript.length > 30 ? 30 : transcript.length)}...');

    try {
      // Create an exactly matching browser-like request to mimic web browser
      final browserDio = Dio(BaseOptions(
        baseUrl: 'https://www.deeptrump.ai',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Accept': '*/*',
          'Accept-Language': 'en-US,en;q=0.9',
          'Origin': 'https://www.deeptrump.ai',
          'Referer': 'https://www.deeptrump.ai/generate',
          'Content-Type':
              'application/json', // Important: Use JSON as in transcript.dart
        },
      ));

      // Use a simpler approach similar to the working code in transcript.dart
      _logger.info('Using direct /generate endpoint approach');

      // Use the exact same payload format as in transcript.dart
      final payload = {'text': transcript};

      final response = await browserDio.post(
        '/generate',
        data: payload, // Send as raw JSON, not form data
        options: Options(
          validateStatus: (status) => true,
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      _logger.info('Response status code: ${response.statusCode}');
      _logger.info('Response data type: ${response.data.runtimeType}');

      // Try to extract session ID or video URL directly
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        // If the response contains direct video URL (as in transcript.dart example)
        if (response.data is Map && response.data['video_url'] != null) {
          _logger.info('Got direct video URL, creating synthetic session ID');
          // Create a synthetic session ID to track this request
          final syntheticId = 'direct-${DateTime.now().millisecondsSinceEpoch}';

          // Store the video URL for later retrieval
          _directVideoUrls[syntheticId] = response.data['video_url'];
          return syntheticId;
        }

        // If response is a map and contains session_id
        if (response.data is Map && response.data['session_id'] != null) {
          _logger.info(
              'Got session ID from response: ${response.data['session_id']}');
          return response.data['session_id'];
        }

        // Handle string response (could be JSON or HTML)
        if (response.data is String) {
          _logger.info('Response is a string, looking for session ID');
          String responseStr = response.data as String;

          // Try parsing as JSON first
          try {
            final jsonData = jsonDecode(responseStr);
            if (jsonData is Map && jsonData['session_id'] != null) {
              _logger.info(
                  'Parsed JSON has session ID: ${jsonData['session_id']}');
              return jsonData['session_id'];
            }
          } catch (e) {
            _logger.warning('Failed to parse response as JSON: $e');
          }

          // Try looking for session ID in the string
          final sessionIdMatch =
              RegExp(r'"session_id":"([^"]+)"').firstMatch(responseStr);
          if (sessionIdMatch != null && sessionIdMatch.groupCount >= 1) {
            _logger
                .info('Found session ID in string: ${sessionIdMatch.group(1)}');
            return sessionIdMatch.group(1)!;
          }
        }
      }

      // Simplified fallback to root endpoint using form-data
      _logger.info('Trying direct form-data approach to root endpoint');

      final formDataResponse = await browserDio.post(
        '/',
        data: FormData.fromMap({'transcript': transcript}),
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          validateStatus: (status) => true,
        ),
      );

      _logger.info('Form data response status: ${formDataResponse.statusCode}');

      // Check for session ID in form data response
      if (formDataResponse.statusCode != null &&
          formDataResponse.statusCode! >= 200 &&
          formDataResponse.statusCode! < 300) {
        if (formDataResponse.data is Map &&
            formDataResponse.data['session_id'] != null) {
          return formDataResponse.data['session_id'];
        } else if (formDataResponse.data is String) {
          // Look for session ID in string
          final match = RegExp(r'"session_id":"([^"]+)"')
              .firstMatch(formDataResponse.data as String);
          if (match != null && match.groupCount >= 1) {
            return match.group(1)!;
          }
        }
      }

      // If all attempts fail, throw a more user-friendly error
      _logger
          .severe('Failed to submit transcript - website might have changed');
      throw Exception(
          'DeepTrump.ai website seems to have updated their system. Please try again later.');
    } on DioException catch (e) {
      _logger.severe('Network error: ${e.message}');
      final errorDetails = e.response != null
          ? 'Status: ${e.response?.statusCode}, Data: ${e.response?.data}'
          : e.message;
      _logger.severe('Error details: $errorDetails');
      throw Exception(
          'Network connection problem. Please check your internet connection and try again.');
    } catch (e) {
      _logger.severe('Error: $e');
      throw Exception('Failed to submit transcript: $e');
    }
  }

  /// Submits a transcript to generate a Trump video with advanced parameters
  /// Returns a session ID that can be used to check the video status
  Future<String> submitTranscriptAdvanced(
    String transcript, {
    String targetLang = "en",
    String videoChoice = "video2",
    String voiceStyle = "confident",
    String videoQuality = "medium",
    String videoEffect = "none",
  }) async {
    _logger.info(
        'Submitting advanced transcript: ${transcript.substring(0, transcript.length > 30 ? 30 : transcript.length)}...');

    try {
      // Create an exactly matching browser-like request to mimic web browser
      final browserDio = Dio(BaseOptions(
        baseUrl: 'https://www.deeptrump.ai',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
          'Accept': '*/*',
          'Accept-Language': 'en-US,en;q=0.9',
          'Origin': 'https://www.deeptrump.ai',
          'Referer': 'https://www.deeptrump.ai/generate',
        },
      ));

      _logger.info('Using advanced API endpoint with form data');

      // Create FormData with all the parameters from the curl command
      final formData = FormData.fromMap({
        'transcript': transcript,
        'target_lang': targetLang,
        'video_choice': videoChoice,
        'voice_style': voiceStyle,
        'video_quality': videoQuality,
        'video_effect': videoEffect,
      });

      final response = await browserDio.post(
        '/api/',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          validateStatus: (status) => true,
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      _logger.info('Response status code: ${response.statusCode}');
      _logger.info('Response data type: ${response.data.runtimeType}');

      // Try to extract session ID or video URL directly
      if (response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300) {
        // First, handle the specific response format you showed
        if (response.data is Map) {
          final responseData = response.data as Map<String, dynamic>;

          // Check for the exact response format you provided
          if (responseData['success'] == true &&
              responseData['session_id'] != null) {
            _logger.info(
                'Got session ID from success response: ${responseData['session_id']}');

            // Log queue position if available
            if (responseData['queue_position'] != null) {
              _logger.info('Queue position: ${responseData['queue_position']}');
            }

            return responseData['session_id'];
          }
        }

        // Then continue with the existing extraction logic for other response formats
        // Extract session ID using the same approach as in submitTranscript
        if (response.data is Map && response.data['video_url'] != null) {
          _logger.info('Got direct video URL, creating synthetic session ID');
          final syntheticId = 'direct-${DateTime.now().millisecondsSinceEpoch}';
          _directVideoUrls[syntheticId] = response.data['video_url'];
          return syntheticId;
        }

        if (response.data is Map && response.data['session_id'] != null) {
          _logger.info(
              'Got session ID from response: ${response.data['session_id']}');
          return response.data['session_id'];
        }

        if (response.data is String) {
          _logger.info('Response is a string, looking for session ID');
          String responseStr = response.data as String;

          try {
            final jsonData = jsonDecode(responseStr);
            if (jsonData is Map && jsonData['session_id'] != null) {
              return jsonData['session_id'];
            }
          } catch (e) {
            _logger.warning('Failed to parse response as JSON: $e');
          }

          final sessionIdMatch =
              RegExp(r'"session_id":"([^"]+)"').firstMatch(responseStr);
          if (sessionIdMatch != null && sessionIdMatch.groupCount >= 1) {
            return sessionIdMatch.group(1)!;
          }
        }
      }

      _logger
          .severe('Failed to submit transcript - website might have changed');
      throw Exception(
          'DeepTrump.ai website seems to have updated their system. Please try again later.');
    } on DioException catch (e) {
      _logger.severe('Network error: ${e.message}');
      final errorDetails = e.response != null
          ? 'Status: ${e.response?.statusCode}, Data: ${e.response?.data}'
          : e.message;
      _logger.severe('Error details: $errorDetails');
      throw Exception(
          'Network connection problem. Please check your internet connection and try again.');
    } catch (e) {
      _logger.severe('Error: $e');
      throw Exception('Failed to submit transcript: $e');
    }
  }

  // Track video URLs for direct responses
  final Map<String, String> _directVideoUrls = {};

  /// Checks if a video is ready using the session ID
  /// Returns the video details if ready, null otherwise
  Future<Map<String, dynamic>?> checkVideoStatus(String sessionId) async {
    // Handle direct video URLs
    if (sessionId.startsWith('direct-') &&
        _directVideoUrls.containsKey(sessionId)) {
      _logger.info('Using direct video URL for session: $sessionId');
      final videoUrl = _directVideoUrls[sessionId]!;
      final _videoUrl = videoUrl.startsWith('http')
          ? videoUrl
          : 'https://www.deeptrump.ai$videoUrl';
      return {
        'ready': true,
        'video_url': _videoUrl,
        'session_id': sessionId,
        'response_text': '', // No response text available for direct URLs
      };
    }

    // Otherwise use the regular status check
    _logger.info('Checking video status for session: $sessionId');

    try {
      // First try the direct progress endpoint - this seems more reliable
      final progressResponse = await _dio.get(
        '/api/progress/$sessionId',
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      _logger.info(
          'Progress endpoint check - Status code: ${progressResponse.statusCode}');

      if (progressResponse.statusCode == 200 && progressResponse.data is Map) {
        final progressData = progressResponse.data as Map<String, dynamic>;

        // If status is "completed", check the video-ready endpoint
        if (progressData['status'] == 'completed') {
          final videoReadyResponse = await _dio.get(
            '/api/is-video-ready', // Updated to use /api/ path prefix
            queryParameters: {'session_id': sessionId},
            options: Options(
              validateStatus: (status) => true,
            ),
          );

          _logger.info(
              'Video-ready check - Status code: ${videoReadyResponse.statusCode}');

          if (videoReadyResponse.statusCode == 200 &&
              videoReadyResponse.data is Map) {
            final videoData = videoReadyResponse.data as Map<String, dynamic>;

            if (videoData['ready'] == true && videoData['video_url'] != null) {
              final String videoUrl = videoData['video_url'];
              final _videoUrl = videoUrl.startsWith('http')
                  ? videoUrl
                  : 'https://www.deeptrump.ai$videoUrl';

              return {
                'ready': true,
                'video_url': _videoUrl,
                'session_id': videoData['session_id'] ?? sessionId,
                'response_text': videoData['response_text'] ?? '',
                'percent': videoData['percent'] ?? 100,
                'progress_status': videoData['progress_status'] ?? 'Completed',
              };
            }
          }
        }
      }

      // Try the direct video-ready endpoint as a fallback
      final videoResponse = await _dio.get(
        '/api/is-video-ready',
        queryParameters: {'session_id': sessionId},
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      _logger.info(
          'Direct video-ready check - Status code: ${videoResponse.statusCode}');

      if (videoResponse.data is String &&
          (videoResponse.data.toString().contains('<!DOCTYPE') ||
              videoResponse.data.toString().contains('<html'))) {
        _logger.warning('Status endpoint returned HTML instead of JSON');
        return null;
      }

      if (videoResponse.statusCode == 200) {
        Map<String, dynamic> videoData;

        if (videoResponse.data is Map) {
          videoData = videoResponse.data as Map<String, dynamic>;
        } else if (videoResponse.data is String) {
          try {
            videoData = jsonDecode(videoResponse.data);
          } catch (e) {
            _logger.severe('Failed to parse response as JSON: $e');
            return null;
          }
        } else {
          _logger.warning(
              'Unexpected response type: ${videoResponse.data.runtimeType}');
          return null;
        }

        // Check for video ready based on the updated API response format
        if (videoData['ready'] == true && videoData['video_url'] != null) {
          // Format the video URL if it's a relative path
          final String videoUrl = videoData['video_url'];

          // Fix URL construction to ensure it works with both relative and absolute paths
          // And handle the special /response-video/ endpoint format
          String _videoUrl;
          if (videoUrl.startsWith('http')) {
            _videoUrl = videoUrl;
          } else if (videoUrl.startsWith('/response-video/')) {
            // Special handling for response-video endpoint
            _videoUrl = 'https://www.deeptrump.ai/api$videoUrl';

            // Log the constructed URL for debugging
            _logger.info('Constructed video URL: $_videoUrl');
          } else {
            _videoUrl = 'https://www.deeptrump.ai/api$videoUrl';
          }

          return {
            'ready': true,
            'video_url': _videoUrl,
            'session_id': videoData['session_id'] ?? sessionId,
            'response_text': videoData['response_text'] ?? '',
            'percent': videoData['percent'] ?? 100,
            'progress_status': videoData['progress_status'] ?? 'Completed',
          };
        }
      }

      return null;
    } catch (e) {
      _logger.warning('Error checking video status: $e');
      return null;
    }
  }

  /// Checks the progress of video generation
  /// Returns the progress percentage or null if not available
  Future<double?> checkVideoProgress(String sessionId) async {
    _logger.info('Checking video progress for session: $sessionId');

    try {
      final progressResponse = await _dio.get(
        '/api/progress/$sessionId',
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (status) => true,
        ),
      );

      _logger
          .info('Progress check - Status code: ${progressResponse.statusCode}');

      if (progressResponse.statusCode == 200) {
        Map<String, dynamic> progressData;

        if (progressResponse.data is Map) {
          progressData = progressResponse.data as Map<String, dynamic>;
        } else if (progressResponse.data is String) {
          try {
            progressData = jsonDecode(progressResponse.data);
          } catch (e) {
            _logger.severe('Failed to parse progress response as JSON: $e');
            return null;
          }
        } else {
          _logger.warning(
              'Unexpected progress response type: ${progressResponse.data.runtimeType}');
          return null;
        }

        // Check for progress percentage
        if (progressData.containsKey('percent')) {
          final percent = progressData['percent'];
          if (percent is num) {
            return percent.toDouble() / 100; // Convert to 0-1 range
          } else if (percent is String) {
            return (double.tryParse(percent) ?? 0) /
                100; // Convert to 0-1 range
          }
        }
      }

      return null;
    } catch (e) {
      _logger.warning('Error checking video progress: $e');
      return null;
    }
  }

  /// Waits for video completion, checking status periodically
  /// Returns video data when ready or throws exception after max attempts
  Future<Map<String, dynamic>> waitForVideoCompletion(
    String sessionId, {
    int maxAttempts = 30,
    int delaySeconds = 2,
    Function(int attempt, int maxAttempts)? onProgress,
  }) async {
    int attempts = 0;

    while (attempts < maxAttempts) {
      attempts++;
      _logger.info('Video check attempt $attempts of $maxAttempts');

      // Call the onProgress callback if provided
      onProgress?.call(attempts, maxAttempts);

      // Check progress (but don't block on it)
      checkVideoProgress(sessionId).then((progress) {
        if (progress != null) {
          _logger.info(
              'Video generation progress: ${(progress * 100).toStringAsFixed(1)}%');
        }
      });

      // Then check if the video is actually ready
      final videoData = await checkVideoStatus(sessionId);

      if (videoData != null) {
        _logger.info('Video is ready: ${videoData['video_url']}');
        return videoData;
      }

      // Wait before the next attempt
      await Future.delayed(Duration(seconds: delaySeconds));
    }

    throw Exception(
        'Maximum attempts reached. Video generation may still be in progress.');
  }

  /// Fetches the video library from the API
  /// Returns a map containing videos and pagination info
  Future<Map<String, dynamic>> getVideoLibrary({int page = 1}) async {
    _logger.info('Fetching video library, page: $page');

    try {
      final response = await _dio.get(
        '/api/video-library',
        queryParameters: {'page': page},
        options: Options(
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)',
          },
          validateStatus: (status) => true,
        ),
      );

      _logger.info('Video library response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        if (response.data is Map) {
          final Map<String, dynamic> data = response.data;
          final List<Map<String, dynamic>> videos = [];

          // Convert the videos map to a list for easier handling
          if (data.containsKey('videos') && data['videos'] is Map) {
            final videosMap = data['videos'] as Map<String, dynamic>;

            videosMap.forEach((key, value) {
              if (value is Map<String, dynamic>) {
                // Add the video ID as a field in the video data
                final videoData = {...value};
                videoData['id'] = key;
                videos.add(videoData);
              }
            });
          }

          return {
            'videos': videos,
            'pagination': data['pagination'] ?? {},
          };
        } else if (response.data is String) {
          try {
            final decodedData = jsonDecode(response.data);
            return decodedData;
          } catch (e) {
            _logger
                .severe('Failed to parse video library response as JSON: $e');
            throw Exception('Invalid API response format');
          }
        }
      }

      throw Exception('Failed to load videos: HTTP ${response.statusCode}');
    } on DioException catch (e) {
      _logger.severe('Network error fetching video library: ${e.message}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      _logger.severe('Error fetching video library: $e');
      throw Exception('Failed to load videos: $e');
    }
  }
}
