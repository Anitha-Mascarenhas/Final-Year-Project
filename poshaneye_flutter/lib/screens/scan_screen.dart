import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/child_profile.dart';
import '../models/vital_record.dart';
import '../theme/app_theme.dart';
import '../widgets/bird_mascot.dart';

class ScanScreen extends StatefulWidget {
  final ChildProfile child;
  final VitalRecord vitals;
  final ValueChanged<int> onNavigateTab;

  const ScanScreen({
    super.key,
    required this.child,
    required this.vitals,
    required this.onNavigateTab,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  String _scanMode = 'camera'; // 'camera', 'distraction', 'result'
  bool _distractionSoundsOn = false;
  bool _isCapturing = false;

  void _playSoothingChime() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('♪ Chime sound played for child!'),
        duration: Duration(milliseconds: 1200),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleCapture() {
    setState(() => _isCapturing = true);
    if (_distractionSoundsOn) _playSoothingChime();

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _scanMode = 'result';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Wrap entire ScanScreen in a opaque background container to ensure camera preview is 100% clear
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
      case 'result':
        return _buildResultMode();
      case 'camera':
      default:
        return _buildCameraMode();
    }
  }

  // 1. CAMERA SCAN FRAME MODE
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

        // Clear Camera Preview Box with Silhouette & Corner Brackets
        Container(
          width: double.infinity,
          height: 380,
          decoration: BoxDecoration(
            color: const Color(0xFFEFEEEA),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppTheme.borderAccent, width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Simulated Camera Feed Background
              ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.03),
                  child: const Center(
                    child: Icon(Icons.camera_alt_outlined, size: 48, color: AppTheme.textMuted),
                  ),
                ),
              ),

              // Child Silhouette Outline
              CustomPaint(
                size: const Size(200, 320),
                painter: _SilhouettePainter(),
              ),

              // Corner Brackets
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
        const SizedBox(height: 24),

        // Mode Controls
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

        // Shutter Button
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

  // 2. CHILD DISTRACTION MODE
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

  // 3. SCAN RESULT MODE
  Widget _buildResultMode() {
    return Column(
      key: const ValueKey('result'),
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(
            color: AppTheme.accentMint,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check_circle_outline, color: AppTheme.darkGreenText, size: 40),
        ),
        const SizedBox(height: 14),
        Text(
          '${widget.child.name} is growing normally',
          style: GoogleFonts.inter(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'Last checked today at 10:42 AM',
          style: GoogleFonts.inter(fontSize: 13, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 24),

        // Measurements Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.cardBgAlt,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LATEST MEASUREMENTS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 14),
              _buildResultRow('Weight', '${widget.vitals.weight}', 'kg'),
              const Divider(height: 20, color: AppTheme.borderColor),
              _buildResultRow('Height', '${widget.vitals.height}', 'cm'),
              const Divider(height: 20, color: AppTheme.borderColor),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('MUAC', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                      RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                          children: [
                            TextSpan(text: '${widget.vitals.muac}', style: const TextStyle(fontSize: 22)),
                            const TextSpan(text: ' cm', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w400)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.accentMint,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: AppTheme.accentSage, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Healthy',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.accentSage),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // What This Means
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'WHAT THIS MEANS',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.child.name} is right on track. His weight and height are perfectly balanced, and his arm circumference shows he is getting plenty of the right nutrients. Keep doing what you\'re doing!',
              style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textPrimary, height: 1.5),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Action Buttons
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: () => widget.onNavigateTab(3), // View Nutrition Plan
            icon: const Icon(Icons.restaurant_outlined, size: 20),
            label: Text('View nutrition plan', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: const StadiumBorder(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => setState(() => _scanMode = 'camera'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primary,
              side: const BorderSide(color: AppTheme.primary, width: 2),
              shape: const StadiumBorder(),
            ),
            child: Text('Scan again', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        ),
      ],
    );
  }

  Widget _buildResultRow(String label, String val, String unit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
            RichText(
              text: TextSpan(
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                children: [
                  TextSpan(text: val, style: const TextStyle(fontSize: 22)),
                  TextSpan(text: ' $unit', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400)),
                ],
              ),
            ),
          ],
        ),
        const Icon(Icons.show_chart, color: AppTheme.accentSage, size: 28),
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
