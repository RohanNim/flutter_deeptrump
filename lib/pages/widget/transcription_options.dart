import 'package:flutter/material.dart';

class TranscriptionOptions extends StatefulWidget {
  final Function(String)? onLanguageChanged;
  final Function(String)? onVideoStyleChanged;
  final Function(String)? onVoiceStyleChanged;
  final Function(String)? onQualityChanged;
  final Function(String)? onEffectChanged;

  const TranscriptionOptions({
    super.key,
    this.onLanguageChanged,
    this.onVideoStyleChanged,
    this.onVoiceStyleChanged,
    this.onQualityChanged,
    this.onEffectChanged,
  });

  @override
  State<TranscriptionOptions> createState() => _TranscriptionOptionsState();
}

class _TranscriptionOptionsState extends State<TranscriptionOptions> {
  // Add state variables to track selections
  String _selectedLanguage = "en";
  String _selectedVideoStyle = "video1";
  String _selectedVoiceStyle = "confident";
  String _selectedQuality = "medium";
  String _selectedEffect = "none";

  @override
  Widget build(BuildContext context) {
    // return GestureDetector(
    //   onTap: () {

    //   },
    //   child: Container(
    //     width: MediaQuery.of(context).size.width * 0.1,
    //     height: MediaQuery.of(context).size.width * 0.1,
    //     decoration: BoxDecoration(
    //       color: Color.fromRGBO(97, 34, 107, 1),
    //       shape: BoxShape.circle,
    //     ),
    //     child: Center(
    //       child: Icon(
    //         Icons.add,
    //         color: Color.fromRGBO(255, 255, 255, 1),
    //       ),
    //     ),
    //   ),
    // );

    return PopupMenuButton(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.1,
        height: MediaQuery.of(context).size.width * 0.1,
        decoration: const BoxDecoration(
          color: Color.fromRGBO(97, 34, 107, 1),
          shape: BoxShape.circle,
        ),
        child: const Center(
          child: Icon(Icons.add, color: Color.fromRGBO(255, 255, 255, 1)),
        ),
      ),
      itemBuilder: (context) {
        return [
          _buildPopupMenuItem(
            // Show currently selected language
            _getLanguageName(_selectedLanguage),
            Icons.language,
            onTap: () {
              print("Language selected");
              _showLanguageOptions(context);
            },
          ),
          _buildPopupMenuItem(
            // Show currently selected video style
            _getVideoStyleName(_selectedVideoStyle),
            Icons.video_library,
            onTap: () {
              print("Video style selected");
              _showVideoStyleOptions(context);
            },
          ),
          _buildPopupMenuItem(
            "Voice: ${_getVoiceStyleName(_selectedVoiceStyle)}",
            Icons.record_voice_over,
            onTap: () {
              print("Voice style selected");
              _showVoiceStyleOptions(context);
            },
          ),
          _buildPopupMenuItem(
            "Quality: ${_getQualityName(_selectedQuality)}",
            Icons.high_quality,
            onTap: () {
              print("Quality selected");
              _showQualityOptions(context);
            },
          ),
          _buildPopupMenuItem(
            "Effect: ${_getEffectName(_selectedEffect)}",
            Icons.auto_fix_high,
            onTap: () {
              print("Effect selected");
              _showEffectOptions(context);
            },
          ),
        ];
      },
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: const Color.fromRGBO(42, 42, 62, 1),
    );
  }

  PopupMenuItem _buildPopupMenuItem(String title, IconData icon,
      {required Function onTap}) {
    return PopupMenuItem(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.arrow_forward_ios,
            color: Colors.white,
            size: 16,
          ),
        ],
      ),
      onTap: () => onTap(),
    );
  }

  // Helper methods to get display names
  String _getLanguageName(String key) {
    final Map<String, String> languages = {
      "en": "English",
      "es": "Spanish",
      "fr": "French",
      "de": "German",
      "zh": "Chinese",
      "ja": "Japanese",
      "ko": "Korean",
      "hi": "Hindi (हिन्दी)"
    };
    return languages[key] ?? "English";
  }

  String _getVideoStyleName(String key) {
    final Map<String, String> videoStyles = {
      "video1": "Presidential Speech",
      "video2": "Trump at Desk",
      "video3": "Trump Interview Style"
    };
    return videoStyles[key] ?? "Presidential Speech";
  }

  String _getVoiceStyleName(String key) {
    final Map<String, String> voiceStyles = {
      "confident": "Confident",
      "angry": "Angry",
      "calm": "Calm",
      "enthusiastic": "Enthusiastic"
    };
    return voiceStyles[key] ?? "Confident";
  }

  String _getQualityName(String key) {
    final Map<String, String> qualities = {"medium": "Medium", "high": "High"};
    return qualities[key] ?? "Medium";
  }

  String _getEffectName(String key) {
    final Map<String, String> effects = {
      "none": "None",
      "vintage": "Vintage",
      "black_white": "Black & White",
      "sepia": "Sepia",
      "dramatic": "Dramatic"
    };
    return effects[key] ?? "None";
  }

  void _showLanguageOptions(BuildContext context) {
    final Map<String, String> languages = {
      "en": "English",
      "es": "Spanish",
      "fr": "French",
      "de": "German",
      "zh": "Chinese",
      "ja": "Japanese",
      "ko": "Korean",
      "hi": "Hindi (हिन्दी)"
    };

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color.fromRGBO(42, 42, 62, 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Select Language",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  width: 250,
                  child: ListView.builder(
                    itemCount: languages.length,
                    itemBuilder: (context, index) {
                      String key = languages.keys.elementAt(index);
                      String value = languages[key]!;

                      return ListTile(
                        title: Text(
                          value,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedLanguage = key;
                          });

                          // Call the callback if provided
                          if (widget.onLanguageChanged != null) {
                            widget.onLanguageChanged!(key);
                          }

                          print("Selected language: $key ($value)");
                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text("Selected language: $value")),
                          );
                        },
                        // Show checkmark based on current selection
                        trailing: key == _selectedLanguage
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showVideoStyleOptions(BuildContext context) {
    final Map<String, String> videoStyles = {
      "video1": "Presidential Speech",
      "video2": "Trump at Desk",
      "video3": "Trump Interview Style"
    };

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color.fromRGBO(42, 42, 62, 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Select Video Style",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  width: 250,
                  child: ListView.builder(
                    itemCount: videoStyles.length,
                    itemBuilder: (context, index) {
                      String key = videoStyles.keys.elementAt(index);
                      String value = videoStyles[key]!;

                      return ListTile(
                        title: Text(
                          value,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          // Update state with the selected video style
                          setState(() {
                            _selectedVideoStyle = key;
                          });

                          // Call the callback if provided
                          if (widget.onVideoStyleChanged != null) {
                            widget.onVideoStyleChanged!(key);
                          }

                          print("Selected video style: $key ($value)");
                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text("Selected video style: $value")),
                          );
                        },
                        // Show checkmark based on current selection
                        trailing: key == _selectedVideoStyle
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showVoiceStyleOptions(BuildContext context) {
    final Map<String, String> voiceStyles = {
      "confident": "Confident",
      "angry": "Angry",
      "calm": "Calm",
      "enthusiastic": "Enthusiastic"
    };

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color.fromRGBO(42, 42, 62, 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Select Voice Style",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  width: 250,
                  child: ListView.builder(
                    itemCount: voiceStyles.length,
                    itemBuilder: (context, index) {
                      String key = voiceStyles.keys.elementAt(index);
                      String value = voiceStyles[key]!;

                      return ListTile(
                        title: Text(
                          value,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedVoiceStyle = key;
                          });

                          // Call the callback if provided
                          if (widget.onVoiceStyleChanged != null) {
                            widget.onVoiceStyleChanged!(key);
                          }

                          print("Selected voice style: $key ($value)");
                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text("Selected voice style: $value")),
                          );
                        },
                        trailing: key == _selectedVoiceStyle
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQualityOptions(BuildContext context) {
    final Map<String, String> qualities = {"medium": "Medium", "high": "High"};

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color.fromRGBO(42, 42, 62, 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Select Video Quality",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height:
                      120, // Smaller height since there are only two options
                  width: 250,
                  child: ListView.builder(
                    itemCount: qualities.length,
                    itemBuilder: (context, index) {
                      String key = qualities.keys.elementAt(index);
                      String value = qualities[key]!;

                      return ListTile(
                        title: Text(
                          value,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedQuality = key;
                          });

                          // Call the callback if provided
                          if (widget.onQualityChanged != null) {
                            widget.onQualityChanged!(key);
                          }

                          print("Selected quality: $key ($value)");
                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Selected quality: $value")),
                          );
                        },
                        trailing: key == _selectedQuality
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showEffectOptions(BuildContext context) {
    final Map<String, String> effects = {
      "none": "None",
      "vintage": "Vintage",
      "black_white": "Black & White",
      "sepia": "Sepia",
      "dramatic": "Dramatic"
    };

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color.fromRGBO(42, 42, 62, 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Select Video Effect",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 250,
                  width: 250,
                  child: ListView.builder(
                    itemCount: effects.length,
                    itemBuilder: (context, index) {
                      String key = effects.keys.elementAt(index);
                      String value = effects[key]!;

                      return ListTile(
                        title: Text(
                          value,
                          style: const TextStyle(color: Colors.white),
                        ),
                        onTap: () {
                          setState(() {
                            _selectedEffect = key;
                          });

                          // Call the callback if provided
                          if (widget.onEffectChanged != null) {
                            widget.onEffectChanged!(key);
                          }

                          print("Selected effect: $key ($value)");
                          Navigator.pop(context);

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text("Selected effect: $value")),
                          );
                        },
                        trailing: key == _selectedEffect
                            ? const Icon(Icons.check, color: Colors.white)
                            : null,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
