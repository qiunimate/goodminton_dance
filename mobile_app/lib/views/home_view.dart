import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:goodminton_mobile/logic/game_engine.dart';
import 'package:goodminton_mobile/utils/camera_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

class HomeView extends StatefulWidget {
  final List<CameraDescription> cameras;

  const HomeView({Key? key, required this.cameras}) : super(key: key);

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  CameraController? _controller;
  late PoseDetector _poseDetector;
  bool _isBusy = false;
  late GameEngine _gameEngine;
  late FlutterTts _flutterTts;
  String _handedness = 'R'; // Default Right
  String _currentInstruction =
      "Please ensure your whole body is visible in the frame!";
  int _instructionCounter = 0; // To force animation even for same text
  bool _isBodyVisible = false;
  String _statusMessage = "";

  @override
  void initState() {
    super.initState();
    _loadHandedness();
    _gameEngine = GameEngine();
    _initTts();
    _initPoseDetector();
    _initCamera();
  }

  Future<void> _loadHandedness() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _handedness = prefs.getString('handedness') ?? 'R';
    });
  }

  Future<void> _saveHandedness(String handedness) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('handedness', handedness);
  }

  void _initTts() {
    _flutterTts = FlutterTts();
    _flutterTts.setLanguage("en-US");
    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);

    // Set error handler
    _flutterTts.setErrorHandler((msg) {
      print("TTS Error: $msg");
    });

    _flutterTts.setCompletionHandler(() {
      print("TTS Completion");
    });

    _flutterTts.setStartHandler(() {
      print("TTS Start");
    });
  }

  void _initPoseDetector() {
    final options = PoseDetectorOptions(mode: PoseDetectionMode.stream);
    _poseDetector = PoseDetector(options: options);
  }

  Future<void> _initCamera() async {
    if (widget.cameras.isEmpty) return;

    // Use front camera by default if available
    CameraDescription camera = widget.cameras.first;
    for (var c in widget.cameras) {
      if (c.lensDirection == CameraLensDirection.front) {
        camera = c;
        break;
      }
    }

    _controller = CameraController(
      camera,
      ResolutionPreset.low, // Lower resolution for faster processing
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.nv21
          : ImageFormatGroup.bgra8888,
    );

    await _controller!.initialize();
    if (!mounted) return;

    // Start streaming
    _controller!.startImageStream(_processCameraImage);
    setState(() {});
  }

  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;

    try {
      final camera = _controller!.description;
      final rotation =
          InputImageRotationValue.fromRawValue(camera.sensorOrientation) ??
              InputImageRotation.rotation0deg;

      final inputImage =
          CameraUtils.inputImageFromCameraImage(image, camera, rotation);

      final poses = await _poseDetector.processImage(inputImage);
      if (poses.isNotEmpty) {
        _processPose(poses.first);
      } else {
        // No body detected
        if (_isBodyVisible) {
          setState(() {
            _isBodyVisible = false;
            _currentInstruction =
                "Please ensure your whole body is visible in the frame!";
            _instructionCounter++;
          });
        }
      }
    } catch (e) {
      print("Error processing image: $e");
    } finally {
      _isBusy = false;
    }
  }

  void _processPose(Pose pose) {
    // Get landmarks
    final landmarks = pose.landmarks;

    // Determine landmarks based on handedness
    PoseLandmark wrist;
    PoseLandmark shoulder;
    PoseLandmark hip;

    if (_handedness == 'R') {
      wrist = landmarks[PoseLandmarkType.rightWrist]!;
      shoulder = landmarks[PoseLandmarkType.rightShoulder]!;
      hip = landmarks[PoseLandmarkType.rightHip]!;
    } else {
      wrist = landmarks[PoseLandmarkType.leftWrist]!;
      shoulder = landmarks[PoseLandmarkType.leftShoulder]!;
      hip = landmarks[PoseLandmarkType.leftHip]!;
    }

    // Check visibility
    if (wrist.likelihood < 0.5 ||
        shoulder.likelihood < 0.5 ||
        hip.likelihood < 0.5) {
      // Body not fully visible
      if (_isBodyVisible) {
        setState(() {
          _isBodyVisible = false;
          _currentInstruction =
              "Please ensure your whole body is visible in the frame!";
          _instructionCounter++;
        });
      }
      return;
    }

    // Person detected and joints are visible
    if (!_isBodyVisible) {
      setState(() {
        _isBodyVisible = true;
        _gameEngine.reset();
      });
    }

    // Logic: wrist_y < threshold (Midpoint)
    // Note: In ML Kit, Y coordinates are in pixels relative to image.
    // 0 is top.

    final thresholdY = (shoulder.y + hip.y) / 2;

    // Check "Hand Up" (Wrist ABOVE threshold -> Y is SMALLER)
    bool isHandUp = wrist.y < thresholdY;

    // Check "Hand Down" (Wrist BELOW threshold -> Y is LARGER)
    bool isHandDown = wrist.y > thresholdY;

    bool shouldSpeak = _gameEngine.update(isHandUp, isHandDown);

    if (shouldSpeak && _gameEngine.currentMove != null) {
      final instruction = _gameEngine.currentMove!.getInstruction(_handedness);
      print("TTS Speaking: $instruction");
      _updateInstructionUI(instruction);
      _flutterTts.speak(instruction);
    }

    // Update status for debugging/UI
    if (mounted) {
      // Optional: Update UI less frequently to avoid lag?
      // For now, let's just update basic status
    }
  }

  void _updateInstructionUI(String instruction) {
    if (mounted) {
      setState(() {
        _currentInstruction = instruction;
        _instructionCounter++;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || !_controller!.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Mapping of instruction to alignment on the court image
    // 1: front right, 2: back right, 3: back left, 4: front left
    final Map<String, Alignment> pointAlignments = {
      "1": const Alignment(0.6, -0.6), // front right
      "2": const Alignment(0.6, 0.6), // back right
      "3": const Alignment(-0.6, 0.6), // back left
      "4": const Alignment(-0.6, -0.6), // front left
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text("Footwork Trainer"),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ToggleButtons(
              borderRadius: BorderRadius.circular(8),
              borderWidth: 2,
              borderColor: Colors.blueGrey,
              selectedBorderColor: Colors.blue,
              fillColor: Colors.blue.withOpacity(0.2),
              selectedColor: const Color.fromARGB(255, 4, 28, 160),
              color: Colors.black54,
              constraints: const BoxConstraints(minWidth: 60, minHeight: 40),
              isSelected: [_handedness == 'L', _handedness == 'R'],
              onPressed: (index) {
                final newHandedness = index == 1 ? 'R' : 'L';
                setState(() {
                  _handedness = newHandedness;
                });
                _saveHandedness(newHandedness);
              },
              children: const [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Left',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'handed',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Right',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'handed',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Display Camera Preview if body is NOT visible, otherwise show Court Image
          Expanded(
            child: Center(
              child: _isBodyVisible
                  ? Stack(
                      children: [
                        // Court Image
                        Image.asset(
                          'assets/images/half_court.png',
                          fit: BoxFit.contain,
                        ),

                        // Red Point Overlay
                        if (pointAlignments.containsKey(_currentInstruction))
                          Positioned.fill(
                            child: Align(
                              alignment: pointAlignments[_currentInstruction]!,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Container(
                                  key: ValueKey<int>(_instructionCounter),
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black45,
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final screenWidth = constraints.maxWidth;
                        final screenHeight = constraints.maxHeight;

                        // Calculate preview dimensions to fit within screen bounds
                        final cameraRatio = _controller!.value.aspectRatio;

                        double previewWidth, previewHeight;

                        if (screenHeight > screenWidth) {
                          // Portrait mode
                          previewWidth = screenWidth;
                          previewHeight = screenWidth * cameraRatio;
                          if (previewHeight > screenHeight) {
                            previewHeight = screenHeight;
                            previewWidth = screenHeight * cameraRatio;
                          }
                        } else {
                          // Landscape mode
                          previewHeight = screenHeight;
                          previewWidth = screenHeight * cameraRatio;
                          if (previewWidth > screenWidth) {
                            previewWidth = screenWidth;
                            previewHeight = screenWidth / cameraRatio;
                          }
                        }

                        return SizedBox(
                          width: previewWidth,
                          height: previewHeight,
                          child: CameraPreview(_controller!),
                        );
                      },
                    ),
            ),
          ),

          // bottom info container
          Container(
            width: double.infinity,
            color: Colors.black54,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Text(
                    _currentInstruction,
                    key: ValueKey<int>(_instructionCounter),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48, // Increased size for better visibility
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
