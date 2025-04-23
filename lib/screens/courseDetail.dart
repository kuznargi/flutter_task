import 'package:flutter/material.dart';
import 'package:flutter_app/models/courseModel.dart';
import 'package:flutter_app/screens/piano.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CourseDetailScreen extends StatefulWidget {
  final int courseId;
  final String deviceId;

  const CourseDetailScreen({
    super.key,
    required this.courseId,
    required this.deviceId,
  });

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  Course? course;
  bool isLoading = true;
  String error = '';
  int? pianoId;

  @override
  void initState() {
    super.initState();
    _fetchCourseDetails();
  }

  Future<void> _fetchCourseDetails() async {
    try {
      final uri = Uri.parse('http://10.0.2.2:8000/api/course/${widget.courseId}/')
          .replace(queryParameters: {'device_id': widget.deviceId});
      
      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          course = Course.fromJson(data);
          pianoId = data['piano_id'];
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load course details');
      }
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  bool _handleHtmlLinkTap(String url) {
    if (url.startsWith('piano://')) {
      final id = url.replaceAll('piano://', '');
      if (id.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PianoGame(
              deviceId: widget.deviceId,
              pianoId: id,
            ),
          ),
        );
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (error.isNotEmpty || course == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(error.isEmpty ? 'Course not found' : error),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchCourseDetails,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(course!.header)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (course!.illustration.isNotEmpty)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    course!.illustration,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Center(
                        child: CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  loadingProgress.expectedTotalBytes!
                              : null,
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: Colors.grey[200],
                        child: const Center(
                          child: Icon(Icons.broken_image, size: 50),
                        ),
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              course!.header,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            HtmlWidget(
              course!.description,
              textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    height: 1.5,
                  ),
              onTapUrl: (url) {
              
                if (url.startsWith('piano://')) {
                  return _handleHtmlLinkTap(url);
                }
           
                return false;
              },
              customWidgetBuilder: (element) {
                if (element.localName == 'button' && 
                    element.attributes['data-piano-id'] != null) {
                  return ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PianoGame(
                            deviceId: widget.deviceId,
                            pianoId: element.attributes['data-piano-id']!,
                          ),
                        ),
                      );
                    },
                    child: Text(element.text),
                  );
                }
                return null;
              },
            ),
         
            if (pianoId != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PianoGame(
                        deviceId: widget.deviceId,
                        pianoId: pianoId.toString(),
                      ),
                    ),
                  );
                },
                child: const Text('Play Piano Melody'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}