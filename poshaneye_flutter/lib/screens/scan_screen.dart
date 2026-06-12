import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class ScanScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const ScanScreen({super.key, required this.onComplete});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with SingleTickerProviderStateMixin {
  bool _distractionMode = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 1))
      ..repeat(reverse: true);
    _pulseAnim = Tween(begin: 0.6, end: 1.0).animate(_pulseController);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDistractionMode(),
        const SizedBox(height: 24),
        _buildCameraInterface(),
        const SizedBox(height: 20),
        _buildSafetyTips(),
      ],
    );
  }

  Widget _buildDistractionMode() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.child_care, color: AppTheme.secondary, size: 24),
              const SizedBox(width: 8),
              Text('Distraction Mode',
                  style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: () => setState(() => _distractionMode = !_distractionMode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _distractionMode ? AppTheme.secondary : AppTheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 200),
                    alignment: _distractionMode ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 22,
                      height: 22,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_distractionMode) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Image.network(
                    'https://lh3.googleusercontent.com/aida-public/AB6AXuD9_CY5K_dXo_Hf4KuRXp6b3bxjPlTKhMUFUdc5SVyIU_1icgNIt4MnPWqBV8U7bUlGX6DeiJHmOA9lhrRCQHSc5sCeS5qJV8zN9QV91_VuZDhxoXgMJmgHW7nJuD87TOEklmLjONq9yP0D2CooEPLW-jbSawynwNw2uBiYWI2J1q4OVlCYU21XDAiOtz4Z14dy-rUg6Ypjx9BQa5UaoLyWZ0Lq2LMebbeCFvr9yPYk_2bdYCAixJIm18yrriMEJXMwQl3EyDzWdsQk',
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 160,
                      color: AppTheme.surfaceContainerHigh,
                      child: const Icon(Icons.play_circle_outline, size: 48, color: AppTheme.outlineVariant),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      color: Colors.black26,
                      child: const Center(
                        child: Icon(Icons.play_circle_fill, color: Colors.white, size: 52),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Keeping child engaged...',
                          style: GoogleFonts.inter(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCameraInterface() {
    return AspectRatio(
      aspectRatio: 3 / 4,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://lh3.googleusercontent.com/aida-public/AB6AXuA4NzpMQ41xVnCqc2Y3KRJP3UkFf-TPBGXTMRTLwszmYY-KpqoTyFJ8ThdmIZn5jiWgBruKERLt5QCpTxYSa0q6RhnmW_UqhPCWyftJtbuMfmTpzUCw49u_ntYeqkFdkVFnyL0rm8vIEFd80XhkHe1NbZjsY47WgwTcKHg4ToXNHDa3wd_OGqG1gxS608Ako7f1rEp81WwAvQczcpT1vdFsHeAkR7sAd0zy2qccillIf3fGtmEw6sF_AmOcl7tJzJlMIeifgYfL0Jp9',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black87),
            ),
            Container(color: Colors.black.withOpacity(0.2)),

            // Top detecting badge
            Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => Opacity(
                          opacity: _pulseAnim.value,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppTheme.secondaryFixed,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('DETECTING...',
                          style: GoogleFonts.montserrat(
                              fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 2)),
                    ],
                  ),
                ),
              ),
            ),

            // Target overlay
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.6), width: 2, style: BorderStyle.solid),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        'Position upper arm\nwithin this area',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                            fontSize: 10, color: Colors.white.withOpacity(0.5), fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                    ),
                    child: const Icon(Icons.my_location, color: Colors.white, size: 32),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Place a coin next to the arm\nfor scale calibration',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                        fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white,
                        shadows: [const Shadow(blurRadius: 8)]),
                  ),
                ],
              ),
            ),

            // Bottom controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(28, 40, 28, 28),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black87],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CamButton(icon: Icons.photo_library_outlined, onTap: () {}),
                    GestureDetector(
                      onTap: widget.onComplete,
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        padding: const EdgeInsets.all(4),
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.primary, width: 3),
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                          ),
                        ),
                      ),
                    ),
                    _CamButton(icon: Icons.flip_camera_ios_outlined, onTap: () {}),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyTips() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('SAFETY CHECK',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700,
                      color: AppTheme.primary, letterSpacing: 1)),
              const SizedBox(height: 6),
              Text(
                'Ensure the area is well-lit and the child is calm. High-contrast backgrounds work best for AI accuracy.',
                style: GoogleFonts.inter(fontSize: 13, color: AppTheme.onSurfaceVariant, height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _TipCard(
                icon: Icons.wb_sunny_outlined,
                label: 'BRIGHT LIGHT',
                color: AppTheme.secondaryContainer,
                textColor: AppTheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _TipCard(
                icon: Icons.straighten,
                label: 'REFERENCE OBJECT',
                color: AppTheme.primaryFixed,
                textColor: AppTheme.primary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CamButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CamButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

class _TipCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  const _TipCard({required this.icon, required this.label, required this.color, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: textColor, size: 30),
          const SizedBox(height: 8),
          Text(label,
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: textColor, letterSpacing: 0.5),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
