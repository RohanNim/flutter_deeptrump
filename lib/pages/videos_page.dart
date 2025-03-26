import 'package:flutter/material.dart';

class VideosPage extends StatelessWidget {
  const VideosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trump Videos'),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: 10, // Replace with actual video count
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              children: [
                // Video thumbnail
                Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      size: 48,
                      color: Colors.red.shade900,
                    ),
                  ),
                ),
                // Video details
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trump Video ${index + 1}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Generated on ${DateTime.now().subtract(Duration(days: index)).toString().split(' ')[0]}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.thumb_up, 
                            size: 16, 
                            color: Colors.grey.shade600
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${(100 - index * 5)}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.remove_red_eye, 
                            size: 16, 
                            color: Colors.grey.shade600
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${(1000 - index * 50)}',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
} 