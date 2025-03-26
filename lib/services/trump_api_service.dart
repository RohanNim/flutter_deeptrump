import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:flutter/material.dart';

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
    _logger.info('Submitting transcript: ${transcript.substring(0, transcript.length > 30 ? 30 : transcript.length)}...');
    
    try {
      // Direct API approach failed (returned HTML), trying Postman version
      final formData = FormData.fromMap({
        'transcript': transcript,
      });
      
      _logger.info('Sending request to /generate endpoint with transcript data');
      
      final response = await _dio.post(
        '/generate',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            // Add additional headers to match browser behavior
            'Accept-Encoding': 'gzip, deflate, br',
            'Accept-Language': 'en-US,en;q=0.9',
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
            'Pragma': 'no-cache',
            'Sec-Fetch-Dest': 'empty',
            'Sec-Fetch-Mode': 'cors',
            'Sec-Fetch-Site': 'same-origin',
          },
          validateStatus: (status) => true, // Accept any status code for debugging
          followRedirects: true,
          maxRedirects: 5,
        ),
      );

      _logger.info('Response status: ${response.statusCode}');
      
      // Log full response for debugging if it's string (likely HTML)
      if (response.data is String && response.data.toString().startsWith('<!DOCTYPE')) {
        final preview = response.data.toString().length > 200 
            ? response.data.toString().substring(0, 200) 
            : response.data.toString();
        _logger.severe('Received HTML instead of JSON! First 200 chars: $preview');
        
        // Try alternative endpoint as fallback
        return await _submitTranscriptFallback(transcript);
      }
      
      Map<String, dynamic> data;
      if (response.data is Map) {
        data = response.data as Map<String, dynamic>;
      } else if (response.data is String) {
        try {
          data = jsonDecode(response.data);
        } catch (e) {
          _logger.severe('Failed to parse response as JSON: $e');
          // Try alternative endpoint as fallback
          return await _submitTranscriptFallback(transcript);
        }
      } else {
        throw Exception('Unexpected response format: ${response.data.runtimeType}');
      }
      
      final String? sessionId = data['session_id'];
      if (sessionId != null) {
        _logger.info('Successfully got session ID: $sessionId');
        return sessionId;
      } else {
        throw Exception('No session ID in response');
      }
    } on DioException catch (e) {
      _logger.severe('Network error: ${e.message}');
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      _logger.severe('Error: $e');
      throw Exception('Failed to submit transcript: $e');
    }
  }
  
  /// Fallback method that tries a different endpoint/approach
  Future<String> _submitTranscriptFallback(String transcript) async {
    _logger.info('Trying fallback transcript submission method');
    
    try {
      // Try a direct API endpoint with JSON payload instead
      final response = await _dio.post(
        '/api/generate', // Different endpoint
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
          validateStatus: (status) => true,
        ),
        data: jsonEncode({
          'transcript': transcript,
          'client': 'mobile_app'
        }),
      );
      
      _logger.info('Fallback response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        Map<String, dynamic> data;
        if (response.data is Map) {
          data = response.data as Map<String, dynamic>;
        } else if (response.data is String) {
          try {
            data = jsonDecode(response.data);
          } catch (e) {
            throw Exception('Fallback also failed to parse JSON: $e');
          }
        } else {
          throw Exception('Unexpected fallback response: ${response.data.runtimeType}');
        }
        
        final String? sessionId = data['session_id'] ?? data['id'];
        if (sessionId != null) {
          _logger.info('Fallback: got session ID: $sessionId');
          return sessionId;
        } else {
          throw Exception('No session ID in fallback response');
        }
      } else {
        throw Exception('Fallback request failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      _logger.severe('Fallback error: $e');
      throw Exception('All transcript submission methods failed: $e');
    }
  }

  /// Checks if a video is ready using the session ID
  /// Returns the video details if ready, null otherwise
  Future<Map<String, dynamic>?> checkVideoStatus(String sessionId) async {
    _logger.info('Checking video status for session: $sessionId');
    
    try {
      final videoResponse = await _dio.get(
        '/api/status',
        queryParameters: {'id': sessionId},
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (status) => true,
        ),
      );

      _logger.info('Video status check - Status code: ${videoResponse.statusCode}');
      
      // Check for HTML response instead of JSON
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
          _logger.warning('Unexpected response type: ${videoResponse.data.runtimeType}');
          return null;
        }
        
        // Check for both ready=true (new API) and status=completed (old API) patterns
        if ((videoData['ready'] == true || videoData['status'] == 'completed') && 
            videoData['video_url'] != null) {
          
          // Format the video URL if it's a relative path
          final String videoUrl = videoData['video_url'];
          final formattedVideoUrl = videoUrl.startsWith('http')
              ? videoUrl
              : 'https://www.deeptrump.ai$videoUrl';
              
          return {
            'ready': true,
            'video_url': formattedVideoUrl,
            'session_id': sessionId,
            'response_text': videoData['response_text'] ?? videoData['text'] ?? '',
          };
        }
      }
      
      // Try alternative status endpoint if main one doesn't work
      if (videoResponse.statusCode != 200 || videoResponse.data is String) {
        return _checkVideoStatusFallback(sessionId);
      }
      
      return null;
    } catch (e) {
      _logger.warning('Error checking video status: $e');
      return null;
    }
  }
  
  /// Fallback method to check video status on a different endpoint
  Future<Map<String, dynamic>?> _checkVideoStatusFallback(String sessionId) async {
    _logger.info('Trying fallback status check for session: $sessionId');
    
    try {
      final videoResponse = await _dio.get(
        '/is-video-ready',  // Alternative endpoint from curl example
        queryParameters: {'session_id': sessionId},
        options: Options(
          headers: {'Accept': 'application/json'},
          validateStatus: (status) => true,
        ),
      );
      
      _logger.info('Fallback status check - Status code: ${videoResponse.statusCode}');
      
      if (videoResponse.statusCode == 200) {
        Map<String, dynamic> videoData;
        
        if (videoResponse.data is Map) {
          videoData = videoResponse.data as Map<String, dynamic>;
        } else if (videoResponse.data is String) {
          try {
            videoData = jsonDecode(videoResponse.data);
          } catch (e) {
            return null;
          }
        } else {
          return null;
        }
        
        if (videoData['ready'] == true && videoData['video_url'] != null) {
          final String videoUrl = videoData['video_url'];
          final formattedVideoUrl = videoUrl.startsWith('http')
              ? videoUrl
              : 'https://www.deeptrump.ai$videoUrl';
              
          return {
            'ready': true,
            'video_url': formattedVideoUrl,
            'session_id': sessionId,
            'response_text': videoData['response_text'] ?? '',
          };
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Polls the API until the video is ready or max attempts are reached
  /// Returns video details if successful, throws an exception otherwise
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
      
      final videoData = await checkVideoStatus(sessionId);
      
      if (videoData != null) {
        _logger.info('Video is ready: ${videoData['video_url']}');
        return videoData;
      }
      
      // Wait before trying again
      await Future.delayed(Duration(seconds: delaySeconds));
    }
    
    throw Exception('Video generation timed out after $maxAttempts attempts');
  }
}