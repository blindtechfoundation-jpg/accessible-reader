import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
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
  String _statusMessage = 'Ready';
  bool _isPlaying = false;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _configureTts();
  }

  @override
  void dispose() {
    flutterTts.stop();
    super.dispose();
  }

  Future<void> _configureTts() async {
    try {
      flutterTts.setStartHandler(() {
        if (!mounted) return;
        setState(() {
          _isPlaying = true;
          _statusMessage = 'Playing audio';
        });
      });

      flutterTts.setCompletionHandler(() {
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _statusMessage = 'Playback complete';
        });
      });

      flutterTts.setPauseHandler(() {
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _statusMessage = 'Paused';
        });
      });

      flutterTts.setCancelHandler(() {
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _statusMessage = 'Playback stopped';
        });
      });

      flutterTts.setErrorHandler((message) {
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _isBusy = false;
          _statusMessage = 'Text-to-speech is unavailable on this device.';
        });
      });

      await flutterTts.setLanguage('en-US');
      await flutterTts.setSpeechRate(0.55);
      await flutterTts.setVolume(1.0);
      await flutterTts.setPitch(1.0);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _statusMessage = 'Text-to-speech is unavailable on this device.';
        _isPlaying = false;
        _isBusy = false;
      });
    }
  }

  Future<void> _safeSpeak(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _isBusy = true;
      _statusMessage = 'Speaking...';
    });

    try {
      await flutterTts.stop();
      await flutterTts.speak(cleanText);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _isPlaying = false;
        _statusMessage = 'Speech is unavailable on this device.';
      });
      return;
    }

    if (mounted) {
      setState(() {
        _isBusy = false;
        _isPlaying = true;
      });
    }
  }

  Future<void> _scanBookPhoto() async {
    if (_isBusy) return;

    setState(() {
      _isBusy = true;
      _statusMessage = 'Scanning page...';
    });

    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (photo == null) {
        if (!mounted) return;
        setState(() {
          _isBusy = false;
          _statusMessage = 'No photo selected.';
        });
        return;
      }

      final inputImage = InputImage.fromFilePath(photo.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      try {
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        if (!mounted) return;
        setState(() {
          _extractedText = recognizedText.text.trim().isEmpty
              ? 'No readable text detected on this page.'
              : recognizedText.text.trim();
          _statusMessage = 'Page scanned successfully';
        });
        await _safeSpeak(_extractedText);
      } finally {
        await textRecognizer.close();
      }
    } on PlatformException catch (_) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _statusMessage = 'Camera access or OCR is unavailable on this device.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isBusy = false;
        _statusMessage = 'Failed to scan the page.';
      });
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isBusy) return;

    if (_isPlaying) {
      try {
        await flutterTts.stop();
      } catch (_) {
        // Ignore stop failures; this is safe on unsupported devices.
      }
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _statusMessage = 'Playback stopped';
      });
      return;
    }

    if (_extractedText.trim().isEmpty || _extractedText == "No document loaded. Tap 'Scan Book Page' to photograph a printed page.") {
      if (!mounted) return;
      setState(() => _statusMessage = 'No text available to play.');
      return;
    }

    await _safeSpeak(_extractedText);
  }

  Future<void> _copyText() async {
    if (_extractedText.trim().isEmpty) {
      if (!mounted) return;
      setState(() => _statusMessage = 'There is no text to copy.');
      return;
    }

    try {
      await Clipboard.setData(ClipboardData(text: _extractedText));
      HapticFeedback.vibrate();
      if (!mounted) return;
      setState(() => _statusMessage = 'Text copied to clipboard');
      await _safeSpeak('Text copied to clipboard');
    } catch (_) {
      if (!mounted) return;
      setState(() => _statusMessage = 'Copy failed on this device.');
    }
  }

  Future<void> _shareText() async {
    if (_extractedText.trim().isEmpty) {
      if (!mounted) return;
      setState(() => _statusMessage = 'There is no text to share.');
      return;
    }

    try {
      await Share.share(_extractedText, subject: 'Extracted Book Text');
      if (!mounted) return;
      setState(() => _statusMessage = 'Text shared');
    } catch (_) {
      if (!mounted) return;
      setState(() => _statusMessage = 'Share is unavailable on this device.');
    }
  }

  Future<void> _saveAsAudio() async {
    if (_extractedText.trim().isEmpty) {
      if (!mounted) return;
      setState(() => _statusMessage = 'There is no text to export.');
      return;
    }

    try {
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String filePath = '${appDocDir.path}/reading_${DateTime.now().millisecondsSinceEpoch}.wav';
      final String result = await flutterTts.synthesizeToFile(_extractedText, filePath);
      if (!mounted) return;
      setState(() {
        _statusMessage = result.isEmpty ? 'Audio file saved successfully' : 'Audio file saved successfully';
      });
      await _safeSpeak('Audio file saved successfully');
    } catch (_) {
      if (!mounted) return;
      setState(() => _statusMessage = 'Audio export is unavailable on this device.');
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
                      child: SelectableText(
                        _extractedText,
                        style: const TextStyle(fontSize: 20, color: Colors.white, height: 1.4),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    if (_isBusy)
                      const Padding(
                        padding: EdgeInsets.only(right: 10),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        _statusMessage,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _accessibleButton('Scan Book Page', Icons.camera_alt, _isBusy ? null : _scanBookPhoto),
                  _accessibleButton(
                    _isPlaying ? 'Pause Audio' : 'Play Audio',
                    _isPlaying ? Icons.pause : Icons.play_arrow,
                    _isBusy ? null : _togglePlayPause,
                  ),
                  _accessibleButton('Copy Text', Icons.copy, _isBusy ? null : _copyText),
                  _accessibleButton('Share Text', Icons.share, _isBusy ? null : _shareText),
                  _accessibleButton('Download Audio', Icons.download, _isBusy ? null : _saveAsAudio),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accessibleButton(String label, IconData icon, VoidCallback? onPressed) {
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
