import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';

class PianoGame extends StatefulWidget {
  final String pianoId;
  final String deviceId;
  const PianoGame({super.key, required this.deviceId, required this.pianoId});

  @override
  State<PianoGame> createState() => _PianoGameState();
}

class _PianoGameState extends State<PianoGame> {
  final AudioPlayer audioPlayer = AudioPlayer();
  final List<String> allWhiteNotes = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];
  final List<String> allBlackNotes = ['C#', 'D#', 'F#', 'G#', 'A#'];
  List<String> targetNotes = [];
  String? currentTargetNote;
  int score = 0;
  bool isGameActive = false;
  bool isLoading = true;
  String error = '';


  final Map<String, Color> whiteNoteColors = {
    'C': Colors.red,
    'D': Colors.orange,
    'E': Colors.yellow,
    'F': Colors.green,
    'G': Colors.blue,
    'A': Colors.indigo,
    'B': Colors.purple,
  };

  final Map<String, Color> blackNoteColors = {
    'C#': Colors.red[800]!,
    'D#': Colors.orange[800]!,
    'F#': Colors.green[800]!,
    'G#': Colors.blue[800]!,
    'A#': Colors.indigo[800]!,
  };

  @override
  void initState() {
    super.initState();
    _fetchPianoNotes();
  }

  Future<void> _fetchPianoNotes() async {
    try {
      final pianoUri = Uri.parse(
        'http://10.0.2.2:8000/api/piano/${widget.pianoId}/',
      ).replace(queryParameters: {'device_id': widget.deviceId});

      debugPrint("Fetching piano details from: ${pianoUri.toString()}");

      final pianoResponse = await http
          .get(pianoUri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      debugPrint("Piano response status: ${pianoResponse.statusCode}");
      debugPrint("Piano response body: ${pianoResponse.body}");

      if (pianoResponse.statusCode == 200) {
        final Map<String, dynamic> pianoData = jsonDecode(pianoResponse.body);
        debugPrint("Piano data received: $pianoData");

        if (!pianoData.containsKey('notes') || pianoData['notes'] is! List) {
          throw Exception("Invalid notes data format received from server");
        }

        final List<dynamic> noteIds = pianoData['notes'];
        debugPrint("Note IDs received: $noteIds");

        if (noteIds.isEmpty) {
          throw Exception("Piano has no notes assigned");
        }

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
          debugPrint("Notes data received: $notesData");

          final List<String> notes = [];

          for (final noteItem in notesData) {
            try {
              if (noteItem is Map && noteItem['name'] != null) {
                final noteName = noteItem['name'].toString().trim();
                debugPrint("Processing note: $noteName");

                if (allWhiteNotes.contains(noteName) ||
                    allBlackNotes.contains(noteName)) {
                  notes.add(noteName);
                } else {
                  debugPrint("Note $noteName not in allowed notes list");
                }
              }
            } catch (e) {
              debugPrint("Error parsing note item: $e");
            }
          }

          setState(() {
            if (notes.isNotEmpty) {
              targetNotes = notes;
              isGameActive = true;
              error = '';
              generateNewTarget();
              debugPrint("Successfully loaded notes: $targetNotes");
            } else {
              error = 'No valid notes received from server';
              debugPrint("No valid notes found in response");
            }
            isLoading = false;
          });
        } else {
          throw Exception(
            'Failed to load note details: ${notesResponse.statusCode}',
          );
        }
      } else if (pianoResponse.statusCode == 403) {
        throw Exception('Invalid device ID - Access denied');
      } else if (pianoResponse.statusCode == 404) {
        throw Exception('Piano not found with ID ${widget.pianoId}');
      } else {
        throw Exception('Server error: ${pianoResponse.statusCode}');
      }
    } catch (e) {
      debugPrint("Error in _fetchPianoNotes: $e");
      setState(() {
        error = 'Failed to load notes: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  int currentNoteIndex = 0;

  void generateNewTarget() {
    if (targetNotes.isEmpty) {
      setState(() {
        error = 'No notes available';
        isGameActive = false;
      });
      return;
    }

    setState(() {
      currentTargetNote = targetNotes[currentNoteIndex];
    });
  }

  void handleNoteTap(String tappedNote) {
    if (!isGameActive || currentTargetNote == null) return;

    playSound(tappedNote);

    if (tappedNote == currentTargetNote) {
      setState(() {
        score += 1;
        currentNoteIndex++;

        if (currentNoteIndex >= targetNotes.length) {
          isGameActive = false;
          showSuccessDialog();
        } else {
          generateNewTarget();
        }
      });
    } else {
      setState(() {
        isGameActive = false;
      });
      showGameOverDialog();
    }
  }

  void showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Congratulations!'),
          content: const Text('You have successfully played a tune'),
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

  void resetGame() {
    setState(() {
      score = 0;
      currentNoteIndex = 0;
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
        appBar: AppBar(title: const Text('Piano Game')),
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
            color:
                whiteNoteColors.containsKey(currentTargetNote)
                    ? whiteNoteColors[currentTargetNote]
                    : blackNoteColors[currentTargetNote],
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.music_note, size: 40, color: Colors.white),
                  const SizedBox(height: 8),
                  Text(
                    currentTargetNote ?? '',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Score: $score',
                    style: const TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
          
                Row(
                  children:
                      allWhiteNotes.map((note) {
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => handleNoteTap(note),
                            child: Container(
                              margin: const EdgeInsets.all(1),
                              decoration: BoxDecoration(
                                color: whiteNoteColors[note],
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
                                      color: Colors.white,
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
                  height:
                      MediaQuery.of(context).size.height *
                      0.3,
                  child: Row(
                    children: [
                     
                      const Expanded(child: SizedBox()),

                    
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            right: 10.0,
                          ),
                          child: GestureDetector(
                            onTap: () => handleNoteTap('C#'),
                            child: Container(
                              width: 60,
                              height: 220,
                              decoration: BoxDecoration(
                                color: blackNoteColors['C#'],
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(6),
                                  bottomRight: Radius.circular(6),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    spreadRadius: 2,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border:
                                    'C#' == currentTargetNote
                                        ? Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        )
                                        : null,
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'C#',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10.0),
                          child: GestureDetector(
                            onTap: () => handleNoteTap('D#'),
                            child: Container(
                              width: 60,
                              height: 220,
                              decoration: BoxDecoration(
                                color: blackNoteColors['D#'],
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(6),
                                  bottomRight: Radius.circular(6),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    spreadRadius: 2,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border:
                                    'D#' == currentTargetNote
                                        ? Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        )
                                        : null,
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'D#',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const Expanded(child: SizedBox()),
                      const Expanded(child: SizedBox()),

                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10.0),
                          child: GestureDetector(
                            onTap: () => handleNoteTap('F#'),
                            child: Container(
                              width: 60,
                              height: 220,
                              decoration: BoxDecoration(
                                color: blackNoteColors['F#'],
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(6),
                                  bottomRight: Radius.circular(6),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    spreadRadius: 2,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border:
                                    'F#' == currentTargetNote
                                        ? Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        )
                                        : null,
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'F#',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10.0),
                          child: GestureDetector(
                            onTap: () => handleNoteTap('G#'),
                            child: Container(
                              width: 90,
                              height: 220,
                              decoration: BoxDecoration(
                                color: blackNoteColors['G#'],
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(6),
                                  bottomRight: Radius.circular(6),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    spreadRadius: 2,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border:
                                    'G#' == currentTargetNote
                                        ? Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        )
                                        : null,
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'G#',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 10.0),
                          child: GestureDetector(
                            onTap: () => handleNoteTap('A#'),
                            child: Container(
                              width: 60,
                              height: 220,
                              decoration: BoxDecoration(
                                color: blackNoteColors['A#'],
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(6),
                                  bottomRight: Radius.circular(6),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    spreadRadius: 2,
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                                border:
                                    'A#' == currentTargetNote
                                        ? Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        )
                                        : null,
                              ),
                              child: Align(
                                alignment: Alignment.bottomCenter,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Text(
                                    'A#',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

          
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
