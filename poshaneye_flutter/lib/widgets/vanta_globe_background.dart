import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Vanta.js Globe-style animated background for mobile.
///
/// Draws a wireframe globe with latitude/longitude grid lines, a flat
/// perspective ground-plane grid extending outward, radiating spike markers,
/// and small intersection nodes — all on a deep dark indigo background.
///
/// Designed specifically for portrait mobile viewports: the globe sits in
/// the lower-right quadrant, leaving the upper-left clear for UI content.
class VantaGlobeBackground extends StatefulWidget {
  final Widget child;
  final bool isBackgroundVisible;

  const VantaGlobeBackground({
    super.key,
    required this.child,
    this.isBackgroundVisible = true,
  });

  @override
  State<VantaGlobeBackground> createState() => _VantaGlobeBackgroundState();
}

class _VantaGlobeBackgroundState extends State<VantaGlobeBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _dragRotX = 0.0;
  double _dragRotY = 0.0;
  Offset? _lastPanPos;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 90),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (d) => _lastPanPos = d.localPosition,
      onPanUpdate: (d) {
        if (_lastPanPos != null) {
          final delta = d.localPosition - _lastPanPos!;
          setState(() {
            _dragRotY += delta.dx * 0.004;
            _dragRotX -= delta.dy * 0.004;
            _dragRotX = _dragRotX.clamp(-0.6, 0.6);
          });
        }
        _lastPanPos = d.localPosition;
      },
      onPanEnd: (_) => _lastPanPos = null,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Deep indigo base (matches Vanta reference)
          Container(color: const Color(0xFF23153C)),

          // Animated globe canvas
          if (widget.isBackgroundVisible)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _VantaGlobePainter(
                    animValue: _controller.value,
                    dragRotX: _dragRotX,
                    dragRotY: _dragRotY,
                  ),
                  size: Size.infinite,
                );
              },
            ),

          // Foreground content
          widget.child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Painter
// ---------------------------------------------------------------------------

class _VantaGlobePainter extends CustomPainter {
  final double animValue;
  final double dragRotX;
  final double dragRotY;

  _VantaGlobePainter({
    required this.animValue,
    required this.dragRotX,
    required this.dragRotY,
  });

  // Rotation matrix helpers ---------------------------------------------------

  static List<double> _rotateY(double x, double y, double z, double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return [x * c + z * s, y, -x * s + z * c];
  }

  static List<double> _rotateX(double x, double y, double z, double angle) {
    final c = math.cos(angle);
    final s = math.sin(angle);
    return [x, y * c - z * s, y * s + z * c];
  }

  /// Apply combined Y → X rotation and return screen-space offset + depth.
  List<double> _transform(double x, double y, double z, double rY, double rX) {
    var p = _rotateY(x, y, z, rY);
    p = _rotateX(p[0], p[1], p[2], rX);
    return p; // [x, y, z]
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Globe sizing — designed for portrait mobile.
    // Globe radius ~ 30% of screen width, max 160px.
    final globeRadius = math.min(w * 0.38, 180.0);

    // Position: right-center, slightly below vertical center.
    final cx = w * 0.58;
    final cy = h * 0.48;

    // Continuous Y rotation + user drag offsets.
    final rY = animValue * 2 * math.pi + dragRotY;
    final rX = 0.25 + dragRotX; // slight tilt

    // -----------------------------------------------------------------------
    // 1. Draw flat perspective ground-plane grid
    // -----------------------------------------------------------------------
    _drawGroundPlane(canvas, size, cx, cy, globeRadius, rY, rX);

    // -----------------------------------------------------------------------
    // 2. Draw wireframe globe (lat/long lines)
    // -----------------------------------------------------------------------
    _drawGlobeWireframe(canvas, cx, cy, globeRadius, rY, rX);

    // -----------------------------------------------------------------------
    // 3. Draw radiating spike markers from globe
    // -----------------------------------------------------------------------
    _drawSpikes(canvas, cx, cy, globeRadius, rY, rX);
  }

  // =========================================================================
  // Ground Plane
  // =========================================================================

  void _drawGroundPlane(
      Canvas canvas, Size size, double cx, double cy, double R, double rY, double rX) {
    final gridPaint = Paint()
      ..color = const Color(0xFF3FFF80).withValues(alpha: 0.06)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final gridLinePaint2 = Paint()
      ..color = const Color(0xFF6666AA).withValues(alpha: 0.12)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final nodePaint = Paint()
      ..color = const Color(0xFF3FFF80).withValues(alpha: 0.55)
      ..style = PaintingStyle.fill;

    // Grid extends outward from globe base in a flat XZ plane at y = R * 0.7.
    const gridLines = 14;
    final gridExtent = R * 3.5;
    final gridY = R * 0.65; // plane sits just below globe equator

    for (int i = -gridLines; i <= gridLines; i++) {
      final frac = i / gridLines;
      final offset = frac * gridExtent;

      // Lines along X-axis (varying Z)
      final xStart = _transform(-gridExtent, gridY, offset, rY, rX);
      final xEnd = _transform(gridExtent, gridY, offset, rY, rX);
      _drawGridLine(canvas, cx, cy, xStart, xEnd, gridLinePaint2);

      // Lines along Z-axis (varying X)
      final zStart = _transform(offset, gridY, -gridExtent, rY, rX);
      final zEnd = _transform(offset, gridY, gridExtent, rY, rX);
      _drawGridLine(canvas, cx, cy, zStart, zEnd, gridLinePaint2);
    }

    // Draw green nodes at grid intersections
    for (int i = -gridLines; i <= gridLines; i += 2) {
      for (int j = -gridLines; j <= gridLines; j += 2) {
        final fx = (i / gridLines) * gridExtent;
        final fz = (j / gridLines) * gridExtent;
        final p = _transform(fx, gridY, fz, rY, rX);
        if (p[2] > -R * 0.5) {
          final sx = cx + p[0];
          final sy = cy + p[1];
          // Only draw if on-screen
          if (sx > -20 && sx < (canvas.getClipBounds().width + 20) &&
              sy > -20 && sy < (canvas.getClipBounds().height + 20)) {
            canvas.drawCircle(Offset(sx, sy), 1.5, nodePaint);
          }
        }
      }
    }

    // Brighter green grid lines close to globe
    for (int i = -4; i <= 4; i++) {
      final frac = i / 4;
      final offset = frac * R * 1.5;

      final xS = _transform(-R * 1.5, gridY, offset, rY, rX);
      final xE = _transform(R * 1.5, gridY, offset, rY, rX);
      _drawGridLine(canvas, cx, cy, xS, xE, gridPaint);

      final zS = _transform(offset, gridY, -R * 1.5, rY, rX);
      final zE = _transform(offset, gridY, R * 1.5, rY, rX);
      _drawGridLine(canvas, cx, cy, zS, zE, gridPaint);
    }
  }

  void _drawGridLine(Canvas canvas, double cx, double cy,
      List<double> start, List<double> end, Paint paint) {
    final s = Offset(cx + start[0], cy + start[1]);
    final e = Offset(cx + end[0], cy + end[1]);
    canvas.drawLine(s, e, paint);
  }

  // =========================================================================
  // Globe Wireframe (latitude + longitude circles)
  // =========================================================================

  void _drawGlobeWireframe(
      Canvas canvas, double cx, double cy, double R, double rY, double rX) {
    final latPaint = Paint()
      ..color = const Color(0xFF3FFF80).withValues(alpha: 0.35)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final lonPaint = Paint()
      ..color = const Color(0xFF3FFF80).withValues(alpha: 0.25)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const segments = 60;

    // Latitude circles
    const latCount = 12;
    for (int i = 1; i < latCount; i++) {
      final phi = (i / latCount - 0.5) * math.pi;
      final ringR = R * math.cos(phi);
      final ringY = R * math.sin(phi);

      final path = Path();
      bool drawing = false;

      for (int s = 0; s <= segments; s++) {
        final theta = (s / segments) * 2 * math.pi;
        final px = ringR * math.cos(theta);
        final pz = ringR * math.sin(theta);
        final p = _transform(px, ringY, pz, rY, rX);

        if (p[2] > -R * 0.15) {
          final sp = Offset(cx + p[0], cy + p[1]);
          if (!drawing) {
            path.moveTo(sp.dx, sp.dy);
            drawing = true;
          } else {
            path.lineTo(sp.dx, sp.dy);
          }
        } else {
          drawing = false;
        }
      }
      canvas.drawPath(path, latPaint);
    }

    // Longitude meridians
    const lonCount = 18;
    for (int i = 0; i < lonCount; i++) {
      final theta = (i / lonCount) * 2 * math.pi;

      final path = Path();
      bool drawing = false;

      for (int s = 0; s <= segments; s++) {
        final phi = (s / segments) * math.pi - math.pi / 2;
        final px = R * math.cos(phi) * math.cos(theta);
        final py = R * math.sin(phi);
        final pz = R * math.cos(phi) * math.sin(theta);
        final p = _transform(px, py, pz, rY, rX);

        if (p[2] > -R * 0.15) {
          final sp = Offset(cx + p[0], cy + p[1]);
          if (!drawing) {
            path.moveTo(sp.dx, sp.dy);
            drawing = true;
          } else {
            path.lineTo(sp.dx, sp.dy);
          }
        } else {
          drawing = false;
        }
      }
      canvas.drawPath(path, lonPaint);
    }
  }

  // =========================================================================
  // Spike / Ray Markers radiating from globe
  // =========================================================================

  void _drawSpikes(
      Canvas canvas, double cx, double cy, double R, double rY, double rX) {
    final spikePaint = Paint()
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Semi-random fixed spike directions via golden-angle distribution
    const spikeCount = 20;
    final rand = math.Random(7);

    for (int i = 0; i < spikeCount; i++) {
      final lat = math.asin(2.0 * i / spikeCount - 1.0);
      final lon = i * 2.399963; // golden angle in radians

      final dir = _transform(
        math.cos(lat) * math.cos(lon),
        math.sin(lat),
        math.cos(lat) * math.sin(lon),
        rY,
        rX,
      );

      // Only draw front-facing spikes
      if (dir[2] < 0.1) continue;

      final spikeLen = R * (0.15 + rand.nextDouble() * 0.25);
      final innerR = R * 1.02;
      final outerR = innerR + spikeLen;

      final sx = cx + dir[0] * innerR;
      final sy = cy + dir[1] * innerR;
      final ex = cx + dir[0] * outerR;
      final ey = cy + dir[1] * outerR;

      // Alpha based on depth (front = brighter)
      final alpha = ((dir[2] + 1.0) / 2.0).clamp(0.0, 1.0) * 0.5;
      spikePaint.color = const Color(0xFFCCCCEE).withValues(alpha: alpha);

      canvas.drawLine(Offset(sx, sy), Offset(ex, ey), spikePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _VantaGlobePainter old) => true;
}
