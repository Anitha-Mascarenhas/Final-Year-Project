import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import '../models/child_profile.dart';
import '../models/prediction_result.dart';
import '../models/vital_record.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ScanScreen extends StatefulWidget {
  final ChildProfile child;
  final VitalRecord vitals;
  final ValueChanged<int> onNavigateTab;
  final ValueChanged<PredictionResult> onAnalysisComplete;

  const ScanScreen({
    super.key,
    required this.child,
    required this.vitals,
    required this.onNavigateTab,
    required this.onAnalysisComplete,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  String _scanMode = 'camera'; // 'camera', 'video_select', 'video_play', 'preview'
  bool _distractionSoundsOn = false;
  String _imageSource = 'camera'; // 'camera' or 'upload'

  // Camera state
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  String? _cameraError;
  bool _isCapturing = false;

  // Image state (web-compatible)
  Uint8List? _capturedImageBytes;

  bool _isAnalyzing = false;
  String? _analysisError;

  // Video state
  VideoPlayerController? _videoController;
  String? _selectedVideo;
  bool _isVideoPlaying = false;

  final List<Map<String, dynamic>> _videos = [
    {
      'name': 'Cheetah',
      'asset': 'assets/videos/cheetah.mp4',
      'icon': Icons.pets,
      'description': 'Fast and playful cheetah',
    },
    {
      'name': 'Albatross',
      'asset': 'assets/videos/albatross.mp4',
      'icon': Icons.flight,
      'description': 'Graceful soaring albatross',
    },
    {
      'name': 'Shark',
      'asset': 'assets/videos/shark.mp4',
      'icon': Icons.water,
      'description': 'Majestic swimming shark',
    },
  ];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _cameraError = kIsWeb
              ? 'No camera found. Please connect a camera or use Upload Image.'
              : 'No cameras available on this device.');
        }
        return;
      }

      _cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) setState(() => _isCameraInitialized = true);
    } on CameraException {
      if (mounted) {
        setState(() => _cameraError = 'Camera permission denied or unavailable. You can allow camera access in your browser settings or upload an image instead.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cameraError = 'Failed to initialise camera. Please check your camera settings or use Upload Image.');
      }
    }
  }

  void _playSoothingChime() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('♪ Chime sound played for child!'),
        duration: Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Video Controls ──────────────────────────────────────────────

  Future<void> _initializeVideo(String assetPath) async {
    _videoController?.dispose();
    _videoController = VideoPlayerController.asset(assetPath);

    try {
      await _videoController!.initialize();
      _videoController!.setLooping(true);
      _videoController!.setVolume(0); // Muted by default
      _videoController!.play();
      if (mounted) {
        setState(() {
          _isVideoPlaying = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load video'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _toggleVideoPlayback() {
    if (_videoController == null) return;
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
        _isVideoPlaying = false;
      } else {
        _videoController!.play();
        _isVideoPlaying = true;
      }
    });
  }

  void _stopVideo() {
    _videoController?.pause();
    _videoController?.seekTo(Duration.zero);
    setState(() => _isVideoPlaying = false);
  }

  void _selectVideo(String videoName, String assetPath) {
    setState(() {
      _selectedVideo = videoName;
      _scanMode = 'video_play';
    });
    _initializeVideo(assetPath);
  }

  // ── Image Capture ──────────────────────────────────────────────

  Future<void> _handleCapture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _isCapturing = true;
      _analysisError = null;
    });
    if (_distractionSoundsOn) _playSoothingChime();

    try {
      final XFile image = await _cameraController!.takePicture();
      final bytes = await image.readAsBytes();

      if (mounted) {
        setState(() {
          _capturedImageBytes = bytes;
          _isCapturing = false;
          _scanMode = 'preview';
          _imageSource = 'camera';
        });
        _stopVideo();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        _showError('Failed to capture photo. Please try again.');
      }
    }
  }

  // ── Image Upload ──────────────────────────────────────────────

  Future<void> _handleUpload() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true, // Important: ensures bytes are loaded for web
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;

      // Get bytes — withData: true populates file.bytes on all platforms
      Uint8List? bytes = file.bytes;

      // Fallback: read from path on mobile only (path is NOT available on web)
      if (bytes == null && !kIsWeb) {
        try {
          final xfile = XFile(file.path!);
          bytes = await xfile.readAsBytes();
        } catch (_) {
          // path-based reading failed
        }
      }

      if (bytes == null) {
        _showError('Failed to read the selected image. Please try another file.');
        return;
      }

      if (mounted) {
        setState(() {
          _capturedImageBytes = bytes;
          _scanMode = 'preview';
          _imageSource = 'upload';
          _analysisError = null;
        });
        _stopVideo();
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to pick image. Please try again.');
      }
    }
  }

  // ── Analysis ─────────────────────────────────────────────────────

  Future<void> _handleAnalyze() async {
    if (_capturedImageBytes == null) return;

    setState(() {
      _isAnalyzing = true;
      _analysisError = null;
    });

    try {
      // Build child data from existing profile and vitals
      final childData = {
        'height': widget.vitals.height,
        'weight': widget.vitals.weight,
        'age': widget.child.ageYears * 12 + widget.child.ageMonths,
        'muac': widget.vitals.muac,
        'hc': 0.0, // Head circumference not in VitalRecord yet
      };

      // Determine filename based on source
      final fileName = _imageSource == 'upload' ? 'uploaded_image.jpg' : 'captured_image.jpg';

      final result = await ApiService.predict(
        imageBytes: _capturedImageBytes!,
        fileName: fileName,
        childData: childData,
      );

      if (mounted) {
        setState(() => _isAnalyzing = false);
        widget.onAnalysisComplete(result);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisError = e.message;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _analysisError = 'Could not connect to the analysis server. Please check your connection and try again.';
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final cameraPreviewHeight = (screenHeight * 0.45).clamp(250.0, 400.0);

    final textPrimary = AppTheme.textColorPrimary(context);
    final textSecondary = AppTheme.textColorSecondary(context);
    final scaffoldBg = AppTheme.scaffoldBgColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: scaffoldBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildCurrentMode(cameraPreviewHeight, textPrimary, textSecondary, scaffoldBg, isDark),
        ),
      ),
    );
  }

  Widget _buildCurrentMode(double cameraPreviewHeight, Color textPrimary, Color textSecondary, Color scaffoldBg, bool isDark) {
    switch (_scanMode) {
      case 'video_select':
        return _buildVideoSelectionMode(textPrimary, textSecondary, isDark);
      case 'video_play':
        return _buildVideoPlayMode(cameraPreviewHeight, textPrimary, textSecondary, isDark);
      case 'preview':
        return _buildPreviewMode(cameraPreviewHeight, textPrimary, textSecondary, scaffoldBg, isDark);
      case 'camera':
      default:
        return _buildCameraMode(cameraPreviewHeight, textPrimary, textSecondary, scaffoldBg, isDark);
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // 1. CAMERA MODE
  // ══════════════════════════════════════════════════════════════════

  Widget _buildCameraMode(double cameraPreviewHeight, Color textPrimary, Color textSecondary, Color scaffoldBg, bool isDark) {
    return Column(
      key: const ValueKey('camera'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          "Let's check in on their growth",
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Position ${widget.child.name} inside the gentle frame below.',
          style: GoogleFonts.inter(fontSize: 14, color: textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Camera Preview Box
        Container(
          width: double.infinity,
          height: cameraPreviewHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.borderAccentColor(context), width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_isCameraInitialized && _cameraController != null)
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _cameraController!.value.previewSize!.height,
                        height: _cameraController!.value.previewSize!.width,
                        child: CameraPreview(_cameraController!),
                      ),
                    ),
                  )
                else
                  Container(
                    color: isDark ? AppTheme.darkCardAlt : const Color(0xFFF1F5F9),
                    child: Center(
                      child: _cameraError != null
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_upload_outlined, size: 48, color: textSecondary),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Text(
                                    _cameraError!,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(fontSize: 13, color: textSecondary),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _cameraError = null;
                                      _isCameraInitialized = false;
                                    });
                                    _initCamera();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Retry',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const CircularProgressIndicator(color: AppTheme.primary),
                    ),
                  ),

                // Corner Brackets
                const Positioned(top: 16, left: 16, child: _CornerBracket(top: true, left: true)),
                const Positioned(top: 16, right: 16, child: _CornerBracket(top: true, left: false)),
                const Positioned(bottom: 16, left: 16, child: _CornerBracket(top: false, left: true)),
                const Positioned(bottom: 16, right: 16, child: _CornerBracket(top: false, left: false)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Action Buttons Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Upload Image Button - using ElevatedButton for web compatibility
            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _handleUpload,
                  icon: const Icon(Icons.cloud_upload_outlined, size: 20),
                  label: Text(
                    'Upload Image',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppTheme.darkCardAlt : const Color(0xFFF1F5F9),
                    foregroundColor: AppTheme.primary,
                    elevation: 0,
                    side: BorderSide(color: AppTheme.borderColorValue(context)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Distraction Videos Button
            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: () => setState(() => _scanMode = 'video_select'),
                  icon: const Icon(Icons.play_circle_outline, size: 20),
                  label: Text(
                    'Distraction',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? AppTheme.darkCardAlt : const Color(0xFFF1F5F9),
                    foregroundColor: AppTheme.accentSage,
                    elevation: 0,
                    side: BorderSide(color: AppTheme.borderColorValue(context)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Mode Controls Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCardAlt : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.volume_up, size: 18, color: AppTheme.accentSage),
                  const SizedBox(width: 6),
                  Text(
                    'Sounds',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: textSecondary),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: _distractionSoundsOn,
                    onChanged: (val) {
                      setState(() => _distractionSoundsOn = val);
                      if (val) _playSoothingChime();
                    },
                    activeTrackColor: AppTheme.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Shutter Button (show when camera is available on any platform)
        if (_isCameraInitialized)
          GestureDetector(
            onTap: _isCapturing ? null : _handleCapture,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppTheme.primary.withValues(alpha: 0.2), blurRadius: 16, spreadRadius: 4),
                ],
              ),
              padding: const EdgeInsets.all(6),
              child: Container(
                decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                child: _isCapturing
                    ? const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        ),
                      )
                    : const Icon(Icons.camera_alt, color: Colors.white, size: 32),
              ),
            ),
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // 2. VIDEO SELECTION MODE
  // ══════════════════════════════════════════════════════════════════

  Widget _buildVideoSelectionMode(Color textPrimary, Color textSecondary, bool isDark) {
    return Column(
      key: const ValueKey('video_select'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Choose a Distraction Video',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Select a video to keep ${widget.child.name} engaged during the scan.',
          style: GoogleFonts.inter(fontSize: 14, color: textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        // Video Selection Cards
        ...(_videos.map((video) => _buildVideoCard(video, textPrimary, textSecondary, isDark))),

        const SizedBox(height: 16),

        // Back Button
        TextButton.icon(
          onPressed: () => setState(() => _scanMode = 'camera'),
          icon: Icon(Icons.arrow_back, color: textSecondary, size: 18),
          label: Text(
            'Back to Camera',
            style: GoogleFonts.inter(fontSize: 14, color: textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> video, Color textPrimary, Color textSecondary, bool isDark) {
    final isSelected = _selectedVideo == video['name'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => _selectVideo(video['name'], video['asset']),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryContainer : (isDark ? AppTheme.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.borderColorValue(context),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary : AppTheme.accentMint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  video['icon'],
                  color: isSelected ? Colors.white : AppTheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video['name'],
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      video['description'],
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.play_circle_outline,
                color: isSelected ? AppTheme.primary : textSecondary,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // 3. VIDEO PLAY MODE
  // ══════════════════════════════════════════════════════════════════

  Widget _buildVideoPlayMode(double cameraPreviewHeight, Color textPrimary, Color textSecondary, bool isDark) {
    return Column(
      key: const ValueKey('video_play'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Distraction Mode',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          _selectedVideo ?? 'Video',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: AppTheme.primary,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        // Video Player
        Container(
          width: double.infinity,
          height: cameraPreviewHeight * 0.8,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Video
                if (_videoController != null && _videoController!.value.isInitialized)
                  SizedBox.expand(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _videoController!.value.size.width,
                        height: _videoController!.value.size.height,
                        child: VideoPlayer(_videoController!),
                      ),
                    ),
                  )
                else
                  const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),

                // Play/Pause Overlay
                GestureDetector(
                  onTap: _toggleVideoPlayback,
                  child: AnimatedOpacity(
                    opacity: _isVideoPlaying ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isVideoPlaying ? Icons.pause : Icons.play_arrow,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),

                // Close Button
                Positioned(
                  top: 12,
                  right: 12,
                  child: GestureDetector(
                    onTap: () {
                      _stopVideo();
                      setState(() => _scanMode = 'camera');
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Video Controls Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Play/Pause Button
            GestureDetector(
              onTap: _toggleVideoPlayback,
              child: Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isVideoPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 20),
            // Mute Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkCard : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.volume_off, size: 16, color: textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Muted',
                    style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Capture Button (when video is playing)
        Text(
          'Tap the shutter button below to capture',
          style: GoogleFonts.inter(fontSize: 12, color: textSecondary),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 12),

        // Shutter Button (show when camera is available on any platform)
        if (_isCameraInitialized)
          GestureDetector(
            onTap: _isCapturing ? null : _handleCapture,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: AppTheme.primary.withValues(alpha: 0.2), blurRadius: 16, spreadRadius: 4),
                ],
              ),
              padding: const EdgeInsets.all(6),
              child: Container(
                decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                child: _isCapturing
                    ? const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                        ),
                      )
                    : const Icon(Icons.camera_alt, color: Colors.white, size: 32),
              ),
            ),
          ),

        // Upload button in video mode (show when camera is NOT available as fallback)
        if (!_isCameraInitialized)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _handleUpload,
              icon: const Icon(Icons.cloud_upload_outlined, size: 20),
              label: Text(
                'Upload Image',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: const StadiumBorder(),
              ),
            ),
          ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // 4. PREVIEW MODE
  // ══════════════════════════════════════════════════════════════════

  Widget _buildPreviewMode(double cameraPreviewHeight, Color textPrimary, Color textSecondary, Color scaffoldBg, bool isDark) {
    return Column(
      key: const ValueKey('preview'),
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _isAnalyzing ? 'Analyzing photo...' : 'Review your photo',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          _isAnalyzing
              ? 'Sending to AI for nutritional screening...'
              : _imageSource == 'upload'
                  ? 'Image uploaded successfully.'
                  : 'Make sure ${widget.child.name} is clearly visible.',
          style: GoogleFonts.inter(fontSize: 14, color: textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // Captured/Uploaded Image Preview (using Image.memory for web compatibility)
        Container(
          width: double.infinity,
          height: cameraPreviewHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.borderAccentColor(context), width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Image display using bytes (works on web and mobile)
                if (_capturedImageBytes != null)
                  Image.memory(
                    _capturedImageBytes!,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        color: isDark ? AppTheme.darkCardAlt : const Color(0xFFF1F5F9),
                        child: Center(
                          child: Icon(Icons.image_not_supported, size: 48, color: textSecondary),
                        ),
                      );
                    },
                  )
                else
                  Container(
                    color: isDark ? AppTheme.darkCardAlt : const Color(0xFFF1F5F9),
                    child: Center(
                      child: Icon(Icons.image_not_supported, size: 48, color: textSecondary),
                    ),
                  ),

                if (_isAnalyzing)
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 3),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'AI is analysing...',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'This may take a moment',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppTheme.textColorSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Error Banner
        if (_analysisError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _analysisError!,
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFDC2626)),
                  ),
                ),
              ],
            ),
          ),

        // Analyse Button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isAnalyzing ? null : _handleAnalyze,
            icon: _isAnalyzing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.analytics_outlined, size: 20),
            label: Text(
              _isAnalyzing ? 'Analyzing...' : 'Analyze',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Retake/Choose Another Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _isAnalyzing
                ? null
                : () => setState(() {
                  _capturedImageBytes = null;
                  _analysisError = null;
                  _scanMode = 'camera';
                    }),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary, width: 2),
              shape: const StadiumBorder(),
            ),
            child: Text(
              _imageSource == 'upload' ? 'Choose Another' : 'Retake photo',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}

class _CornerBracket extends StatelessWidget {
  final bool top;
  final bool left;
  const _CornerBracket({required this.top, required this.left});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        border: Border(
          top: top ? const BorderSide(color: AppTheme.primary, width: 3) : BorderSide.none,
          bottom: !top ? const BorderSide(color: AppTheme.primary, width: 3) : BorderSide.none,
          left: left ? const BorderSide(color: AppTheme.primary, width: 3) : BorderSide.none,
          right: !left ? const BorderSide(color: AppTheme.primary, width: 3) : BorderSide.none,
        ),
      ),
    );
  }
}
