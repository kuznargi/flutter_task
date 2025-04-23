import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Piano Game',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _deviceIdController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enter Device ID')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _deviceIdController,
              decoration: const InputDecoration(
                labelText: 'Device ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (_deviceIdController.text.isNotEmpty) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) =>
                              PianoGame(deviceId: _deviceIdController.text),
                    ),
                  );
                }
              },
              child: const Text('Start Piano Game'),
            ),
          ],
        ),
      ),
    );
  }
}

class PianoGame extends StatefulWidget {
  final String deviceId;
  const PianoGame({super.key, required this.deviceId});

  @override
  State<PianoGame> createState() => _PianoGameState();
}

class _PianoGameState extends State<PianoGame> {
  final AudioPlayer audioPlayer = AudioPlayer();
  final List<String> allNotes = ['Do', 'Re', 'Mi', 'Fa', 'Sol', 'La', 'Ti'];
  List<String> targetNotes = [];
  String? currentTargetNote;
  int score = 0;
  bool isGameActive = false;
  bool isLoading = true;
  String error = '';

  final Map<String, Color> noteColors = {
    'Do': Colors.red,
    'Re': Colors.orange,
    'Mi': Colors.yellow,
    'Fa': Colors.green,
    'Sol': Colors.blue,
    'La': Colors.indigo,
    'Ti': Colors.purple,
  };

  @override
  void initState() {
    super.initState();
    _fetchPianoNotes();
  }

  Future<void> _fetchPianoNotes() async {
    try {
      // First fetch piano records to get note IDs
      final pianoUri = Uri.parse(
        'http://10.0.2.2:8000/api/piano/',
      ).replace(queryParameters: {'device_id': widget.deviceId});

      debugPrint("Fetching piano records from: ${pianoUri.toString()}");

      final pianoResponse = await http
          .get(pianoUri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      debugPrint("Piano response status: ${pianoResponse.statusCode}");
      debugPrint("Piano response body: ${pianoResponse.body}");

      if (pianoResponse.statusCode == 200) {
        final List<dynamic> pianoData = jsonDecode(pianoResponse.body);
        final noteIds = <int>[];

        // Extract note IDs from piano records
        for (final item in pianoData) {
          try {
            if (item['note'] != null) {
              noteIds.add(item['note'] as int);
            }
          } catch (e) {
            debugPrint("Error parsing note ID: $e");
          }
        }

        if (noteIds.isNotEmpty) {
          // Now fetch note names using the IDs
          final notesUri = Uri.parse('http://10.0.2.2:8000/api/note/').replace(
            queryParameters: {
              'ids': noteIds.join(','),
              'device_id': widget.deviceId,
            },
          );

          debugPrint("Fetching note details from: ${notesUri.toString()}");

          final notesResponse = await http
              .get(notesUri, headers: {'Accept': 'application/json'})
              .timeout(const Duration(seconds: 10));

          debugPrint("Notes response status: ${notesResponse.statusCode}");
          debugPrint("Notes response body: ${notesResponse.body}");

          if (notesResponse.statusCode == 200) {
            final List<dynamic> notesData = jsonDecode(notesResponse.body);
            final List<String> notes = [];

            for (final noteItem in notesData) {
              try {
                if (noteItem['name'] != null) {
                  final noteName = noteItem['name'].toString();
                  if (allNotes.contains(noteName)) {
                    notes.add(noteName);
                  }
                }
              } catch (e) {
                debugPrint("Error parsing note name: $e");
              }
            }

            setState(() {
              if (notes.isNotEmpty) {
                targetNotes = notes;
                isGameActive = true;
                error = '';
                generateNewTarget();
              } else {
                error = 'No valid notes received from server';
              }
              isLoading = false;
            });
            return;
          }
        }
      }

      // If we get here, something went wrong
      throw Exception('Failed to load notes');
    } catch (e) {
      debugPrint("Error in _fetchPianoNotes: $e");
      setState(() {
        error = 'Failed to load notes: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  void generateNewTarget() {
    if (targetNotes.isEmpty) {
      setState(() {
        error = 'No notes available';
        isGameActive = false;
      });
      return;
    }
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
      });
      showGameOverDialog();
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
    try {
      await audioPlayer.play(AssetSource('sounds/$note.mp3'));
    } catch (e) {
      debugPrint("Error playing sound: $e");
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
              child: const Text('Play Again'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading piano notes from server...'),
            ],
          ),
        ),
      );
    }

    if (error.isNotEmpty || !isGameActive) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                error,
                style: const TextStyle(fontSize: 16, color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchPianoNotes,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Piano Game'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchPianoNotes,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[200],
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.music_note, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    currentTargetNote ?? '',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.indigo,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Score: $score', style: const TextStyle(fontSize: 24)),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Row(
                  children:
                      allNotes.map((note) {
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => handleNoteTap(note),
                            child: Container(
                              margin: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                color: noteColors[note] ?? Colors.grey,
                                border:
                                    note == currentTargetNote
                                        ? Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        )
                                        : null,
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    note,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: 120,
                  child: Row(
                    children: [
                      for (int i = 0; i < allNotes.length - 1; i++)
                        if (i != 2 && i != 6)
                          Expanded(
                            child: Align(
                              alignment: Alignment.center,
                              child: GestureDetector(
                                onTap: () => handleNoteTap(allNotes[i]),
                                child: Container(
                                  width: 36,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.black,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          )
                        else
                          const Expanded(child: SizedBox()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
