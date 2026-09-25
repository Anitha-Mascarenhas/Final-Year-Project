import 'dart:async';
import 'package:flutter/material.dart';

class CardSwapStack extends StatefulWidget {
  final List<Widget> cards;
  final double cardWidth;
  final double cardHeight;
  final double cardDistance;
  final double verticalDistance;
  final Duration autoSwapDuration;
  final Duration animDuration;
  final Curve curve;
  final int currentIndex;
  final bool autoPlay;
  final ValueChanged<int>? onCardChanged;

  const CardSwapStack({
    super.key,
    required this.cards,
    this.cardWidth = 330.0,
    this.cardHeight = 200.0,
    this.cardDistance = 16.0,
    this.verticalDistance = 12.0,
    this.autoSwapDuration = const Duration(seconds: 4),
    this.animDuration = const Duration(milliseconds: 900),
    this.curve = Curves.easeInOutCubic,
    this.currentIndex = 0,
    this.autoPlay = true,
    this.onCardChanged,
  });

  @override
  State<CardSwapStack> createState() => _CardSwapStackState();
}

class _CardSwapStackState extends State<CardSwapStack>
    with SingleTickerProviderStateMixin {
  late List<int> _order;
  late AnimationController _controller;
  late Animation<double> _animation;
  Timer? _timer;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    _order = List.generate(widget.cards.length, (index) => index);
    _syncFrontCard(widget.currentIndex);
    _controller = AnimationController(
      vsync: this,
      duration: widget.animDuration,
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: widget.curve,
    );

    _animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          final top = _order.removeAt(0);
          _order.add(top);
          _controller.reset();
          _isAnimating = false;
        });
        widget.onCardChanged?.call(_order.first);
      }
    });

    if (widget.autoPlay) {
      _startAutoSwap();
    }
  }

  @override
  void didUpdateWidget(covariant CardSwapStack oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.cards.length != oldWidget.cards.length) {
      _order = List.generate(widget.cards.length, (index) => index);
      _syncFrontCard(widget.currentIndex);
    }

    if (widget.currentIndex != oldWidget.currentIndex &&
        widget.currentIndex >= 0) {
      _syncFrontCard(widget.currentIndex);
    }

    if (widget.animDuration != oldWidget.animDuration) {
      _controller.duration = widget.animDuration;
    }

    if (widget.autoPlay != oldWidget.autoPlay) {
      if (widget.autoPlay) {
        _startAutoSwap();
      } else {
        _timer?.cancel();
      }
    }
  }

  void _syncFrontCard(int targetIndex) {
    if (widget.cards.isEmpty ||
        targetIndex < 0 ||
        targetIndex >= widget.cards.length) {
      return;
    }

    while (_order.first != targetIndex) {
      final top = _order.removeAt(0);
      _order.add(top);
    }
  }

  void _startAutoSwap() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.autoSwapDuration, (_) {
      if (!_isAnimating && mounted && widget.cards.length > 1) {
        _triggerSwap();
      }
    });
  }

  void _triggerSwap() {
    if (_isAnimating || widget.cards.length < 2) return;
    setState(() {
      _isAnimating = true;
    });
    _controller.forward();
  }

  Color _getSlotColor(double slot, int total) {
    final List<Color> colors = [
      const Color(0xFFFFFFFF), // Slot 0 (Front): Pure White
      const Color(0xFFDBE7DA), // Slot 1 (Middle): Medium Light Sage
      const Color(0xFFC3D5C1), // Slot 2 (Back): Darker Sage
    ];

    final maxIndex = (colors.length - 1).toDouble();
    final clamped = slot.clamp(0.0, maxIndex);
    final int index = clamped.floor();
    final double t = clamped - index;

    if (index >= colors.length - 1) return colors.last;
    return Color.lerp(colors[index], colors[index + 1], t)!;
  }

  Color _getSlotBorderColor(double slot, int total) {
    final List<Color> colors = [
      const Color(0xFFE2EBE2), // Slot 0 Border
      const Color(0xFFC7D7C9), // Slot 1 Border
      const Color(0xFFB4C7B3), // Slot 2 Border
    ];

    final maxIndex = (colors.length - 1).toDouble();
    final clamped = slot.clamp(0.0, maxIndex);
    final int index = clamped.floor();
    final double t = clamped - index;

    if (index >= colors.length - 1) return colors.last;
    return Color.lerp(colors[index], colors[index + 1], t)!;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cards.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = _order.length;

    return GestureDetector(
      onTap: _triggerSwap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: widget.cardWidth + (widget.cardDistance * (total - 1)),
        height: widget.cardHeight + (widget.verticalDistance * (total - 1)) + 16,
        child: AnimatedBuilder(
          animation: _animation,
          builder: (context, child) {
            final t = _animation.value;
            final renderList = <_CardRenderData>[];

            for (int slotIndex = 0; slotIndex < total; slotIndex++) {
              final cardIndex = _order[slotIndex];
              double xOffset;
              double yOffset;
              double scale;
              int zPriority;
              double fractionalSlot;

              if (slotIndex == 0) {
                final backSlot = total - 1;
                fractionalSlot = t * backSlot;
                if (t < 0.45) {
                  final dropProgress = t / 0.45;
                  xOffset = (widget.cardDistance * backSlot * 0.2) * dropProgress;
                  yOffset = 180.0 * dropProgress;
                  scale = 1.0 - (0.04 * dropProgress);
                  zPriority = 100;
                } else {
                  final returnProgress = (t - 0.45) / 0.55;
                  final startX = widget.cardDistance * backSlot * 0.2;
                  final targetX = widget.cardDistance * backSlot;
                  final startY = 180.0;
                  final targetY = -widget.verticalDistance * backSlot;

                  xOffset = startX + (targetX - startX) * returnProgress;
                  yOffset = startY + (targetY - startY) * returnProgress;
                  scale = 0.96 - (0.04 * returnProgress);
                  zPriority = 0;
                }
              } else {
                final currentSlot = slotIndex;
                final targetSlot = slotIndex - 1;
                fractionalSlot = currentSlot - t;

                final startX = widget.cardDistance * currentSlot;
                final targetX = widget.cardDistance * targetSlot;
                final startY = -widget.verticalDistance * currentSlot;
                final targetY = -widget.verticalDistance * targetSlot;

                xOffset = startX + (targetX - startX) * t;
                yOffset = startY + (targetY - startY) * t;
                scale = (1.0 - 0.04 * currentSlot) + (0.04 * t);
                zPriority = total - slotIndex;
              }

              renderList.add(
                _CardRenderData(
                  cardIndex: cardIndex,
                  xOffset: xOffset,
                  yOffset: yOffset,
                  scale: scale,
                  zPriority: zPriority,
                  fractionalSlot: fractionalSlot,
                ),
              );
            }

            renderList.sort((a, b) => a.zPriority.compareTo(b.zPriority));

            return Stack(
              alignment: Alignment.center,
              children: renderList.map((data) {
                final bgColor = _getSlotColor(data.fractionalSlot, total);
                final borderColor =
                    _getSlotBorderColor(data.fractionalSlot, total);
                final shadowOpacity = (0.05 *
                        (1.0 -
                            (data.fractionalSlot / (total - 1))
                                .clamp(0.0, 1.0)))
                    .clamp(0.0, 0.05);

                return Positioned(
                  key: ValueKey(data.cardIndex),
                  child: Transform.translate(
                    offset: Offset(data.xOffset, data.yOffset),
                    child: Transform.scale(
                      scale: data.scale,
                      child: Container(
                        width: widget.cardWidth,
                        height: widget.cardHeight,
                        decoration: BoxDecoration(
                          color: bgColor,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: borderColor, width: 1.5),
                          boxShadow: shadowOpacity > 0.001
                              ? [
                                  BoxShadow(
                                    color:
                                        Colors.black.withOpacity(shadowOpacity),
                                    blurRadius: 16,
                                    offset: const Offset(0, 8),
                                  ),
                                ]
                              : null,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: widget.cards[data.cardIndex],
                      ),
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}

class _CardRenderData {
  final int cardIndex;
  final double xOffset;
  final double yOffset;
  final double scale;
  final int zPriority;
  final double fractionalSlot;

  _CardRenderData({
    required this.cardIndex,
    required this.xOffset,
    required this.yOffset,
    required this.scale,
    required this.zPriority,
    required this.fractionalSlot,
  });
}
