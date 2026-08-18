import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BirdMascot extends StatefulWidget {
  final VoidCallback onTap;

  const BirdMascot({super.key, required this.onTap});

  @override
  State<BirdMascot> createState() => _BirdMascotState();
}

class _BirdMascotState extends State<BirdMascot> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _wingAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _scaleAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    _wingAnim = Tween<double>(begin: -0.1, end: 0.1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnim.value,
            child: SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Pulse Glow Aura
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.accentMint.withValues(alpha: 0.4),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.15),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),

                  // Custom Painter Bird Mascot
                  CustomPaint(
                    size: const Size(200, 200),
                    painter: _BirdPainter(wingOffset: _wingAnim.value),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BirdPainter extends CustomPainter {
  final double wingOffset;

  _BirdPainter({required this.wingOffset});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.5);

    // Body Paint
    final bodyPaint = Paint()
      ..color = AppTheme.accentMint
      ..style = PaintingStyle.fill;

    // Wing Paint
    final wingPaint = Paint()
      ..color = const Color(0xFFB0CDBB)
      ..style = PaintingStyle.fill;

    // Eye Paint
    final eyePaint = Paint()
      ..color = const Color(0xFF062014)
      ..style = PaintingStyle.fill;

    // Beak Paint
    final beakPaint = Paint()
      ..color = const Color(0xFF4A654D)
      ..style = PaintingStyle.fill;

    // 1. Draw Body oval
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 140, height: 120),
      bodyPaint,
    );

    // 2. Draw Left Wing
    canvas.save();
    canvas.translate(center.dx - 55, center.dy + 5);
    canvas.rotate(wingOffset);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 36, height: 50),
      wingPaint,
    );
    canvas.restore();

    // 3. Draw Right Wing
    canvas.save();
    canvas.translate(center.dx + 55, center.dy + 5);
    canvas.rotate(-wingOffset);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 36, height: 50),
      wingPaint,
    );
    canvas.restore();

    // 4. Draw Eyes
    canvas.drawCircle(Offset(center.dx - 22, center.dy - 12), 7, eyePaint);
    canvas.drawCircle(Offset(center.dx + 22, center.dy - 12), 7, eyePaint);
    canvas.drawCircle(Offset(center.dx - 20, center.dy - 14), 2.5, Paint()..color = Colors.white);
    canvas.drawCircle(Offset(center.dx + 24, center.dy - 14), 2.5, Paint()..color = Colors.white);

    // 5. Draw Beak Triangle
    final beakPath = Path()
      ..moveTo(center.dx - 10, center.dy)
      ..lineTo(center.dx + 10, center.dy)
      ..lineTo(center.dx, center.dy + 16)
      ..close();
    canvas.drawPath(beakPath, beakPaint);
  }

  @override
  bool shouldRepaint(covariant _BirdPainter oldDelegate) =>
      oldDelegate.wingOffset != wingOffset;
}
