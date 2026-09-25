import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import '../models/prediction_result.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../utils/chime_synthesizer.dart';
import '../utils/image_picker_helper.dart';
import '../widgets/interactive_eye_logo.dart';

class AiScanScreen extends StatefulWidget {
  final String childName;

  const AiScanScreen({
    Key? key,
    this.childName = 'Aarav',
  }) : super(key: key);

  @override
  State<AiScanScreen> createState() => _AiScanScreenState();
}

enum _ScanState { scanner, mascot, result }

class _AiScanScreenState extends State<AiScanScreen>
    with TickerProviderStateMixin {
  _ScanState _state = _ScanState.scanner;
  bool _soundsEnabled = false;
  bool _isScanning = false;
  int _selectedMascotIndex = 2; // Cheetah default
  PredictionResult? _lastPrediction;
  String? _errorMessage;

  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  late AnimationController _spinController;

  late AnimationController _counterController;
  late Animation<double> _counterAnimation;

  CameraController? _cameraController;
  String? _cameraError;
  bool _isCameraReady = false;

  final List<Map<String, dynamic>> _mascots = [
    {
      'name': 'Albatross',
      'subtitle': 'Graceful Ocean Soarer',
      'emoji': '🪶',
      'video': '/videos/albatross.mp4',
      'fallback': '/videos/video1.mp4',
    },
    {
      'name': 'Shark',
      'subtitle': 'Swift Friendly Swimmer',
      'emoji': '🦈',
      'video': '/videos/shark.mp4',
      'fallback': '/videos/video2.mp4',
    },
    {
      'name': 'Cheetah',
      'subtitle': 'Lightning Fast Runner',
      'emoji': '🐆',
      'video': '/videos/cheetah.mp4',
      'fallback': '/videos/video3.mp4',
    },
  ];

  final Map<int, VideoPlayerController> _mascotVideoControllers = {};

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
      debugPrint('Mascot video load error ($fullUrl): $err');
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
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException(
            'NoCamera', 'No camera was found on this device.');
      }

      final preferredCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        preferredCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _isCameraReady = true;
        _cameraError = null;
      });
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

  @override
  void dispose() {
    _cameraController?.dispose();
    for (final controller in _mascotVideoControllers.values) {
      controller.dispose();
    }
    _laserController.dispose();
    _spinController.dispose();
    _counterController.dispose();
    super.dispose();
  }

  void _triggerScan([Uint8List? providedBytes]) async {
    if (_isScanning) return;
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });
    _spinController.repeat();

    try {
      Uint8List? bytes = providedBytes;
      if (bytes == null && _isCameraReady && _cameraController != null) {
        try {
          final XFile imageFile = await _cameraController!.takePicture();
          bytes = await imageFile.readAsBytes();
        } catch (camErr) {
          debugPrint('Camera capture error: $camErr');
        }
      }

      if (bytes == null || bytes.isEmpty) {
        bytes = await pickImageBytes();
      }

      if (bytes == null || bytes.isEmpty) {
        throw ApiException('No image selected or captured. Please select an image to scan.');
      }

      final result = await ApiService.predictImage(bytes);

      if (!mounted) return;
      _spinController.stop();
      setState(() {
        _isScanning = false;
        _lastPrediction = result;
        _state = _ScanState.result;
      });
      _counterController.forward(from: 0.0);
    } catch (e) {
      if (!mounted) return;
      _spinController.stop();
      final msg = e is ApiException
          ? e.message
          : 'Unable to connect to server. Please check the backend and try again.';
      setState(() {
        _isScanning = false;
        _errorMessage = msg;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _pickAndScanImage() async {
    final bytes = await pickImageBytes();
    if (bytes != null && bytes.isNotEmpty) {
      _triggerScan(bytes);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
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

  Widget _buildBody() {
    switch (_state) {
      case _ScanState.scanner:
        return _buildScannerView();
      case _ScanState.mascot:
        return _buildMascotView();
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
                  'Position ${widget.childName} inside the guide frame below.',
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

                // Dashed child silhouette symbol
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ChildSilhouettePainter(),
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
                              decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(
                            _isScanning
                                ? 'Scanning Biometrics...'
                                : 'Aligning Posture',
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

          // Big Shutter Button
          GestureDetector(
            onTap: _triggerScan,
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
            _isScanning ? 'Processing scan...' : 'Tap shutter to scan',
            style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.bold,
                color: Color(0xFF556D5E)),
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
    final isVideoReady = activeController != null && activeController.value.isInitialized;

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
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3FFF80).withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Text(active['emoji'],
                                style: const TextStyle(fontSize: 48)),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Loading ${active['name']}...',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Initializing Mascot Stream',
                            style:
                                TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
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
                    child: const Icon(Icons.sync, color: Colors.white, size: 20),
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




  // 3. RESULT VIEW (00:39 - 00:50)
  Widget _buildResultView() {
    final pred = _lastPrediction;
    final String statusText = pred != null
        ? '${widget.childName} status: ${pred.status}'
        : '${widget.childName} is growing normally';
    final String confidenceText = pred != null
        ? '${(pred.confidence * 100).toStringAsFixed(1)}%'
        : '95.2%';
    final String riskText = pred?.risk ?? 'Low Risk';
    final String recommendationText = pred?.recommendation ??
        '${widget.childName} is tracking well on growth curves. Maintain balanced nutrition.';
    final isHealthy = pred == null || pred.prediction.toLowerCase() == 'healthy';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: AnimatedBuilder(
        animation: _counterAnimation,
        builder: (context, child) {
          final p = _counterAnimation.value;
          final weight = (11.0 + (14.2 - 11.0) * p).toStringAsFixed(1);
          final height = (72.9 + (94.5 - 72.9) * p).toStringAsFixed(1);
          final muac = (11.6 + (15.0 - 11.6) * p).toStringAsFixed(1);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: isHealthy ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                child: Icon(
                  isHealthy ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                  color: isHealthy ? const Color(0xFF059669) : const Color(0xFFDC2626),
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
                'AI Model Confidence: $confidenceText  •  $riskText',
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
                        final isSelectedClass = entry.key.toLowerCase() == pred.prediction.toLowerCase();
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
                                    fontWeight: isSelectedClass ? FontWeight.bold : FontWeight.w500,
                                    color: isSelectedClass ? const Color(0xFF0C2417) : const Color(0xFF445B4E),
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
                                        ? (isHealthy ? const Color(0xFF059669) : const Color(0xFFDC2626))
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
                                    fontWeight: isSelectedClass ? FontWeight.bold : FontWeight.normal,
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
                        Text('$weight kg',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0C2417))),
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
                        Text('$height cm',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF0C2417))),
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
                            Text('$muac cm',
                                style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF0C2417))),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                  color: isHealthy ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Text(
                                pred?.status.toUpperCase() ?? 'HEALTHY',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: isHealthy ? const Color(0xFF065F46) : const Color(0xFF991B1B)),
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
                onPressed: () => setState(() => _state = _ScanState.scanner),
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

class _ChildSilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF445B4E)
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    // Head oval
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 70), width: 50, height: 62),
      paint,
    );

    // Neck & Spine
    canvas.drawLine(Offset(cx, cy - 39), Offset(cx, cy + 40), paint);

    // Torso & Arms
    final bodyPath = Path();
    bodyPath.moveTo(cx - 24, cy - 25);
    bodyPath.cubicTo(cx - 45, cy - 10, cx - 50, cy + 30, cx - 35, cy + 40);
    bodyPath.cubicTo(cx - 20, cy + 40, cx - 18, cy + 10, cx, cy + 6);
    bodyPath.cubicTo(cx + 18, cy + 10, cx + 20, cy + 40, cx + 35, cy + 40);
    bodyPath.cubicTo(cx + 50, cy + 30, cx + 45, cy - 10, cx + 24, cy - 25);
    canvas.drawPath(bodyPath, paint);

    // Legs
    canvas.drawLine(Offset(cx - 16, cy + 40), Offset(cx - 20, cy + 100), paint);
    canvas.drawLine(Offset(cx + 16, cy + 40), Offset(cx + 20, cy + 100), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
      [const Color(0xFF0F3827), const Color(0xFF0369A1), const Color(0xFF0C4A6E)], // Albatross
      [const Color(0xFF0F3827), const Color(0xFF0F766E), const Color(0xFF164E63)], // Shark
      [const Color(0xFF0F3827), const Color(0xFFB45309), const Color(0xFF78350F)], // Cheetah
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
                                color: const Color(0xFF3FFF80).withOpacity(0.6)),
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




