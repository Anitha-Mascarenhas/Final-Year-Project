import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/child_profile.dart';
import '../models/prediction_result.dart';
import '../models/vital_record.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/bird_mascot.dart';

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
  // ── Navigation state ─────────────────────────────────────────────
  String _scanMode = 'camera'; // 'camera', 'distraction', 'preview'

  // ── Distraction state ────────────────────────────────────────────
  bool _distractionSoundsOn = false;

  // ── Camera state ─────────────────────────────────────────────────
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  String? _cameraError;

  // ── Capture & analysis state ─────────────────────────────────────
  bool _isCapturing = false;
  XFile? _capturedImage;
  bool _isAnalyzing = false;
  String? _analysisError;

  // ── Lifecycle ────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  // ── Camera initialisation ────────────────────────────────────────

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = 'No cameras available on this device.');
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
        setState(() => _cameraError = 'Camera permission denied or unavailable.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _cameraError = 'Failed to initialise camera.');
      }
    }
  }

  // ── Distraction helper ───────────────────────────────────────────

  void _playSoothingChime() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('♪ Chime sound played for child!'),
        duration: Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Capture ──────────────────────────────────────────────────────

  Future<void> _handleCapture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;

    setState(() {
      _isCapturing = true;
      _analysisError = null;
    });
    if (_distractionSoundsOn) _playSoothingChime();

    try {
      final XFile image = await _cameraController!.takePicture();
      if (mounted) {
        setState(() {
          _capturedImage = image;
          _isCapturing = false;
          _scanMode = 'preview';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCapturing = false);
        _showError('Failed to capture photo. Please try again.');
      }
    }
  }

  // ── Analysis ─────────────────────────────────────────────────────

  Future<void> _handleAnalyze() async {
    if (_capturedImage == null) return;

    setState(() {
      _isAnalyzing = true;
      _analysisError = null;
    });

    try {
      final result = await ApiService.predict(_capturedImage!.path);
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
    return Container(
      color: AppTheme.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 80, 20, 110),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildCurrentMode(),
        ),
      ),
    );
  }

  Widget _buildCurrentMode() {
    switch (_scanMode) {
      case 'distraction':
        return _buildDistractionMode();
      case 'preview':
        return _buildPreviewMode();
      case 'camera':
      default:
        return _buildCameraMode();
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // 1. CAMERA SCAN FRAME MODE
  // ══════════════════════════════════════════════════════════════════

  Widget _buildCameraMode() {
    return Column(
      key: const ValueKey('camera'),
      children: [
        Text(
          "Let's check in on their growth",
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Position ${widget.child.name} inside the gentle frame below.',
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // ── Camera Preview Box with Overlays ───────────────────────
        Container(
          width: double.infinity,
          height: 380,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppTheme.borderAccent, width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // ── Real Camera Feed OR Placeholder ─────────────────
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
                    color: const Color(0xFFEFEEEA),
                    child: Center(
                      child: _cameraError != null
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.videocam_off, size: 48, color: AppTheme.textMuted),
                                const SizedBox(height: 12),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                  child: Text(
                                    _cameraError!,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
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

                // ── Child Silhouette Outline ────────────────────────
                CustomPaint(
                  size: const Size(200, 320),
                  painter: _SilhouettePainter(),
                ),

                // ── Corner Brackets ─────────────────────────────────
                const Positioned(
                  top: 16,
                  left: 16,
                  child: _CornerBracket(top: true, left: true),
                ),
                const Positioned(
                  top: 16,
                  right: 16,
                  child: _CornerBracket(top: true, left: false),
                ),
                const Positioned(
                  bottom: 16,
                  left: 16,
                  child: _CornerBracket(top: false, left: true),
                ),
                const Positioned(
                  bottom: 16,
                  right: 16,
                  child: _CornerBracket(top: false, left: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // ── Mode Controls ──────────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Sound Distraction Switch
            GestureDetector(
              onTap: () {
                setState(() => _distractionSoundsOn = !_distractionSoundsOn);
                if (_distractionSoundsOn) _playSoothingChime();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9E8E4),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.volume_up, size: 18, color: AppTheme.accentSage),
                    const SizedBox(width: 6),
                    Text(
                      'Distract with sounds',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
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
            ),
            const SizedBox(width: 10),

            // Mascot Mode Button
            ElevatedButton(
              onPressed: () => setState(() => _scanMode = 'distraction'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentMint,
                foregroundColor: AppTheme.darkGreenText,
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                elevation: 0,
              ),
              child: Text(
                'Mascot Mode',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // ── Shutter Button ─────────────────────────────────────────
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
  // 2. CHILD DISTRACTION MODE
  // ══════════════════════════════════════════════════════════════════

  Widget _buildDistractionMode() {
    return Column(
      key: const ValueKey('distraction'),
      children: [
        Text(
          'DISTRACTION MODE ON',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Look here, ${widget.child.name}!',
          style: GoogleFonts.inter(fontSize: 16, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 28),

        // Interactive Animated Bird Mascot
        BirdMascot(
          onTap: _playSoothingChime,
        ),
        const SizedBox(height: 16),

        Text(
          'Tap the bird for a cheerful chime!',
          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 28),

        // Exit Distraction Button
        ElevatedButton.icon(
          onPressed: () => setState(() => _scanMode = 'camera'),
          icon: const Icon(Icons.close, size: 18),
          label: Text('Exit Distraction Mode', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFE9E8E4),
            foregroundColor: AppTheme.textSecondary,
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════
  // 3. PREVIEW & ANALYSE MODE
  // ══════════════════════════════════════════════════════════════════

  Widget _buildPreviewMode() {
    return Column(
      key: const ValueKey('preview'),
      children: [
        // ── Header ─────────────────────────────────────────────────
        Text(
          _isAnalyzing ? 'Analyzing photo...' : 'Review your photo',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          _isAnalyzing
              ? 'Sending to AI for nutritional screening...'
              : 'Make sure ${widget.child.name} is clearly visible.',
          style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),

        // ── Captured Image Preview ─────────────────────────────────
        Container(
          width: double.infinity,
          height: 380,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppTheme.borderAccent, width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_capturedImage != null)
                  Image.file(
                    File(_capturedImage!.path),
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                  )
                else
                  Container(
                    color: const Color(0xFFEFEEEA),
                    child: const Center(
                      child: Icon(Icons.image_not_supported, size: 48, color: AppTheme.textMuted),
                    ),
                  ),

                // Loading overlay when analysing
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
                                color: AppTheme.textSecondary,
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

        // ── Error Banner ───────────────────────────────────────────
        if (_analysisError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEA),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE57373)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFBA1A1A), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _analysisError!,
                    style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFBA1A1A)),
                  ),
                ),
              ],
            ),
          ),

        // ── Analyse Button ─────────────────────────────────────────
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

        // ── Retake Button ──────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: _isAnalyzing
                ? null
                : () => setState(() {
                      _capturedImage = null;
                      _analysisError = null;
                      _scanMode = 'camera';
                    }),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary, width: 2),
              shape: const StadiumBorder(),
            ),
            child: Text(
              'Retake photo',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
// Private helpers
// ════════════════════════════════════════════════════════════════════

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

class _SilhouettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryContainer.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..addOval(Rect.fromCenter(center: Offset(size.width * 0.5, 60), width: 70, height: 80))
      ..moveTo(size.width * 0.5, 100)
      ..lineTo(size.width * 0.5, 220)
      ..moveTo(size.width * 0.5, 130)
      ..lineTo(size.width * 0.2, 180)
      ..moveTo(size.width * 0.5, 130)
      ..lineTo(size.width * 0.8, 180)
      ..moveTo(size.width * 0.5, 220)
      ..lineTo(size.width * 0.3, 300)
      ..moveTo(size.width * 0.5, 220)
      ..lineTo(size.width * 0.7, 300);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
