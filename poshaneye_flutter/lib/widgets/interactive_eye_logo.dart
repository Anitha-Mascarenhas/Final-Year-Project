import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class InteractiveEyeLogo extends StatefulWidget {
  final Color color;
  final double width;

  const InteractiveEyeLogo({
    Key? key,
    this.color = const Color(0xFF173124),
    this.width = 42.0,
  }) : super(key: key);

  @override
  State<InteractiveEyeLogo> createState() => InteractiveEyeLogoState();
}

class InteractiveEyeLogoState extends State<InteractiveEyeLogo>
    with SingleTickerProviderStateMixin {
  static final Set<InteractiveEyeLogoState> _mountedLogos =
      <InteractiveEyeLogoState>{};

  late AnimationController _ticker;
  final GlobalKey _eyeKey = GlobalKey();

  Offset _targetPupilOffset = Offset.zero;
  Offset _currentPupilOffset = Offset.zero;
  double _targetPupilRadius = 8.0;
  double _currentPupilRadius = 8.0;

  @override
  void initState() {
    super.initState();
    _mountedLogos.add(this);
    
    // Register global pointer listener to capture mouse hover anywhere on screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      GestureBinding.instance.pointerRouter.addGlobalRoute(_handleGlobalPointer);
    });

    // Continuous 60/120 FPS physics loop
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_onTick);
    _ticker.repeat();
  }

  void _handleGlobalPointer(PointerEvent event) {
    if (event is PointerHoverEvent ||
        event is PointerMoveEvent ||
        event is PointerDownEvent) {
      updateEyeTarget(event.position);
    }
  }

  void updateEyeTarget(Offset globalPointerPos) {
    final RenderBox? box =
        _eyeKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    // Get exact center of eye in global screen coordinates
    final eyeCenter =
        box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
    final dx = globalPointerPos.dx - eyeCenter.dx;
    final dy = globalPointerPos.dy - eyeCenter.dy;
    final dist = math.sqrt(dx * dx + dy * dy);

    if (dist < 2.0) {
      _targetPupilOffset = Offset.zero;
      _targetPupilRadius = 8.0;
      return;
    }

    final angle = math.atan2(dy, dx);

    // Max displacement limits in SVG coordinate space (120x80)
    const double maxOffsetHoriz = 26.0;
    const double maxOffsetVert = 15.0;

    // Smooth responsive pull strength
    final double pullStrength = (dist / 100.0).clamp(0.2, 1.0);
    final double targetR = dist < 60.0 ? 9.8 : 8.0;

    _targetPupilOffset = Offset(
      math.cos(angle) * maxOffsetHoriz * pullStrength,
      math.sin(angle) * maxOffsetVert * pullStrength,
    );
    _targetPupilRadius = targetR;
  }

  void resetEyeTarget() {
    _targetPupilOffset = Offset.zero;
    _targetPupilRadius = 8.0;
  }

  static void updateMountedTargets(Offset globalPointerPos) {
    for (final logo in List<InteractiveEyeLogoState>.of(_mountedLogos)) {
      logo.updateEyeTarget(globalPointerPos);
    }
  }

  static void resetMountedTargets() {
    for (final logo in List<InteractiveEyeLogoState>.of(_mountedLogos)) {
      logo.resetEyeTarget();
    }
  }

  void _onTick() {
    if (!mounted) return;
    // Ultra-smooth lerp physics factor (0.18) for fluid 60/120 FPS motion
    const double lerpSpeed = 0.18;
    final double newDx = _currentPupilOffset.dx +
        (_targetPupilOffset.dx - _currentPupilOffset.dx) * lerpSpeed;
    final double newDy = _currentPupilOffset.dy +
        (_targetPupilOffset.dy - _currentPupilOffset.dy) * lerpSpeed;
    final double newR = _currentPupilRadius +
        (_targetPupilRadius - _currentPupilRadius) * lerpSpeed;

    if ((newDx - _currentPupilOffset.dx).abs() > 0.001 ||
        (newDy - _currentPupilOffset.dy).abs() > 0.001 ||
        (newR - _currentPupilRadius).abs() > 0.001) {
      setState(() {
        _currentPupilOffset = Offset(newDx, newDy);
        _currentPupilRadius = newR;
      });
    }
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handleGlobalPointer);
    _mountedLogos.remove(this);
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 120x80 viewBox aspect ratio (3:2)
    final double height = widget.width * (80.0 / 120.0);

    return SizedBox(
      key: _eyeKey,
      width: widget.width,
      height: height,
      child: CustomPaint(
        painter: PoshanEyePainter(
          color: widget.color,
          pupilOffset: _currentPupilOffset,
          pupilRadius: _currentPupilRadius,
        ),
      ),
    );
  }
}

class PoshanEyePainter extends CustomPainter {
  final Color color;
  final Offset pupilOffset;
  final double pupilRadius;

  PoshanEyePainter({
    required this.color,
    required this.pupilOffset,
    required this.pupilRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Scale canvas coordinate space to match SVG viewBox (120x80)
    final double scaleX = size.width / 120.0;
    final double scaleY = size.height / 80.0;
    canvas.scale(scaleX, scaleY);

    // 1. Draw Outer Eyelid Curves
    final Paint strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..strokeCap = StrokeCap.round;

    final Path topCurve = Path()
      ..moveTo(10, 40)
      ..quadraticBezierTo(25, 10, 60, 10)
      ..cubicTo(85, 10, 100, 25, 100, 35);

    final Path bottomCurve = Path()
      ..moveTo(20, 40)
      ..quadraticBezierTo(60, 70, 100, 40);

    canvas.drawPath(topCurve, strokePaint);
    canvas.drawPath(bottomCurve, strokePaint);

    // 2. Draw Translucent Eyelid Shade
    final Paint fillPaint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final Path shadePath = Path()
      ..moveTo(20, 35)
      ..quadraticBezierTo(50, 15, 90, 20)
      ..cubicTo(70, 35, 40, 45, 20, 35)
      ..close();

    canvas.drawPath(shadePath, fillPaint);

    // 3. Draw Dynamic Pupil Circle
    final Paint pupilPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final Offset center = Offset(60 + pupilOffset.dx, 42 + pupilOffset.dy);
    canvas.drawCircle(center, pupilRadius, pupilPaint);
  }

  @override
  bool shouldRepaint(covariant PoshanEyePainter oldDelegate) {
    return oldDelegate.pupilOffset != pupilOffset ||
        oldDelegate.pupilRadius != pupilRadius ||
        oldDelegate.color != color;
  }
}
