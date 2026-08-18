import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final bool showBack;
  final VoidCallback? onBackClick;
  final VoidCallback onProfileClick;
  final String avatarUrl;

  const AppHeader({
    super.key,
    required this.title,
    this.showBack = false,
    this.onBackClick,
    required this.onProfileClick,
    required this.avatarUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1235).withValues(alpha: 0.88),
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF3FFF80).withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 48,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Back button + PoshanEye Brand Logo & Title
              Row(
                children: [
                  if (showBack) ...[
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF3FFF80), size: 22),
                      onPressed: onBackClick,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                    const SizedBox(width: 4),
                  ],

                  // PoshanEye Brand Eye Logo
                  const _PoshanEyeLogoIcon(),
                  const SizedBox(width: 8),

                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),

              // Right: Profile Avatar Button
              GestureDetector(
                onTap: onProfileClick,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF3FFF80).withValues(alpha: 0.5), width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppTheme.accentMint,
                        child: const Icon(Icons.person, color: AppTheme.primary, size: 20),
                      ),
                    ),
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

class _PoshanEyeLogoIcon extends StatelessWidget {
  const _PoshanEyeLogoIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 24,
      child: CustomPaint(
        painter: _EyeLogoPainter(),
      ),
    );
  }
}

class _EyeLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = const Color(0xFF3FFF80)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = const Color(0xFF3FFF80).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final pupilPaint = Paint()
      ..color = const Color(0xFF3FFF80)
      ..style = PaintingStyle.fill;

    // Top Eye Arch
    final topPath = Path()
      ..moveTo(2, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.5, 2, size.width - 2, size.height * 0.5);

    // Bottom Eye Arch
    final bottomPath = Path()
      ..moveTo(2, size.height * 0.5)
      ..quadraticBezierTo(size.width * 0.5, size.height - 2, size.width - 2, size.height * 0.5);

    canvas.drawPath(topPath, strokePaint);
    canvas.drawPath(bottomPath, strokePaint);
    canvas.drawPath(topPath, fillPaint);
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), 3.5, pupilPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
