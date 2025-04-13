import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';

class PianoGame extends StatefulWidget {
  final String deviceId;
  const PianoGame({super.key, required this.deviceId});

  @override
  State<PianoGame> createState() => _PianoGameState();
}

class _PianoGameState extends State<PianoGame> {
  final AudioPlayer audioPlayer = AudioPlayer();
  List<String> allNotes = ['Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Ti'];
  // Все возможные ноты
  List<String> targetNotes = []; // Ноты из БД (которые нужно нажимать)
  String? currentTargetNote;
  int score = 0;
  bool isGameActive = true;
  bool isLoading = true;
  String error = '';

  final Map<String, Color> noteColors = {
    'C': Colors.red,
    'D': Colors.orange,
    'E': Colors.yellow,
    'F': Colors.green,
    'G': Colors.blue,
    'A': Colors.indigo,
    'B': Colors.purple,
  };

  @override
  void initState() {
    super.initState();
    _fetchTargetNotes();
  }

  Future<void> _fetchTargetNotes() async {
    try {
      final response = await http.get(
        Uri.parse(
          'http://10.0.2.2:8000/api/piano/',
        ).replace(queryParameters: {'device_id': widget.deviceId}),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final List<String> notes = [];

        for (final item in data) {
          if (item is Map) {
            if (item['note_name'] != null) {
              notes.add(item['note_name'].toString());
            } else if (item['note'] is Map && item['note']['name'] != null) {
              notes.add(item['note']['name'].toString());
            }
          }
        }

        setState(() {
          targetNotes = notes;
          isLoading = false;
          if (targetNotes.isNotEmpty) {
            generateNewTarget();
          } else {
            error = 'No target notes found';
          }
        });
      } else {
        throw Exception('Failed to load notes');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  void generateNewTarget() {
    if (targetNotes.isEmpty) return;
    setState(() {
      currentTargetNote = targetNotes[Random().nextInt(targetNotes.length)];
    });
  }

  void handleNoteTap(String tappedNote) {
    if (!isGameActive || currentTargetNote == null) return;

    playSound(tappedNote);

    if (tappedNote == currentTargetNote) {
      setState(() {
        score += 1;
        generateNewTarget();
      });
    } else {
      setState(() {
        isGameActive = false;
        showGameOverDialog();
      });
    }
  }

  void resetGame() {
    setState(() {
      score = 0;
      isGameActive = true;
      generateNewTarget();
    });
  }

  void playSound(String note) async {
    if (note.isNotEmpty) {
      await audioPlayer.play(AssetSource('sounds/$note.mp3'));
    }
  }

   void showGameOverDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Game Over'),
          content: Text('Your score: $score'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                resetGame();
              },
              child: const Text('Play again'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(error),
              ElevatedButton(
                onPressed: _fetchTargetNotes,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            color: Colors.grey[200],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.music_note, size: 40),
                  const SizedBox(height: 10),
                 
                  Text(
                    currentTargetNote ?? '',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Score: $score', style: const TextStyle(fontSize: 24)),
                ],
              ),
            ),
          ),
        ),

      
        Expanded(
          flex: 2,
          child: Stack(
            children: [
              Row(
                children: List.generate(allNotes.length, (index) {
                  final note = allNotes[index];
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => handleNoteTap(note),
                      child: Container(
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: noteColors[note] ?? Colors.grey,
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Text(
                              note,
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              // Черные клавиши
              Positioned.fill(
                child: Row(
                  children: List.generate(allNotes.length - 1, (index) {
                    if (index != 2 && index != 6) {
                      return Expanded(
                        child: Align(
                          alignment: Alignment.center,
                          child: Container(
                            width: 40,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      );
                    } else {
                      return const Expanded(child: SizedBox());
                    }
                  }),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
