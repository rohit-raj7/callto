 



 import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../actions/calling.dart';

class ExpertCard extends StatefulWidget {
  final String name;
  final int age;
  final String city;
  final String topic;
  final String rate;
  final double rating;
  final String imagePath;

  const ExpertCard({
    super.key,
    required this.name,
    required this.age,
    required this.city,
    required this.topic,
    required this.rate,
    required this.rating,
    required this.imagePath,
  });

  @override
  State<ExpertCard> createState() => _ExpertCardState();
}

class _ExpertCardState extends State<ExpertCard> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isPlaying = false;

  Future<void> _toggleVoice() async {
    if (isPlaying) {
      await _audioPlayer.stop();
    } else {
      await _audioPlayer.play(AssetSource('voice/sample.mp3'));
    }
    setState(() {
      isPlaying = !isPlaying;
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    // Responsive font scaling
    final double nameFontSize = screenWidth < 360 ? 13 : 15;
    final double cityFontSize = screenWidth < 360 ? 11 : 13;
    final double topicFontSize = screenWidth < 360 ? 11 : 13;
    final double ratingFontSize = screenWidth < 360 ? 11 : 13;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar with status + age
            Column(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: AssetImage(widget.imagePath),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Online",
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontSize: 9),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "${widget.age} Y",
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(width: 10),

            // Expert Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: nameFontSize,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    widget.city,
                    style: TextStyle(
                      fontSize: cityFontSize,
                      color: Colors.black54,
                    ),
                  ),
                  Text(
                    widget.topic,
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: topicFontSize,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 14),
                      const SizedBox(width: 3),
                      Text(
                        widget.rating.toString(),
                        style: TextStyle(
                          fontSize: ratingFontSize,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Buttons + ₹5/min below
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: _toggleVoice,
                      icon: Icon(
                        isPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.pinkAccent,
                        size: screenWidth < 360 ? 20 : 24,
                      ),
                    ),
                    const SizedBox(width: 4),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const Calling()),
                        );
                      },
                      icon: const Icon(Icons.call,
                          size: 16, color: Colors.white),
                      label: Text(
                        "Call Now",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: screenWidth < 360 ? 11 : 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.pinkAccent,
                        padding: EdgeInsets.symmetric(
                          horizontal: screenWidth < 360 ? 10 : 14,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // ₹5/min text aligned below Call Now button
                const Text(
                  "₹5/min",
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
