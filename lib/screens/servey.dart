import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_app/screens/home.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:device_info_plus/device_info_plus.dart';




class DeviceCheckScreen extends StatefulWidget {
  const DeviceCheckScreen({super.key});

  @override
  State<DeviceCheckScreen> createState() => _DeviceCheckScreenState();
}

class _DeviceCheckScreenState extends State<DeviceCheckScreen> {
  String? _deviceId;
  bool? _deviceExists;
  bool _isLoading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _initDeviceCheck();
  }

  Future<void> _initDeviceCheck() async {
    try {
      _deviceId = await _getDeviceId();
      final response = await http.get(
        Uri.parse('http://10.0.2.2:8000/api/check-device/$_deviceId/'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _deviceExists = data['exists'];
          _isLoading = false;
        });
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      return (await deviceInfo.androidInfo).id;
    } else if (Platform.isIOS) {
      return (await deviceInfo.iosInfo).identifierForVendor ?? '';
    }
    return 'unknown_device';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text(_error)),
      );
    }

    return _deviceExists! ? Home(deviceId: _deviceId!) : SurveyForm(deviceId: _deviceId!);
  }
}

class SurveyForm extends StatefulWidget {
  final String deviceId;

  const SurveyForm({super.key, required this.deviceId});

  @override
  State<SurveyForm> createState() => _SurveyFormState();
}

class _SurveyFormState extends State<SurveyForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  bool _isSubmitting = false;
  String _error = '';

  
 Future<void> _submitForm() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    _isSubmitting = true;
    _error = '';
  });

  try {
    print('Sending request to server...');
    final response = await http.post(
      Uri.parse('http://10.0.2.2:8000/api/user/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'device_id': widget.deviceId,
        'name': _nameController.text.trim(),
        'age': int.parse(_ageController.text),
      }),
    ).timeout(const Duration(seconds: 15));

    print('Response received: ${response.statusCode}');
    
    final responseData = jsonDecode(response.body);
    
    if (response.statusCode == 201) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => Home(deviceId: widget.deviceId),
        ),
      );
    } else {
      throw Exception(responseData['error'] ?? 'Survey failed with status ${response.statusCode}');
    }
  } on TimeoutException {
    setState(() => _error = 'Server is taking too long to respond. Please try again later.');
  } on SocketException {
    setState(() => _error = 'Could not connect to server. Check your internet connection.');
  } on FormatException {
    setState(() => _error = 'Invalid server response. Please contact support.');
  } catch (e) {
    setState(() => _error = 'Error: ${e.toString().replaceAll('Exception: ', '')}');
  } finally {
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }
}
  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Survey')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ageController,
                decoration: const InputDecoration(labelText: 'Age'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your age';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              if (_error.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  _error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator()
                    : const Text('Submit Survey'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}