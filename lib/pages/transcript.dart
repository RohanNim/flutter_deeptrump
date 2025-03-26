import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: VideoGeneratorScreen(),
    );
  }
}

class VideoGeneratorScreen extends StatefulWidget {
  @override
  _VideoGeneratorScreenState createState() => _VideoGeneratorScreenState();
}

class _VideoGeneratorScreenState extends State<VideoGeneratorScreen> {
  final TextEditingController _textController = TextEditingController();
  VideoPlayerController? _videoController;
  String? _videoUrl;
  bool _isLoading = false;
  final Dio _dio = Dio();

  Future<void> generateVideo() async {
    if (_textController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enter text to generate video!')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await _dio.post(
        'https://www.deeptrump.ai/generate',  // Replace with your actual API URL
        data: {'text': _textController.text},
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      if (response.statusCode == 200) {
        final responseData = response.data;
        if (responseData is Map<String, dynamic> && responseData.containsKey('video_url')) {
          setState(() {
            _videoUrl = responseData['video_url'];
            _videoController = VideoPlayerController.network(_videoUrl!)
              ..initialize().then((_) {
                setState(() {});
                _videoController!.play();
              });
          });
        } else {
          throw Exception('Unexpected API response');
        }
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AI Video Generator')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Enter text for video',
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : generateVideo,
              child: _isLoading ? CircularProgressIndicator() : Text('Generate Video'),
            ),
            SizedBox(height: 20),
            _videoUrl != null && _videoController != null && _videoController!.value.isInitialized
                ? AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  )
                : Text(_isLoading ? 'Generating video...' : 'No video generated yet'),
          ],
        ),
      ),
    );
  }
}
