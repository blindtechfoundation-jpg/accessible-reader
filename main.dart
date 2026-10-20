import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  runApp(const AccessibleReaderApp());
}

class AccessibleReaderApp extends StatelessWidget {
  const AccessibleReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Accessible Reader',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primarySwatch: Colors.amber,
      ),
      home: const ReaderHomeScreen(),
    );
  }
}

class ReaderHomeScreen extends StatefulWidget {
  const ReaderHomeScreen({super.key});

  @override
  State<ReaderHomeScreen> createState() => _ReaderHomeScreenState();
}

class _ReaderHomeScreenState extends State<ReaderHomeScreen> {
  final FlutterTts flutterTts = FlutterTts();
  final ImagePicker _picker = ImagePicker();
  String _extractedText = "No document loaded. Tap 'Scan Book Page' to photograph a printed page.";
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    flutterTts.setCompletionHandler(() {
      setState(() => _isPlaying = false);
    });
  }

  Future<void> _scanBookPhoto() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo == null) return;

    final inputImage = InputImage.fromFilePath(photo.path);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    await textRecognizer.close();

    setState(() {
      _extractedText = recognizedText.text.isEmpty
          ? "No readable text detected on this page."
          : recognizedText.text;
    });

    _speak(_extractedText);
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await flutterTts.stop();
      setState(() => _isPlaying = false);
    } else {
      if (_extractedText.isNotEmpty) {
        await flutterTts.setSpeechRate(0.5);
        await flutterTts.speak(_extractedText);
        setState(() => _isPlaying = true);
      }
    }
  }

  Future<void> _speak(String text) async {
    await flutterTts.stop();
    await flutterTts.speak(text);
    setState(() => _isPlaying = true);
  }

  void _copyText() {
    Clipboard.setData(ClipboardData(text: _extractedText));
    HapticFeedback.vibrate();
    _speak("Text copied to clipboard");
  }

  void _shareText() {
    Share.share(_extractedText, subject: 'Extracted Book Text');
  }

  Future<void> _saveAsAudio() async {
    try {
      Directory appDocDir = await getApplicationDocumentsDirectory();
      String filePath = '${appDocDir.path}/reading_${DateTime.now().millisecondsSinceEpoch}.wav';
      await flutterTts.synthesizeToFile(_extractedText, filePath);
      _speak("Audio file saved successfully");
    } catch (e) {
      _speak("Failed to save audio file");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accessible Book Reader'),
        backgroundColor: Colors.amber[800],
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.withOpacity(0.5)),
                  ),
                  child: SingleChildScrollView(
                    child: Semantics(
                      label: "Document content: $_extractedText",
                      child: Text(
                        _extractedText,
                        style: const TextStyle(fontSize: 20, color: Colors.white, height: 1.4),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _accessibleButton("Scan Book Page", Icons.camera_alt, _scanBookPhoto),
                  _accessibleButton(_isPlaying ? "Pause Audio" : "Play Audio", _isPlaying ? Icons.pause : Icons.play_arrow, _togglePlayPause),
                  _accessibleButton("Copy Text", Icons.copy, _copyText),
                  _accessibleButton("Share Text", Icons.share, _shareText),
                  _accessibleButton("Download Audio", Icons.download, _saveAsAudio),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accessibleButton(String label, IconData icon, VoidCallback onPressed) {
    return Semantics(
      label: label,
      button: true,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          backgroundColor: Colors.amber,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 24),
        label: Text(label),
      ),
    );
  }
}
