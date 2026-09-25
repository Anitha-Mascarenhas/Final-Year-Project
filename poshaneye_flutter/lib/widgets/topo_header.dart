import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TopoHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final double? height;

  const TopoHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(32),
        topRight: Radius.circular(32),
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(44),
      ),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: AppColors.primaryForest,
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: TopoLinesPainter(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1.15,
                          ),
                        ),
                      ),
                      if (trailing != null) ...[
                        const SizedBox(width: 16),
                        trailing!,
                      ],
                    ],
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TopoLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    final path1 = Path();
    path1.moveTo(0, size.height * 0.2);
    path1.cubicTo(
      size.width * 0.35, size.height * 0.05,
      size.width * 0.65, size.height * 0.45,
      size.width, size.height * 0.15,
    );
    canvas.drawPath(path1, paint);

    final path2 = Path();
    path2.moveTo(0, size.height * 0.45);
    path2.cubicTo(
      size.width * 0.25, size.height * 0.3,
      size.width * 0.7, size.height * 0.65,
      size.width, size.height * 0.35,
    );
    canvas.drawPath(path2, paint);

    final path3 = Path();
    path3.moveTo(0, size.height * 0.7);
    path3.cubicTo(
      size.width * 0.3, size.height * 0.55,
      size.width * 0.65, size.height * 0.85,
      size.width, size.height * 0.6,
    );
    canvas.drawPath(path3, paint);

    // Oval contour on upper right
    final ovalRect1 = Rect.fromCenter(
      center: Offset(size.width * 0.78, size.height * 0.28),
      width: size.width * 0.48,
      height: size.height * 0.38,
    );
    canvas.drawOval(ovalRect1, paint);

    final ovalRect2 = Rect.fromCenter(
      center: Offset(size.width * 0.80, size.height * 0.28),
      width: size.width * 0.32,
      height: size.height * 0.22,
    );
    canvas.drawOval(ovalRect2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
