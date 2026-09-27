import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import '../models/prediction_result.dart';
import '../services/api_service.dart';
import '../services/hybrid_landmark_bridge.dart';
import '../state/session_provider.dart';
import '../state/vitals_provider.dart';
import '../theme/app_colors.dart';
import '../utils/chime_synthesizer.dart';
import '../utils/captured_file_cleanup.dart';
import '../utils/image_picker_helper.dart';
import '../utils/l10n_extension.dart';
import '../widgets/interactive_eye_logo.dart';

class AiScanScreen extends ConsumerStatefulWidget {
  final String childName;

  const AiScanScreen({
    Key? key,
    this.childName = 'Aarav',
  }) : super(key: key);

  @override
  ConsumerState<AiScanScreen> createState() => _AiScanScreenState();
}

enum _ScanState { scanner, mascot, measurements, result }

class _AiScanScreenState extends ConsumerState<AiScanScreen>
    with TickerProviderStateMixin {
  _ScanState _state = _ScanState.scanner;
  Uint8List?
      _pendingScanBytes; // photo captured, awaiting measurements confirmation
  Uint8List?
      _analyzingBytes; // image currently being analyzed (full-quality bytes)
  bool _soundsEnabled = false;
  bool _isScanning = false;
  int _selectedMascotIndex = 2; // Cheetah default
  PredictionResult? _lastPrediction;

  // Auto-capture uses face points plus shoulders and elbows, with no wrist or
  // lower-body requirement.
  bool _autoCaptureArmed = false;
  bool _autoCaptured = false;
  bool _frameStable = false;
  bool _isCapturing = false;
  LandmarkResult? _liveLandmarks;
  final ValueNotifier<LandmarkResult?> _liveLandmarksNotifier =
      ValueNotifier<LandmarkResult?>(null);
  bool _cameraFullscreenOpen = false;
  String _scanGuidance = 'Position the child in the frame';

  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  late AnimationController _spinController;

  late AnimationController _counterController;
  late Animation<double> _counterAnimation;

  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = const [];
  String? _cameraError;
  bool _isCameraReady = false;
  bool _samplingFrame = false;
  bool _captureInProgress = false;

  final List<Map<String, dynamic>> _mascots = [
    {
      'name': 'Albatross',
      'subtitle': 'Graceful Ocean Soarer',
      'emoji': 'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€šÃ‚ÂªÃƒâ€šÃ‚Â¶',
      'video': '/videos/albatross.mp4',
      'fallback': '/videos/video1.mp4',
    },
    {
      'name': 'Shark',
      'subtitle': 'Swift Friendly Swimmer',
      'emoji': 'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€šÃ‚Â¦Ãƒâ€¹Ã¢â‚¬Â ',
      'video': '/videos/shark.mp4',
      'fallback': '/videos/video2.mp4',
    },
    {
      'name': 'Cheetah',
      'subtitle': 'Lightning Fast Runner',
      'emoji': 'ÃƒÆ’Ã‚Â°Ãƒâ€¦Ã‚Â¸Ãƒâ€šÃ‚ÂÃƒÂ¢Ã¢â€šÂ¬Ã‚Â ',
      'video': '/videos/cheetah.mp4',
      'fallback': '/videos/video3.mp4',
    },
  ];

  final Map<int, VideoPlayerController> _mascotVideoControllers = {};
  final Set<int> _mascotVideoFailures = {};

  String _resolveFullUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    try {
      final origin = Uri.base.origin;
      if (origin.isNotEmpty && origin != 'null') {
        final cleanPath = path.startsWith('/') ? path : '/$path';
        return '$origin$cleanPath';
      }
    } catch (_) {}
    return path;
  }

  void _loadMascotVideo(int index) {
    if (_mascotVideoFailures.contains(index)) return;
    if (_mascotVideoControllers.containsKey(index)) {
      final controller = _mascotVideoControllers[index];
      if (controller != null && controller.value.isInitialized) {
        controller.seekTo(Duration.zero);
        controller.setVolume(0.0);
        controller.play();
      }
      return;
    }

    final primaryPath = _mascots[index]['video'] as String;
    final fullUrl = _resolveFullUrl(primaryPath);

    final Uri videoUri = Uri.parse(fullUrl);
    if (!videoUri.hasScheme || videoUri.host.isEmpty) {
      // The project has no bundled mascot videos. Relative web paths cannot be
      // passed to Android's network player; use the animated Flutter fallback.
      _mascotVideoFailures.add(index);
      return;
    }
    final controller = VideoPlayerController.networkUrl(videoUri);
    controller.initialize().then((_) {
      if (mounted) {
        setState(() {
          _mascotVideoControllers[index] = controller;
        });
        controller.setLooping(true);
        controller.setVolume(0.0);
        if (index == _selectedMascotIndex) {
          controller.play();
        }
      }
    }).catchError((err) {
      _mascotVideoFailures.add(index);
      debugPrint('Mascot video load error ($fullUrl): $err');
      if (mounted) setState(() {});
    });
  }

  void _selectMascot(int index) {
    playChime();
    _mascotVideoControllers.forEach((key, controller) {
      if (key != index) {
        controller.pause();
      }
    });

    setState(() {
      _selectedMascotIndex = index;
    });

    _loadMascotVideo(index);
  }

  @override
  void initState() {
    super.initState();
    // Laser up and down sweep
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
    _laserAnimation = CurvedAnimation(
      parent: _laserController,
      curve: Curves.easeInOut,
    );

    // Shutter button spin
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Result counters
    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _counterAnimation = CurvedAnimation(
      parent: _counterController,
      curve: Curves.easeOutCubic,
    );

    // AI scan overlay animations (visual only)
    _scanSweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    _scanPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _initializeCamera();
  }

  Future<void> _initializeCamera({CameraDescription? requestedCamera}) async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException(
            'NoCamera', 'No camera was found on this device.');
      }

      final selectedCamera = requestedCamera ??
          cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
            orElse: () => cameras.first,
          );
      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _availableCameras = cameras;
        _cameraController = controller;
        _isCameraReady = true;
        _cameraError = null;
        _autoCaptureArmed =
            kIsWeb || defaultTargetPlatform == TargetPlatform.android;
        _scanGuidance = _autoCaptureArmed
            ? 'Position the child in the frame'
            : 'Use the camera button to capture a photo';
      });
      if (_autoCaptureArmed) _startAutoCapturePolling();
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _cameraError = _cameraErrorMessage(error);
        _isCameraReady = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraError =
            'Camera access is unavailable. Check browser permissions.';
        _isCameraReady = false;
      });
    }
  }

  Future<void> _switchCamera() async {
    if (_captureInProgress || _isCapturing) return;
    final current = _cameraController;
    if (current == null || _availableCameras.length < 2) return;
    final currentLens = current.description.lensDirection;
    final next = _availableCameras.firstWhere(
      (camera) => camera.lensDirection != currentLens,
      orElse: () => _availableCameras.first,
    );
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = null;
    while (_samplingFrame && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    if (!mounted || _cameraController != current) return;
    setState(() {
      _cameraController = null;
      _isCameraReady = false;
      _setLiveLandmarks(null);
      _scanGuidance = 'Switching camera...';
    });
    await current.dispose();
    if (mounted) await _initializeCamera(requestedCamera: next);
  }

  Future<void> _openCameraFullscreen() async {
    final controller = _cameraController;
    if (!_isCameraReady || controller == null || _cameraFullscreenOpen) return;
    _cameraFullscreenOpen = true;
    try {
      await Navigator.of(context).push<void>(MaterialPageRoute<void>(
        builder: (_) => _FullScreenCameraView(
          controller: controller,
          landmarks: _liveLandmarksNotifier,
          mirrorX:
              controller.description.lensDirection == CameraLensDirection.front,
          fallbackImageSize: Size(
            controller.value.previewSize!.height,
            controller.value.previewSize!.width,
          ),
          onCapture: _captureAndAnalyze,
        ),
      ));
    } finally {
      _cameraFullscreenOpen = false;
    }
  }

  void _dismissCameraFullscreenForCapture() {
    if (!_cameraFullscreenOpen) return;
    _cameraFullscreenOpen = false;
    Navigator.of(context).pop();
  }

  void _setLiveLandmarks(LandmarkResult? landmarks) {
    _liveLandmarks = landmarks;
    _liveLandmarksNotifier.value = landmarks;
  }

  String _cameraErrorMessage(CameraException error) {
    switch (error.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
        return 'Camera permission was denied. Allow camera access to use AI Scan.';
      case 'CameraAccessRestricted':
        return 'Camera access is restricted on this device.';
      case 'CameraNotFound':
      case 'NoCamera':
        return 'No camera was found on this device.';
      default:
        return error.description ?? 'Camera access is unavailable.';
    }
  }

  // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Height/weight confirmation step (after photo, before analysis) ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
  // Values come from the existing vitals provider; nothing is fabricated.
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _ageYearsController = TextEditingController();
  final TextEditingController _ageMonthsController = TextEditingController();
  String? _selectedGender;
  final GlobalKey<FormState> _measurementsFormKey = GlobalKey<FormState>();
  bool _measurementsPreFilled = false;

  // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ Analysis overlay (purely visual progress; shows no fake results) ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
  late AnimationController _scanSweepController;
  late AnimationController _scanPulseController;
  Timer? _autoCaptureTimer;

  /// Pre-fill the confirmation fields from the most recent vitals record.
  /// A measurement the app does not have stays empty ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â no defaults.
  Future<void> _prepareMeasurementsStep() async {
    if (_measurementsPreFilled) return;

    var records = ref.read(vitalsProvider);
    final session = ref.read(sessionProvider);
    if (records.isEmpty &&
        session.childId != null &&
        session.accessToken != null) {
      try {
        await ref
            .read(vitalsProvider.notifier)
            .loadForChild(session.childId!, session.accessToken!);
        records = ref.read(vitalsProvider);
      } catch (error) {
        debugPrint('[SCAN] Could not load saved vitals: $error');
      }
    }

    // Screening history is newest first, but some rows may not contain a
    // measurement. Resolve each field independently from the latest saved
    // value so a newer partial screening cannot hide an older height/weight.
    final heightRecord = records.cast<VitalsRecord?>().firstWhere(
          (record) => record?.heightCm != null && record!.heightCm! > 0,
          orElse: () => null,
        );
    final weightRecord = records.cast<VitalsRecord?>().firstWhere(
          (record) => record?.weightKg != null && record!.weightKg! > 0,
          orElse: () => null,
        );
    final ageRecord = records.cast<VitalsRecord?>().firstWhere(
          (record) => record?.ageYears != null || record?.ageMonths != null,
          orElse: () => null,
        );
    final genderRecord = records.cast<VitalsRecord?>().firstWhere(
          (record) => record?.gender == 'Boy' || record?.gender == 'Girl',
          orElse: () => null,
        );

    if (_heightController.text.trim().isEmpty &&
        heightRecord?.heightCm != null) {
      _heightController.text = heightRecord!.heightCm!.toStringAsFixed(1);
    }
    if (_weightController.text.trim().isEmpty &&
        weightRecord?.weightKg != null) {
      _weightController.text = weightRecord!.weightKg!.toStringAsFixed(1);
    }
    if (_ageYearsController.text.trim().isEmpty &&
        ageRecord?.ageYears != null) {
      _ageYearsController.text = '${ageRecord!.ageYears}';
    }
    if (_ageMonthsController.text.trim().isEmpty &&
        ageRecord?.ageMonths != null) {
      _ageMonthsController.text = '${ageRecord!.ageMonths}';
    }
    if (_selectedGender == null && genderRecord != null) {
      _selectedGender = genderRecord.gender;
    }

    // Keep this retryable if no record has arrived, for example while the
    // session is still being restored or the backend was temporarily offline.
    _measurementsPreFilled = records.isNotEmpty;
  }

  void _startAnalyze() {
    if (!(_measurementsFormKey.currentState?.validate() ?? false)) return;
    FocusManager.instance.primaryFocus?.unfocus();
    _analyzePendingScan();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _ageYearsController.dispose();
    _ageMonthsController.dispose();
    _liveLandmarksNotifier.dispose();
    _autoCaptureTimer?.cancel();
    _scanSweepController.dispose();
    _scanPulseController.dispose();
    _cameraController?.dispose();
    for (final controller in _mascotVideoControllers.values) {
      controller.dispose();
    }
    _laserController.dispose();
    _spinController.dispose();
    _counterController.dispose();
    super.dispose();
  }

  /// Upload path: the picked image is shown FULL (contain) on the analysis
  /// view while the real backend runs; then the measurements step appears.
  void _triggerScan([Uint8List? providedBytes]) async {
    if (_isScanning) return;
    Uint8List? bytes = providedBytes;
    if (bytes == null || bytes.isEmpty) {
      bytes = await pickImageBytes();
    }

    if (bytes == null || bytes.isEmpty) {
      _showScanError(ApiException(
          'No image selected or captured. Please select an image to scan.'));
      return;
    }

    debugPrint('[SCAN] selected image bytes = ${bytes.length}');
    await _beginAnalysis(bytes);
  }

  /// Live-camera path: capture the current frame, then run the same analysis
  /// flow. Used by the shutter and by auto-capture.
  Future<void> _captureAndAnalyze() async {
    if (_isScanning ||
        _isCapturing ||
        _captureInProgress ||
        !_isCameraReady ||
        _cameraController == null) return;
    _isCapturing = true;
    _captureInProgress = true;
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = null;
    _dismissCameraFullscreenForCapture();
    while (_samplingFrame && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    if (!mounted || !_isCameraReady || _cameraController == null) {
      _captureInProgress = false;
      _isCapturing = false;
      return;
    }
    final controller = _cameraController!;
    _isCameraReady = false;
    try {
      final XFile imageFile = await controller.takePicture();
      final bytes = await imageFile.readAsBytes();
      await deleteCapturedFile(imageFile.path);
      await _finishCameraCapture(controller, bytes);
    } catch (camErr) {
      _cameraController = null;
      await controller.dispose();
      _isCapturing = false;
      debugPrint('Camera capture error: $camErr');
      _showScanError(
          ApiException('Could not capture the photo. Please try again.'));
    } finally {
      _captureInProgress = false;
    }
  }

  Future<void> _finishCameraCapture(
      CameraController controller, Uint8List capturedBytes) async {
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer = null;
    _isCameraReady = false;
    _cameraController = null;
    try {
      await controller.dispose();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _scanGuidance = 'Capturing...';
        _setLiveLandmarks(null);
      });
    }
    // These are the exact bytes from the frame whose landmarks passed the gate.
    await _beginAnalysis(capturedBytes);
  }

  /// Show the AI analysis view with the full image, run the real backend
  /// request, then continue to the measurements confirmation step.
  Future<void> _beginAnalysis(Uint8List bytes) async {
    await _prepareMeasurementsStep();
    if (!mounted) return;
    setState(() {
      _analyzingBytes = bytes;
      _isScanning = true;
      _state =
          _ScanState.scanner; // analysis overlay renders over the scanner view
    });
    _scanSweepController.repeat();
    _scanPulseController.repeat(reverse: true);

    try {
      final result = await ApiService.predictImage(
        bytes,
        filename: 'scan_${DateTime.now().millisecondsSinceEpoch}.jpg',
        fields: _anthropometricFields(),
      );
      if (!mounted) return;
      _scanSweepController.stop();
      _scanPulseController.stop();
      setState(() {
        _isScanning = false;
        _lastPrediction = result;
        _pendingScanBytes = bytes;
        _state = _ScanState.measurements;
      });
    } on ApiException catch (e) {
      _showScanError(e);
    } catch (e) {
      _showScanError(ApiException(
          'Unable to analyze this image. Please try another photo.'));
    }
  }

  void _showScanError(ApiException e) {
    if (!mounted) return;
    _spinController.stop();
    final shouldRestoreCamera = _cameraController == null;
    setState(() {
      _isScanning = false;
      _isCapturing = false;
      _captureInProgress = false;
      _autoCaptured = false;
      _analyzingBytes = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.message),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (shouldRestoreCamera) unawaited(_initializeCamera());
  }

  void _returnToScanner() {
    setState(() {
      _state = _ScanState.scanner;
      _pendingScanBytes = null;
      _analyzingBytes = null;
      _isCapturing = false;
      _captureInProgress = false;
      _autoCaptured = false;
      _setLiveLandmarks(null);
    });
    if (_cameraController == null || !_isCameraReady) {
      unawaited(_initializeCamera());
    } else if (_autoCaptureArmed) {
      _startAutoCapturePolling();
    }
  }

  /// Step 2 of the flow: run the real hybrid analysis on the confirmed photo
  /// with the height/weight values currently in the fields (edited or not).
  void _analyzePendingScan() async {
    if (_isScanning || _pendingScanBytes == null) return;
    setState(() {
      _isScanning = true;
    });
    _spinController.repeat();

    try {
      // Send the child's anthropometrics with the scan so the backend's
      // production hybrid pipeline (168-feature fusion) can use them. Any field
      // left out is safely imputed server-side (training-split medians).
      debugPrint('[SCAN] sending current image to /predict '
          '(bytes=${_pendingScanBytes!.length})');
      final result = await ApiService.predictImage(
        _pendingScanBytes!,
        fields: _anthropometricFields(),
      );

      if (!mounted) return;
      _spinController.stop();
      setState(() {
        _isScanning = false;
        _lastPrediction = result;
        _state = _ScanState.result;
      });
      _counterController.forward(from: 0.0);
    } on ApiException catch (e) {
      _showScanError(e);
    } catch (e) {
      _showScanError(ApiException(
          'Unable to connect to server. Please check the backend and try again.'));
    }
  }

  void _pickAndScanImage() async {
    final bytes = await pickImageBytes();
    if (bytes != null && bytes.isNotEmpty) {
      _triggerScan(bytes);
    }
  }

  // Analyze sampled preview captures. The first frame with every required
  // facial and upper-arm point starts capture immediately.

  void _startAutoCapturePolling() {
    _autoCaptureTimer?.cancel();
    _autoCaptureTimer =
        Timer.periodic(LiveLandmarkTuning.sampleInterval, (_) async {
      if (!mounted ||
          !_autoCaptureArmed ||
          _autoCaptured ||
          _isCapturing ||
          _isScanning ||
          _samplingFrame ||
          _captureInProgress) return;
      if (!_isCameraReady || _cameraController == null) return;

      _samplingFrame = true;
      XFile? sampleFile;
      try {
        final controller = _cameraController!;
        sampleFile = await controller.takePicture();
        final bytes = await sampleFile.readAsBytes();
        final landmarks = await HybridLandmarkBridge.extractLandmarks(bytes,
            allowNoFace: true);
        if (!mounted) return;

        final hasAnyLandmarks =
            landmarks.face.isNotEmpty || landmarks.pose.isNotEmpty;
        if (!landmarks.hasValidRequiredPoints) {
          setState(() {
            _setLiveLandmarks(hasAnyLandmarks ? landmarks : null);
            _frameStable = false;
            _scanGuidance = hasAnyLandmarks
                ? 'Show face, shoulders and elbows'
                : 'Move the child into view';
          });
          return;
        }

        setState(() {
          _setLiveLandmarks(landmarks);
          _frameStable = true;
          _scanGuidance = 'Child detected';
        });
        if (!_isCapturing) {
          _isCapturing = true;
          _autoCaptured = true;
          _captureInProgress = true;
          _autoCaptureTimer?.cancel();
          _autoCaptureTimer = null;
          await Future<void>.delayed(LiveLandmarkTuning.captureStatusDuration);
          if (mounted && _cameraController == controller) {
            setState(() => _scanGuidance = 'Capturing...');
            _dismissCameraFullscreenForCapture();
            await _finishCameraCapture(controller, bytes);
          }
        }
      } on HybridLandmarkException {
        _resetLiveLandmarkGate('Move the child into view');
      } on PlatformException catch (error) {
        debugPrint('[Landmarks] detector error: $error');
        _resetLiveLandmarkGate(kIsWeb
            ? 'Detector unavailable; check connection'
            : 'Move the child into view');
      } catch (error) {
        debugPrint('[Landmarks] frame processing error: $error');
        _resetLiveLandmarkGate(kIsWeb
            ? 'Detector unavailable; check connection'
            : 'Adjust position');
      } finally {
        if (sampleFile != null) {
          await deleteCapturedFile(sampleFile.path);
        }
        _samplingFrame = false;
      }
    });
  }

  void _resetLiveLandmarkGate(String message) {
    if (mounted) {
      setState(() {
        _setLiveLandmarks(null);
        _frameStable = false;
        _scanGuidance = message;
      });
    }
  }

  /// Anthropometric form fields for the hybrid API. Height/weight come from the
  /// confirmation fields (the values actually used for THIS scan ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â edited or
  /// pre-filled); the remaining fields come from the existing vitals record.
  /// Missing values are simply omitted and imputed server-side (training median).
  Map<String, String> _anthropometricFields() {
    final fields = <String, String>{};
    final height = double.tryParse(_heightController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    if (height != null && height > 0)
      fields['height_cm'] = height.toStringAsFixed(2);
    if (weight != null && weight > 0)
      fields['weight_kg'] = weight.toStringAsFixed(2);

    final years = int.tryParse(_ageYearsController.text.trim());
    final months = int.tryParse(_ageMonthsController.text.trim());
    if (years != null && years >= 0) fields['age_years'] = '$years';
    if (months != null && months >= 0 && months < 12)
      fields['age_months'] = '$months';
    if (_selectedGender != null) fields['gender'] = _selectedGender!;

    final records = ref.read(vitalsProvider);
    if (!fields.containsKey('gender')) {
      final genderRecord = records.cast<VitalsRecord?>().firstWhere(
            (record) => record?.gender != null,
            orElse: () => null,
          );
      if (genderRecord?.gender != null) {
        fields['gender'] = genderRecord!.gender!;
      }
    }
    final ageRecord = records.cast<VitalsRecord?>().firstWhere(
          (record) => record?.ageYears != null || record?.ageMonths != null,
          orElse: () => null,
        );
    if (ageRecord?.ageYears != null) {
      fields.putIfAbsent('age_years', () => '${ageRecord!.ageYears}');
    }
    if (ageRecord?.ageMonths != null) {
      fields.putIfAbsent('age_months', () => '${ageRecord!.ageMonths}');
    }
    // head_circumference_cm / muac_cm / waist_cm are not tracked in the app
    // yet; they are simply omitted and the backend imputes them.
    // Temporary data-flow trace (remove after verification)
    debugPrint('[SCAN] fields sent: $fields');
    return fields;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _buildBody(),
                  ),
                ),
              ],
            ),
            // Full-screen AI analysis overlay while the backend request runs.
            if (_isScanning && _analyzingBytes != null)
              _buildAnalyzingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF0C2417)),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const InteractiveEyeLogo(
                width: 26,
                color: Color(0xFF0C2417),
              ),
              const SizedBox(width: 6),
              const Text(
                'Ai Scan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0C2417),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE7DC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.wb_sunny_outlined,
                    size: 18, color: Color(0xFF0F3827)),
              ),
              const SizedBox(width: 8),
              const CircleAvatar(
                radius: 17,
                backgroundColor: Color(0xFF0C2417),
                child:
                    Icon(Icons.person_outline, size: 18, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cameraActionButton({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) =>
      Material(
        color: const Color(0xCC0C2417),
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white, size: 22),
        ),
      );

  Widget _buildBody() {
    switch (_state) {
      case _ScanState.scanner:
        return _buildScannerView();
      case _ScanState.mascot:
        return _buildMascotView();
      case _ScanState.measurements:
        return _buildMeasurementsView();
      case _ScanState.result:
        return _buildResultView();
    }
  }

  // 1. SCANNER VIEW (00:02 - 00:11 & 00:32 - 00:38)
  Widget _buildScannerView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Growth Scan',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0C2417)),
                ),
                const SizedBox(height: 2),
                Text(
                  'Position the child in the frame and keep them still.',
                  style:
                      const TextStyle(fontSize: 13, color: Color(0xFF556D5E)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Scan Frame Box
          Container(
            width: double.infinity,
            height: 310,
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAF8),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: const Color(0xFFD8E6D9), width: 2),
            ),
            child: Stack(
              children: [
                // Live camera preview starts as soon as the scan page opens.
                if (_isCameraReady && _cameraController != null)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _cameraController!.value.previewSize!.height,
                          height: _cameraController!.value.previewSize!.width,
                          child: CameraPreview(_cameraController!),
                        ),
                      ),
                    ),
                  ),
                if (_isCameraReady &&
                    _cameraController?.value.previewSize != null &&
                    _liveLandmarks != null)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _LiveLandmarkPainter(
                          landmarks: _liveLandmarks!,
                          imageSize: Size(
                            (_liveLandmarks!.imageWidth ??
                                    _cameraController!
                                        .value.previewSize!.height)
                                .toDouble(),
                            (_liveLandmarks!.imageHeight ??
                                    _cameraController!.value.previewSize!.width)
                                .toDouble(),
                          ),
                          mirrorX:
                              _cameraController!.description.lensDirection ==
                                  CameraLensDirection.front,
                        ),
                      ),
                    ),
                  ),
                if (_isCameraReady)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_availableCameras.length > 1)
                          _cameraActionButton(
                            tooltip:
                                _cameraController?.description.lensDirection ==
                                        CameraLensDirection.front
                                    ? 'Switch to back camera'
                                    : 'Switch to front camera',
                            icon: Icons.flip_camera_android,
                            onPressed: _switchCamera,
                          ),
                        const SizedBox(width: 8),
                        _cameraActionButton(
                          tooltip: 'View camera full screen',
                          icon: Icons.fullscreen,
                          onPressed: _openCameraFullscreen,
                        ),
                      ],
                    ),
                  ),

                if (!_isCameraReady)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAF8).withOpacity(0.92),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.videocam_outlined,
                                  size: 34, color: Color(0xFF0F3827)),
                              const SizedBox(height: 10),
                              Text(
                                _cameraError ?? 'Starting camera...',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF445B4E)),
                              ),
                              if (_cameraError != null) ...[
                                const SizedBox(height: 12),
                                TextButton.icon(
                                  onPressed: _initializeCamera,
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Try again'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // Corner Brackets
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CornerBracketPainter(),
                  ),
                ),

                // Animated Laser Line
                AnimatedBuilder(
                  animation: _laserAnimation,
                  builder: (context, child) {
                    final top = 30.0 + _laserAnimation.value * 230.0;
                    return Positioned(
                      top: top,
                      left: 20,
                      right: 20,
                      child: Column(
                        children: [
                          Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2AE196),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFF2AE196).withOpacity(0.8),
                                  blurRadius: 10,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Status pill
                Positioned(
                  bottom: 14,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.92),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: _frameStable
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF84CC16),
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(
                            _isScanning ? 'Processing scan...' : _scanGuidance,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0C2417)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Row with SOUNDS and Mascot Mode
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _soundsEnabled = !_soundsEnabled),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _soundsEnabled
                          ? const Color(0xFFECF7ED)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFD8E3D8)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _soundsEnabled
                                  ? Icons.volume_up
                                  : Icons.volume_off,
                              size: 16,
                              color: _soundsEnabled
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF7D9585),
                            ),
                            const SizedBox(width: 6),
                            const Text('SOUNDS',
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800)),
                          ],
                        ),
                        Container(
                          width: 34,
                          height: 20,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: _soundsEnabled
                                ? const Color(0xFF0F3827)
                                : const Color(0xFFCBD8CB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: _soundsEnabled
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _state = _ScanState.mascot),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFD8E3D8)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.auto_awesome,
                            size: 16, color: Color(0xFF059669)),
                        SizedBox(width: 6),
                        Text('Mascot Mode',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0C2417))),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const SizedBox(height: 8),

          // Big Shutter Button
          GestureDetector(
            onTap: _captureAndAnalyze,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF0F3827),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: _isScanning
                    ? RotationTransition(
                        turns: _spinController,
                        child: const Icon(Icons.sync,
                            color: Color(0xFF2AE196), size: 30),
                      )
                    : const Icon(Icons.camera_alt,
                        color: Colors.white, size: 30),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _isScanning
                ? context.l10n.scanAnalyzing
                : context.l10n.scanInstruction3,
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF556D5E)),
          ),
          const SizedBox(height: 4),
          // Minimal upload action: pick a real photo from this device and run
          // the same analysis path as the shutter (browser-compatible).
          TextButton.icon(
            onPressed: _isScanning ? null : _pickAndScanImage,
            icon: const Icon(Icons.upload_file,
                size: 16, color: Color(0xFF0F3827)),
            label: Text(
              context.l10n.scanUploadImage,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F3827)),
            ),
          ),
        ],
      ),
    );
  }

  // 2. MASCOT MODE (00:12 - 00:31)
  Widget _buildMascotView() {
    _loadMascotVideo(_selectedMascotIndex);
    final active = _mascots[_selectedMascotIndex];
    final activeController = _mascotVideoControllers[_selectedMascotIndex];
    final isVideoReady =
        activeController != null && activeController.value.isInitialized;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                const Text(
                  'INTERACTIVE MODE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF047857),
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Look here, ${widget.childName}!',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0C2417),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pick a mascot to keep ${widget.childName} focused.',
                  style:
                      const TextStyle(fontSize: 13.5, color: Color(0xFF556D5E)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 1. Animated Card Swap Deck Stack (Selector Deck)
          MascotCardSwapDeck(
            mascots: _mascots,
            selectedIndex: _selectedMascotIndex,
            onMascotSelected: (index) {
              _selectMascot(index);
            },
          ),
          const SizedBox(height: 18),

          // 2. DEDICATED FULL VIDEO FRAME (Plays the Clicked Mascot Video!)
          Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF09120D),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF3FFF80), width: 2),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3FFF80).withOpacity(0.24),
                  blurRadius: 22,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (isVideoReady)
                    FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: activeController.value.size.width > 0
                            ? activeController.value.size.width
                            : 320,
                        height: activeController.value.size.height > 0
                            ? activeController.value.size.height
                            : 240,
                        child: VideoPlayer(activeController),
                      ),
                    )
                  else
                    _MascotAnimationFallback(
                      emoji: active['emoji'] as String,
                      name: active['name'] as String,
                    ),

                  // Bottom Info & Status Bar
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black87,
                            Colors.black45,
                            Colors.transparent,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 21,
                                backgroundColor: Colors.white24,
                                child: Text(active['emoji'],
                                    style: const TextStyle(fontSize: 22)),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    active['name'],
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 19,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    active['subtitle'],
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3FFF80).withOpacity(0.18),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF3FFF80).withOpacity(0.6),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF3FFF80),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'PLAYING',
                                  style: TextStyle(
                                    color: Color(0xFF3FFF80),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),

          // 3. ACTION BUTTONS
          ElevatedButton.icon(
            onPressed: _triggerScan,
            icon: _isScanning
                ? RotationTransition(
                    turns: _spinController,
                    child:
                        const Icon(Icons.sync, color: Colors.white, size: 20),
                  )
                : const Icon(Icons.camera_alt, size: 20, color: Colors.white),
            label: Text(
              _isScanning ? 'SCANNING BIOMETRICS...' : 'START BIOMETRIC SCAN',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F3827),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 4,
              shadowColor: const Color(0xFF0F3827).withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 10),

          // Secondary Exit Button
          OutlinedButton.icon(
            onPressed: () => setState(() => _state = _ScanState.scanner),
            icon: const Icon(Icons.close, size: 16, color: Color(0xFF556D5E)),
            label: const Text(
              'Exit Distraction Mode',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0C2417),
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              side: const BorderSide(color: Color(0xFFD8E3D8)),
            ),
          ),
        ],
      ),
    );
  }

  // ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ AI ANALYSIS OVERLAY ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã‚ÂÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬
  // Shows the FULL selected/captured image (contain, aspect preserved) while
  // the production model runs. No decorative graphics obscure the child.
  Widget _buildAnalyzingOverlay() {
    return Positioned.fill(
      child: Container(
        color: const Color(0xFF0B1F15).withOpacity(0.97),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'AI GROWTH SCAN',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          color: Color(0xFF2AE196)),
                    ),
                    const Icon(Icons.graphic_eq,
                        size: 18, color: Color(0xFF2AE196)),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // 1. FULL image, aspect preserved, nothing cropped
                        Image.memory(
                          _analyzingBytes!,
                          fit: BoxFit.contain,
                          alignment: Alignment.center,
                        ),
                        // Sweeping scan line stays clear of the child's face.
                        AnimatedBuilder(
                          animation: _scanSweepController,
                          builder: (context, child) {
                            final y = MediaQuery.of(context).size.height *
                                0.55 *
                                _scanSweepController.value;
                            return Positioned(
                              left: 0,
                              right: 0,
                              top: y,
                              child: Container(
                                height: 2.5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2AE196),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF2AE196)
                                          .withOpacity(0.75),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // Honest status: what is actually happening
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10291C),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFF1F5C41)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Color(0xFF2AE196)),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Analyzing child\u2019s image...',
                        style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFCFF5E4)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Running the production hybrid model on this photo',
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF6FA88C)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 2b. HEIGHT/WEIGHT CONFIRMATION VIEW (photo captured, pre-analysis)
  Widget _buildMeasurementsView() {
    const fieldBorder = Color(0xFFD8E3D8);
    const labelColor = Color(0xFF556D5E);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Confirm Measurements',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0C2417)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Check the values below, edit if needed, then analyze.',
            style: TextStyle(fontSize: 13, color: labelColor),
          ),
          const SizedBox(height: 16),

          // Photo preview ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â FULL image, aspect preserved (this exact file is
          // what Analyze sends to /predict).
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              color: const Color(0xFF0B1F15),
              child: Image.memory(
                _pendingScanBytes!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Form(
            key: _measurementsFormKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _heightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Height (cm)',
                    hintText: 'Enter height in centimeters',
                    prefixIcon: const Icon(Icons.height,
                        size: 20, color: Color(0xFF0F3827)),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: fieldBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFF0F3827)),
                    ),
                  ),
                  validator: (value) {
                    final v = double.tryParse(value?.trim() ?? '');
                    if (v == null || v <= 0) {
                      return 'Enter a valid height in centimeters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _weightController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Weight (kg)',
                    hintText: 'Enter weight in kilograms',
                    prefixIcon: const Icon(Icons.monitor_weight_outlined,
                        size: 20, color: Color(0xFF0F3827)),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: fieldBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: Color(0xFF0F3827)),
                    ),
                  ),
                  validator: (value) {
                    final v = double.tryParse(value?.trim() ?? '');
                    if (v == null || v <= 0) {
                      return 'Enter a valid weight in kilograms';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _ageYearsController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                          labelText: 'Age (years)',
                          filled: true,
                          fillColor: Colors.white),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return null;
                        final age = int.tryParse(text);
                        return age == null || age > 18
                            ? 'Enter a valid age'
                            : null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _ageMonthsController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                          labelText: 'Extra months',
                          filled: true,
                          fillColor: Colors.white),
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.isEmpty) return null;
                        final months = int.tryParse(text);
                        return months == null || months > 11
                            ? 'Use 0ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œ11 months'
                            : null;
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(
                      labelText: 'Gender (optional)',
                      filled: true,
                      fillColor: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'Boy', child: Text('Boy')),
                    DropdownMenuItem(value: 'Girl', child: Text('Girl')),
                  ],
                  onChanged: (value) => setState(() => _selectedGender = value),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          ElevatedButton.icon(
            onPressed: _isScanning ? null : _startAnalyze,
            icon: _isScanning
                ? RotationTransition(
                    turns: _spinController,
                    child:
                        const Icon(Icons.sync, color: Colors.white, size: 20),
                  )
                : const Icon(Icons.camera_alt, size: 20, color: Colors.white),
            label: Text(
              _isScanning
                  ? context.l10n.scanAnalyzing.toUpperCase()
                  : context.l10n.scanCapturePhoto,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F3827),
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              elevation: 4,
              shadowColor: const Color(0xFF0F3827).withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 10),

          OutlinedButton.icon(
            onPressed: _isScanning ? null : _returnToScanner,
            icon: const Icon(Icons.close, size: 16, color: Color(0xFF556D5E)),
            label: Text(
              context.l10n.retakeButton,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0C2417),
              ),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              side: const BorderSide(color: Color(0xFFD8E3D8)),
            ),
          ),
        ],
      ),
    );
  }

  // 3. RESULT VIEW (00:39 - 00:50)
  Widget _buildResultView() {
    // ALL displayed values come from the real backend response (_lastPrediction)
    // and the real vitals state. There are no demo/fallback prediction values.
    final pred = _lastPrediction;
    final sessionChildName = ref.read(sessionProvider).childName;
    final childName = (sessionChildName != null && sessionChildName.isNotEmpty)
        ? sessionChildName
        : widget.childName;
    final String statusText = pred != null
        ? '$childName status: ${pred.status}'
        : '$childName status: Not available';
    final String confidenceText = pred?.confidence != null
        ? '${(pred!.confidence! * 100).toStringAsFixed(1)}% (model score)'
        : 'Not available';
    final String riskText = pred?.risk ?? 'Not available';
    final String recommendationText = pred?.recommendation ?? 'Not available';
    final isHealthy =
        pred != null && pred.prediction.toLowerCase() == 'healthy';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: AnimatedBuilder(
        animation: _counterAnimation,
        builder: (context, child) {
          // Show the exact height/weight values used for THIS scan (the user's
          // confirmed/edited confirmation-field values), falling back to the
          // latest vitals record only if the fields were never populated. Values
          // the app does not collect (MUAC, head circumference, waist) are shown
          // as not recorded instead of being fabricated.
          final height = double.tryParse(_heightController.text.trim())
              ?.toStringAsFixed(1);
          final weight = double.tryParse(_weightController.text.trim())
              ?.toStringAsFixed(1);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: isHealthy
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFEE2E2),
                child: Icon(
                  isHealthy
                      ? Icons.check_circle_outline
                      : Icons.warning_amber_rounded,
                  color: isHealthy
                      ? const Color(0xFF059669)
                      : const Color(0xFFDC2626),
                  size: 30,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                statusText,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0C2417)),
              ),
              const SizedBox(height: 4),
              Text(
                'AI Model Confidence: $confidenceText  ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€šÃ‚Â¢  $riskText',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF556D5E)),
              ),
              const SizedBox(height: 16),

              // Real Model Class Probabilities Breakdown
              if (pred != null && pred.probabilities.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: const Color(0xFFDCE6DC)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MODEL CLASSIFICATION PROBABILITIES',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF556D5E),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...pred.probabilities.entries.map((entry) {
                        final pct = (entry.value * 100).toStringAsFixed(1);
                        final isSelectedClass = entry.key.toLowerCase() ==
                            pred.prediction.toLowerCase();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: Text(
                                  entry.key.capitalize(),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isSelectedClass
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                    color: isSelectedClass
                                        ? const Color(0xFF0C2417)
                                        : const Color(0xFF445B4E),
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 5,
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: entry.value,
                                    backgroundColor: const Color(0xFFEAF1E9),
                                    color: isSelectedClass
                                        ? (isHealthy
                                            ? const Color(0xFF059669)
                                            : const Color(0xFFDC2626))
                                        : const Color(0xFF94A3B8),
                                    minHeight: 8,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 44,
                                child: Text(
                                  '$pct%',
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelectedClass
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: const Color(0xFF0C2417),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Measurements
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFDCE6DC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('LATEST MEASUREMENTS',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF556D5E),
                            letterSpacing: 0.8)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Weight',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF445B4E))),
                        Text(weight != null ? '$weight kg' : 'Not recorded',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: weight != null
                                    ? const Color(0xFF0C2417)
                                    : const Color(0xFF9AA79F))),
                      ],
                    ),
                    const Divider(height: 20, color: Color(0xFFEDF2ED)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Height',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF445B4E))),
                        Text(height != null ? '$height cm' : 'Not recorded',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: height != null
                                    ? const Color(0xFF0C2417)
                                    : const Color(0xFF9AA79F))),
                      ],
                    ),
                    const Divider(height: 20, color: Color(0xFFEDF2ED)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('MUAC',
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF445B4E))),
                        Row(
                          children: [
                            Text('Not recorded',
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF9AA79F))),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: isHealthy
                                      ? const Color(0xFFDCFCE7)
                                      : const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                pred?.status.toUpperCase() ?? 'N/A',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: isHealthy
                                        ? const Color(0xFF065F46)
                                        : const Color(0xFF991B1B)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Analysis Insights / Backend Recommendations
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFDCE6DC)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ANALYSIS INSIGHTS & RECOMMENDATION',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF556D5E),
                            letterSpacing: 0.8)),
                    const SizedBox(height: 8),
                    Text(
                      recommendationText,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF2C3D32), height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forestGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.restaurant_menu, size: 18),
                    SizedBox(width: 6),
                    Text('View Nutrition Plan',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14.5)),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              ElevatedButton(
                onPressed: _returnToScanner,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFF0C2417),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: const BorderSide(color: Color(0xFFD8E3D8)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.refresh, size: 18),
                    SizedBox(width: 6),
                    Text('Scan Again',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14.5)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CornerBracketPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF2AE196)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const arm = 26.0;
    const pad = 16.0;

    // TL
    canvas.drawLine(
        const Offset(pad, pad), const Offset(pad + arm, pad), paint);
    canvas.drawLine(
        const Offset(pad, pad), const Offset(pad, pad + arm), paint);

    // TR
    canvas.drawLine(Offset(size.width - pad, pad),
        Offset(size.width - pad - arm, pad), paint);
    canvas.drawLine(Offset(size.width - pad, pad),
        Offset(size.width - pad, pad + arm), paint);

    // BL
    canvas.drawLine(Offset(pad, size.height - pad),
        Offset(pad + arm, size.height - pad), paint);
    canvas.drawLine(Offset(pad, size.height - pad),
        Offset(pad, size.height - pad - arm), paint);

    // BR
    canvas.drawLine(Offset(size.width - pad, size.height - pad),
        Offset(size.width - pad - arm, size.height - pad), paint);
    canvas.drawLine(Offset(size.width - pad, size.height - pad),
        Offset(size.width - pad, size.height - pad - arm), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FullScreenCameraView extends StatelessWidget {
  final CameraController controller;
  final ValueListenable<LandmarkResult?> landmarks;
  final bool mirrorX;
  final Size fallbackImageSize;
  final VoidCallback onCapture;

  const _FullScreenCameraView({
    required this.controller,
    required this.landmarks,
    required this.mirrorX,
    required this.fallbackImageSize,
    required this.onCapture,
  });

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize!;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ClipRect(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: previewSize.height,
                height: previewSize.width,
                child: CameraPreview(controller),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ValueListenableBuilder<LandmarkResult?>(
                valueListenable: landmarks,
                builder: (context, result, _) {
                  if (result == null) return const SizedBox.shrink();
                  return CustomPaint(
                    painter: _LiveLandmarkPainter(
                      landmarks: result,
                      imageSize: Size(
                        (result.imageWidth?.toDouble() ??
                            fallbackImageSize.width),
                        (result.imageHeight?.toDouble() ??
                            fallbackImageSize.height),
                      ),
                      mirrorX: mirrorX,
                    ),
                  );
                },
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Material(
                  color: const Color(0xCC0C2417),
                  shape: const CircleBorder(),
                  child: IconButton(
                    tooltip: 'Close full screen camera',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 26),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.94),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Text(
                        'Frame the face, both shoulders and elbows',
                        style: TextStyle(
                          color: Color(0xFF0C2417),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Material(
                      color: const Color(0xFF0F3827),
                      shape: const CircleBorder(),
                      child: IconButton(
                        tooltip: 'Capture photo',
                        onPressed: onCapture,
                        iconSize: 32,
                        padding: const EdgeInsets.all(18),
                        icon: const Icon(Icons.camera_alt, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveLandmarkPainter extends CustomPainter {
  final LandmarkResult landmarks;
  final Size imageSize;
  final bool mirrorX;

  const _LiveLandmarkPainter({
    required this.landmarks,
    required this.imageSize,
    required this.mirrorX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || imageSize.isEmpty) return;
    final fitted = applyBoxFit(BoxFit.cover, imageSize, size);
    final source =
        Alignment.center.inscribe(fitted.source, Offset.zero & imageSize);
    final destination =
        Alignment.center.inscribe(fitted.destination, Offset.zero & size);
    Offset mapPoint(List<double> p) {
      final x = p[0] * imageSize.width;
      final y = p[1] * imageSize.height;
      var dx = destination.left +
          (x - source.left) / source.width * destination.width;
      final dy = destination.top +
          (y - source.top) / source.height * destination.height;
      if (mirrorX) dx = destination.left + destination.right - dx;
      return Offset(dx, dy);
    }

    final facePaint = Paint()..color = const Color(0xFF43FF5B);
    final posePaint = Paint()..color = const Color(0xFF42D9FF);
    final textLabels = <String, String>{
      '10': 'Forehead',
      '152': 'Chin',
      '33': 'Right eye',
      '263': 'Left eye',
      '234': 'Right cheek',
      '454': 'Left cheek',
      '61': 'Mouth',
      '291': 'Mouth',
      '127': 'Right jaw',
      '356': 'Left jaw',
      '11': 'Left shoulder',
      '12': 'Right shoulder',
      '13': 'Left elbow',
      '14': 'Right elbow',
      '15': 'Left wrist',
      '16': 'Right wrist',
    };

    void drawPoints(Map<String, List<double>> points, Paint paint) {
      for (final entry in points.entries) {
        if (entry.value.length < 2) continue;
        final point = mapPoint(entry.value);
        if (!destination.contains(point)) continue;
        canvas.drawCircle(point, 4, paint);
        final label = textLabels[entry.key];
        if (label == null) continue;
        final text = TextPainter(
          text: TextSpan(
              text: label,
              style: TextStyle(
                color: paint.color,
                fontSize: 9,
                fontWeight: FontWeight.w600,
                shadows: const [Shadow(color: Colors.black87, blurRadius: 2)],
              )),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout(maxWidth: 90);
        final labelOffset = Offset(
          (point.dx + 6)
              .clamp(destination.left, destination.right - text.width)
              .toDouble(),
          (point.dy - text.height - 3)
              .clamp(destination.top, destination.bottom - text.height)
              .toDouble(),
        );
        text.paint(canvas, labelOffset);
      }
    }

    drawPoints(landmarks.face, facePaint);
    drawPoints(landmarks.pose, posePaint);
  }

  @override
  bool shouldRepaint(covariant _LiveLandmarkPainter oldDelegate) =>
      oldDelegate.landmarks != landmarks ||
      oldDelegate.imageSize != imageSize ||
      oldDelegate.mirrorX != mirrorX;
}

class _MascotAnimationFallback extends StatefulWidget {
  final String emoji;
  final String name;

  const _MascotAnimationFallback({required this.emoji, required this.name});

  @override
  State<_MascotAnimationFallback> createState() =>
      _MascotAnimationFallbackState();
}

class _MascotAnimationFallbackState extends State<_MascotAnimationFallback>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ScaleTransition(
            scale: Tween<double>(begin: 0.92, end: 1.08).animate(
              CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
            ),
            child: Text(widget.emoji, style: const TextStyle(fontSize: 76)),
          ),
          const SizedBox(height: 12),
          Text(widget.name,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('Animated mascot preview',
              style: TextStyle(color: Colors.white60, fontSize: 12)),
        ]),
      );
}

class MascotCardSwapDeck extends StatefulWidget {
  final List<Map<String, dynamic>> mascots;
  final int selectedIndex;
  final Function(int) onMascotSelected;

  const MascotCardSwapDeck({
    Key? key,
    required this.mascots,
    required this.selectedIndex,
    required this.onMascotSelected,
  }) : super(key: key);

  @override
  State<MascotCardSwapDeck> createState() => _MascotCardSwapDeckState();
}

class _MascotCardSwapDeckState extends State<MascotCardSwapDeck>
    with SingleTickerProviderStateMixin {
  late List<int> _order;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _order = List.generate(widget.mascots.length, (i) => i);
    // Align deck so top card matches selectedIndex on load
    while (_order[0] != widget.selectedIndex) {
      final top = _order.removeAt(0);
      _order.add(top);
    }

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _animController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        if (mounted) {
          _animController.reset();
        }
      }
    });
  }

  void _onCardTap(int mascotIndex) {
    if (!_animController.isAnimating) {
      if (_order[0] != mascotIndex) {
        setState(() {
          while (_order[0] != mascotIndex) {
            final top = _order.removeAt(0);
            _order.add(top);
          }
        });
        _animController.forward();
      }
      widget.onMascotSelected(mascotIndex);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        height: 310,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) {
            final t = CurvedAnimation(
              parent: _animController,
              curve: Curves.elasticOut,
            ).value;

            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: List.generate(_order.length, (i) {
                final slotIndex = _order.length - 1 - i; // 2, 1, 0
                final mascotIndex = _order[slotIndex];
                return _buildCard(slotIndex, mascotIndex, t);
              }),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCard(int slotIndex, int mascotIndex, double t) {
    // Spatial positioning (Straight card stack alignment)
    double xOffset = (1 - slotIndex) * 16.0;
    double yOffset = (1 - slotIndex) * 16.0;
    double scale = 1.0 - (slotIndex * 0.05);

    if (slotIndex == 0 && _animController.isAnimating) {
      yOffset += t * 450.0; // Drop front card straight down out of view
    } else if (slotIndex > 0 && _animController.isAnimating) {
      xOffset -= (16.0 * t); // Slide left-forward to next slot
      yOffset += (16.0 * t);
      scale += (0.05 * t);
    }

    final mascot = widget.mascots[mascotIndex];
    final isSelected = mascotIndex == widget.selectedIndex;

    // Distinct theme gradients for each mascot image card
    final List<List<Color>> mascotGradients = [
      [
        const Color(0xFF0F3827),
        const Color(0xFF0369A1),
        const Color(0xFF0C4A6E)
      ], // Albatross
      [
        const Color(0xFF0F3827),
        const Color(0xFF0F766E),
        const Color(0xFF164E63)
      ], // Shark
      [
        const Color(0xFF0F3827),
        const Color(0xFFB45309),
        const Color(0xFF78350F)
      ], // Cheetah
    ];

    final cardColors = mascotGradients[mascotIndex % mascotGradients.length];

    return Align(
      alignment: Alignment.center,
      child: Transform(
        transform: Matrix4.identity()
          ..translate(xOffset, yOffset)
          ..scale(scale),
        alignment: Alignment.center,
        child: GestureDetector(
          onTap: () => _onCardTap(mascotIndex),
          child: Container(
            width: 285,
            height: 270,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: (isSelected && slotIndex == 0)
                    ? const Color(0xFF3FFF80)
                    : Colors.white30,
                width: (isSelected && slotIndex == 0) ? 2.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(slotIndex == 0 ? 0.35 : 0.18),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // High-Definition Gradient Background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: cardColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),

                  // Center Mascot Emoji Artwork Card Design
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.14),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white30,
                              width: 1.5,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Text(
                            mascot['emoji'] as String,
                            style: const TextStyle(fontSize: 60),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3FFF80).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color:
                                    const Color(0xFF3FFF80).withOpacity(0.6)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.play_circle_fill,
                                  size: 13, color: Color(0xFF3FFF80)),
                              SizedBox(width: 4),
                              Text(
                                'TAP TO PLAY VIDEO',
                                style: TextStyle(
                                  color: Color(0xFF3FFF80),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Gradient Typography Overlay
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.black87,
                            Colors.black45,
                            Colors.transparent,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            mascot['name'] as String,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (slotIndex == 0) ...[
                            const SizedBox(height: 2),
                            Text(
                              mascot['subtitle'] as String,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
