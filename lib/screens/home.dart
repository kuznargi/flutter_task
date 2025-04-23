import 'package:flutter/material.dart';
import 'package:flutter_app/models/pianoModel.dart';
import 'package:flutter_app/screens/courseDetail.dart';
import 'package:flutter_app/screens/piano.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/courseModel.dart';

class Home extends StatefulWidget {
  final String deviceId;
  const Home({super.key, required this.deviceId});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  List<Course> courses = [];
  bool isLoading = true;
  String error = '';

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    try {
      final uri = Uri.parse(
        'http://10.0.2.2:8000/api/courses/',
      ).replace(queryParameters: {'device_id': widget.deviceId});

      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          courses = data.map((json) => Course.fromJson(json)).toList();
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load courses');
      }
    } catch (e) {
      setState(() {
        error = 'Error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ');
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(error),
              ElevatedButton(
                onPressed: _fetchCourses,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Courses'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchCourses),
        ],
      ),
      body: Column(
        children: [
          // Список курсов
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: courses.length,
              itemBuilder: (context, index) => _buildCourseCard(courses[index]),
            ),
          ),

          // Кнопка для перехода на другой экран
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => PianoGame(
                    deviceId: widget.deviceId,
                  ),
            ),
          );
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue, // Цвет кнопки
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                shadowColor: Colors.black.withOpacity(0.2),
                elevation: 5,
              ),
              child: const Text(
                'Piano',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCourseCard(Course course) {
    // Функция для очистки HTML и обрезки текста
    String getShortDescription(String html) {
      // Удаляем HTML-теги
      final text = html.replaceAll(RegExp(r'<[^>]*>'), '');
      // Удаляем множественные пробелы
      final cleanText = text.replaceAll(RegExp(r'\s+'), ' ').trim();
      // Обрезаем до 50 символов
      return cleanText.length > 50
          ? '${cleanText.substring(0, 50)}...'
          : cleanText;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => CourseDetailScreen(
                    courseId: course.id,
                    deviceId: widget.deviceId,
                  ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (course.illustration.isNotEmpty)
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child:
                 Image.network(
  course.illustration,
   headers: {"User-Agent": "Mozilla/5.0"}, 
  fit: BoxFit.cover,
  errorBuilder: (_, error, __) {
    print('Image load error: $error'); // Добавьте это
    return Container(
      color: Colors.grey[200],
      child: const Icon(Icons.broken_image),
    );
  },
)
                ),
              const SizedBox(height: 12),
              Text(
                course.header,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                getShortDescription(course.description),
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
