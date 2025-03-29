import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class TrumpStyleSelector extends StatefulWidget {
  final Function(String) onStyleSelected;
  final String? selectedStyle;

  const TrumpStyleSelector({
    Key? key,
    required this.onStyleSelected,
    this.selectedStyle,
  }) : super(key: key);

  @override
  State<TrumpStyleSelector> createState() => _TrumpStyleSelectorState();
}

class _TrumpStyleSelectorState extends State<TrumpStyleSelector> {
  // Map video choices to their corresponding video paths
  final Map<String, Map<String, String>> _videoChoices = const {
    "video1": {
      "title": "Presidential Speech",
      "video": "https://deeptrump.ai/api/character-videos/trmp_char1.mp4"
    },
    "video2": {
      "title": "Trump at Desk",
      "video": "https://deeptrump.ai/api/character-videos/trmp_char2.mp4"
    },
    "video3": {
      "title": "Trump Interview Style",
      "video": "https://deeptrump.ai/api/character-videos/trmp_char3.mp4"
    },
  };

  // Map to store video controllers
  Map<String, VideoPlayerController> _controllers = {};

  @override
  void initState() {
    super.initState();
    // Initialize video controllers
    for (String key in _videoChoices.keys) {
      String videoUrl = _videoChoices[key]!['video']!;
      _controllers[key] = VideoPlayerController.network(videoUrl)
        ..initialize().then((_) {
          // Ensure the first frame is shown
          if (mounted) setState(() {});
          // Loop the videos
          _controllers[key]!.setLooping(true);
          // Play videos (you might want to control this behavior)
          _controllers[key]!.play();
          // Set volume to zero for preview thumbnails
          _controllers[key]!.setVolume(0.0);
        });
    }
  }

  @override
  void dispose() {
    // Dispose all controllers when the widget is removed
    for (VideoPlayerController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _videoChoices.length,
        itemBuilder: (context, index) {
          String key = _videoChoices.keys.elementAt(index);
          String title = _videoChoices[key]!['title']!;
          bool isSelected = widget.selectedStyle == key;
          VideoPlayerController controller = _controllers[key]!;

          return GestureDetector(
            onTap: () => widget.onStyleSelected(key),
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Container(
                padding: const EdgeInsets.all(8),
                width: 190,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(11, 2, 28, 1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected
                        ? Colors.red.shade900
                        : const Color.fromRGBO(255, 255, 255, 0.1),
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: controller.value.isInitialized
                          ? SizedBox(
                              width: 60,
                              height: 42,
                              child: AspectRatio(
                                aspectRatio: controller.value.aspectRatio,
                                child: VideoPlayer(controller),
                              ),
                            )
                          : Container(
                              width: 60,
                              height: 42,
                              color: Colors.black,
                              child: const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 90,
                      height: 40,
                      child: Center(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontFamily: 'Kodchasan',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
