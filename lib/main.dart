import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' show join;

const String uploadUrl = 'https://flutter-sandbox.free.beeceptor.com/upload_photo/';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cameras = await availableCameras();
  final firstCamera = cameras.first;

  runApp(MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;

  const MyApp({
    super.key,
    required this.camera,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Photo Uploader',
      theme: ThemeData.dark(),
      home: UploadScreen(camera: camera),
    );
  }
}

class UploadScreen extends StatefulWidget {
  final CameraDescription camera;

  const UploadScreen({
    super.key,
    required this.camera,
  });

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  late CameraController _cameraController;
  late Future<void> _initializeControllerFuture;
  final TextEditingController _commentController = TextEditingController();

  bool _isUploading = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    _cameraController = CameraController(
      widget.camera,
      ResolutionPreset.medium,
    );
    _initializeControllerFuture = _cameraController.initialize();
  }

  @override
  void dispose() {
    _cameraController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
          'Location permissions are permanently denied, we cannot request permissions.');
    }
    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _captureAndUpload() async {
    if (_isUploading) return;

    setState(() {
      _isUploading = true;
      _statusMessage = 'Starting upload...';
    });

    try {
      await _initializeControllerFuture;

      final path = join(
        (await getTemporaryDirectory()).path,
        '${DateTime.now()}.png',
      );

      setState(() { _statusMessage = 'Capturing image...'; });
      final XFile imageFile = await _cameraController.takePicture();
      await imageFile.saveTo(path);

      setState(() { _statusMessage = 'Getting location...'; });
      Position position = await _determinePosition();

      final String comment = _commentController.text;

      setState(() { _statusMessage = 'Uploading data...'; });
      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));

      request.fields['comment'] = comment;
      request.fields['latitude'] = position.latitude.toString();
      request.fields['longitude'] = position.longitude.toString();

      request.files.add(await http.MultipartFile.fromPath('photo', path));

      var response = await request.send();

      if (response.statusCode == 200) {
        setState(() {
          _statusMessage = 'Upload successful!';
          _commentController.clear();
        });
      } else {
        setState(() {
          _statusMessage = 'Upload failed: ${response.statusCode}';
        });
      }
    } catch (e) {
      debugPrint(e.toString());
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capture & Upload Photo')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              FutureBuilder<void>(
                future: _initializeControllerFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12.0),
                      child: AspectRatio(
                        aspectRatio: _cameraController.value.aspectRatio,
                        child: CameraPreview(_cameraController),
                      ),
                    );
                  } else {
                    return const Center(child: CircularProgressIndicator());
                  }
                },
              ),
              const SizedBox(height: 16.0),

              TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  labelText: 'Enter a comment',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16.0),

              if (_statusMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _statusMessage.startsWith('Error')
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ),

              ElevatedButton.icon(
                icon: _isUploading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.0, color: Colors.white),
                )
                    : const Icon(Icons.camera_alt),
                label: Text(_isUploading ? 'Uploading...' : 'Capture & Upload'),
                onPressed: _isUploading ? null : _captureAndUpload,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  textStyle: const TextStyle(fontSize: 16.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

