import 'dart:math' as math;
import 'package:flutter/material.dart';

class InteractiveBottomNav extends StatefulWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onScanPressed;

  const InteractiveBottomNav({
    Key? key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onScanPressed,
  }) : super(key: key);

  @override
  State<InteractiveBottomNav> createState() => _InteractiveBottomNavState();
}

class _InteractiveBottomNavState extends State<InteractiveBottomNav>
    with SingleTickerProviderStateMixin {
  int? _elevatedIndex;

  late final AnimationController _physicsTicker;
  final List<GlobalKey> _itemKeys = List.generate(5, (_) => GlobalKey());
  final List<double> _itemCenterXs = [];
  late List<double> _scales;
  late List<double> _yLifts;
  late List<double> _dxDrifts;
  Offset? _pointerPosition;
  bool _isInteracting = false;

  final List<String> _labels = [
    'Home',
    'Growth',
    'Scan',
    'Nutrition',
    'Profile'
  ];

  @override
  void initState() {
    super.initState();
    _scales = List.filled(_itemKeys.length, 1.0);
    _yLifts = List.filled(_itemKeys.length, 0.0);
    _dxDrifts = List.filled(_itemKeys.length, 0.0);
    _physicsTicker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_updatePhysics);
    _physicsTicker.repeat();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureItemCenters());
  }

  void _measureItemCenters() {
    _itemCenterXs
      ..clear()
      ..addAll(List<double>.filled(_itemKeys.length, 0));

    for (int i = 0; i < _itemKeys.length; i++) {
      final itemContext = _itemKeys[i].currentContext;
      final renderObject = itemContext?.findRenderObject();
      if (renderObject is RenderBox && renderObject.hasSize) {
        final position = renderObject.localToGlobal(Offset.zero);
        _itemCenterXs[i] = position.dx + renderObject.size.width / 2;
      }
    }
  }

  void _updatePhysics() {
    if (!mounted) return;

    const lerpFactor = 0.22;
    bool needsUpdate = false;

    for (int i = 0; i < _itemKeys.length; i++) {
      double targetScale = 1.0;
      double targetY = 0.0;
      double targetDx = 0.0;

      if (_isInteracting &&
          _pointerPosition != null &&
          _itemCenterXs.length == _itemKeys.length) {
        final distance = _pointerPosition!.dx - _itemCenterXs[i];
        const sigma = 78.0;
        final influence =
            math.exp(-(distance * distance) / (2 * sigma * sigma));
        targetScale = 1.0 + (1.3 - 1.0) * influence;
        targetY = -16.0 * influence;
        targetDx = distance * 0.13 * influence;
      }

      final nextScale = _scales[i] + (targetScale - _scales[i]) * lerpFactor;
      final nextY = _yLifts[i] + (targetY - _yLifts[i]) * lerpFactor;
      final nextDx = _dxDrifts[i] + (targetDx - _dxDrifts[i]) * lerpFactor;

      if ((nextScale - _scales[i]).abs() > 0.001 ||
          (nextY - _yLifts[i]).abs() > 0.001 ||
          (nextDx - _dxDrifts[i]).abs() > 0.001) {
        needsUpdate = true;
      }

      _scales[i] = nextScale;
      _yLifts[i] = nextY;
      _dxDrifts[i] = nextDx;
    }

    if (needsUpdate) setState(() {});
  }

  void _handlePointerUp(Offset globalPosition) {
    _measureItemCenters();
    int bestIndex = -1;
    double closestDistance = 55.0;

    for (int i = 0; i < _itemCenterXs.length; i++) {
      final distance = (globalPosition.dx - _itemCenterXs[i]).abs();
      if (distance < closestDistance) {
        closestDistance = distance;
        bestIndex = i;
      }
    }

    if (bestIndex >= 0 && bestIndex != 2) {
      widget.onTabSelected(bestIndex);
    } else if (bestIndex == 2) {
      widget.onScanPressed();
    }

    setState(() {
      _isInteracting = false;
      _pointerPosition = null;
      _elevatedIndex = null;
    });
  }

  @override
  void dispose() {
    _physicsTicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (event) {
        _measureItemCenters();
        setState(() {
          _isInteracting = true;
          _pointerPosition = event.position;
        });
      },
      onPointerMove: (event) =>
          setState(() => _pointerPosition = event.position),
      onPointerUp: (event) => _handlePointerUp(event.position),
      onPointerCancel: (_) {
        setState(() {
          _isInteracting = false;
          _pointerPosition = null;
          _elevatedIndex = null;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF7FAF7).withOpacity(0.96),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: const Color(0xFF163224).withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFE2EBE2),
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildNavItem(0, Icons.home_rounded),
            _buildNavItem(1, Icons.trending_up_rounded),
            _buildScanButton(),
            _buildNavItem(3, Icons.flatware_rounded),
            _buildNavItem(4, Icons.person_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon) {
    final isSelected = widget.currentIndex == index;
    final isElevated = _elevatedIndex == index;

    return Container(
      key: _itemKeys[index],
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: Transform.translate(
        offset: Offset(_dxDrifts[index], _yLifts[index]),
        child: Transform.scale(
          scale: _scales[index],
          child: GestureDetector(
            onTapDown: (_) => setState(() => _elevatedIndex = index),
            onTapUp: (_) => setState(() => _elevatedIndex = null),
            onTapCancel: () => setState(() => _elevatedIndex = null),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Floating elevated bubble
                if (isElevated)
                  Positioned(
                    top: -42,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: 1.0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF163224),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFF2DE099).withOpacity(0.6)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon,
                                size: 16, color: const Color(0xFF2DE099)),
                            Text(
                              _labels[index],
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Base nav item: rounded tile matching screenshot
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutBack,
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF163224),
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected
                            ? Border.all(
                                color: const Color(0xFF2DE099), width: 2.2)
                            : null,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF163224).withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        icon,
                        color: isSelected
                            ? Colors.white
                            : Colors.white.withOpacity(0.75),
                        size: 23,
                      ),
                    ),
                    const SizedBox(height: 4),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isSelected ? 6 : 0,
                      height: isSelected ? 6 : 0,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2DE099),
                        shape: BoxShape.circle,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF2DE099).withOpacity(0.8),
                                  blurRadius: 6,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanButton() {
    return Container(
      key: _itemKeys[2],
      margin: const EdgeInsets.symmetric(horizontal: 2),
      child: Transform.translate(
        offset: Offset(_dxDrifts[2], _yLifts[2]),
        child: Transform.scale(
          scale: _scales[2],
          child: GestureDetector(
            onTap: widget.onScanPressed,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFF2DE099),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2DE099).withOpacity(0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.crop_free_rounded,
                color: Color(0xFF0C2417),
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

