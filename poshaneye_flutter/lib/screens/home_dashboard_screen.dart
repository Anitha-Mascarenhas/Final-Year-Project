import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/card_swap_stack.dart';
import '../widgets/interactive_eye_logo.dart';
import 'ai_scan_screen.dart';
import 'nutrition_plan_screen.dart';
import 'profile_screen.dart';
import 'role_selection_screen.dart';
import 'main_scaffold.dart';

/// Compatibility wrapper — redirects to MainScaffold.
class HomeDashboardScreen extends StatelessWidget {
  final String childName;

  const HomeDashboardScreen({
    Key? key,
    this.childName = 'Aarav',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MainScaffold(childName: childName, initialIndex: 0);
  }
}

/// Body content for the Home tab — no Scaffold, no bottom nav.
/// Rendered inside MainScaffold.
class HomeDashboardScreenBody extends StatefulWidget {
  final String childName;
  final ValueChanged<int>? onNavRequested;
  final VoidCallback? onScanPressed;

  const HomeDashboardScreenBody({
    Key? key,
    this.childName = 'Aarav',
    this.onNavRequested,
    this.onScanPressed,
  }) : super(key: key);

  @override
  State<HomeDashboardScreenBody> createState() =>
      _HomeDashboardScreenBodyState();
}

class _HomeDashboardScreenBodyState extends State<HomeDashboardScreenBody> {
  int _currentCardIndex = 0;
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = math.max(300.0, screenWidth - 44);

    return AppThemeTransition(
      isDark: _isDarkMode,
      child: Container(
        color: _isDarkMode ? const Color(0xFF14241B) : const Color(0xFFF7FAF7),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              _buildTopBar(),
              const SizedBox(height: 18),
              _buildGreeting(),
              const SizedBox(height: 22),
              _buildRotatingCardStack(cardWidth),
              const SizedBox(height: 14),
              _buildDotsIndicator(),
              const SizedBox(height: 26),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const InteractiveEyeLogo(
                width: 32,
                color: Color(0xFF163224),
              ),
              const SizedBox(width: 10),
              Text(
                'Home',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: _isDarkMode
                      ? const Color(0xFFE8F2EA)
                      : const Color(0xFF163224),
                ),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _isDarkMode = !_isDarkMode),
                child: Container(
                  width: 52,
                  height: 28,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: _isDarkMode
                        ? const Color(0xFF274233)
                        : const Color(0xFFD6E3D8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Align(
                    alignment: _isDarkMode
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2DE099),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isDarkMode
                            ? Icons.nightlight_round
                            : Icons.wb_sunny_rounded,
                        size: 13,
                        color: const Color(0xFF0C2417),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  if (widget.onNavRequested != null) {
                    widget.onNavRequested!(4);
                  } else {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(
                          childName: widget.childName,
                          onLogout: () {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (_) => const RoleSelectionScreen()),
                              (route) => false,
                            );
                          },
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF163224),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.9), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: Colors.white, size: 21),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getGreetingText() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildGreeting() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_getGreetingText()}, ${widget.childName}',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w900,
              color: _isDarkMode
                  ? const Color(0xFFE8F2EA)
                  : const Color(0xFF163224),
              letterSpacing: -0.8,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.childName} is doing well today.',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: _isDarkMode
                  ? const Color(0xFFA9C0B1)
                  : const Color(0xFF4D6053),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRotatingCardStack(double cardWidth) {
    return Container(
      height: 235,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: CardSwapStack(
        currentIndex: _currentCardIndex,
        onCardChanged: (index) => setState(() => _currentCardIndex = index),
        cardWidth: cardWidth,
        cardHeight: 190,
        cardDistance: 14,
        verticalDistance: 12,
        autoSwapDuration: const Duration(seconds: 5),
        animDuration: const Duration(milliseconds: 850),
        cards: [
          // Card 0: Current Vitals (Matching the reference screenshot exactly)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text(
                      'Current Vitals',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF163224),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Updated 2 days ago',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6C7C70),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildVitalColumn('Weight', '46.2', 'kg'),
                    _buildVitalColumn('Height', '149.9', 'cm'),
                    _buildVitalColumn('MUAC', '14.5', 'cm'),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),

          // Card 1: Growth Status Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF163224),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'GROWTH STATUS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.4,
                        color: Color(0xFF163224),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Normal Growth',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF163224),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${widget.childName} remains in the healthy percentile for their age group according to WHO standards.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF5A6C60),
                  ),
                ),
                const Spacer(),
                const Text(
                  'View growth details →',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF163224),
                  ),
                ),
              ],
            ),
          ),

          // Card 2: Assessment Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Color(0xFF163224),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'NUTRITION MILESTONES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.4,
                        color: Color(0xFF163224),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Optimal Nutrition',
                  style: TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF163224),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Analysis indicates optimal protein intake and balanced micro-nutrients.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF5A6C60),
                  ),
                ),
                const Spacer(),
                const Text(
                  'View nutrition plan →',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF163224),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVitalColumn(String label, String value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF4D6053),
          ),
        ),
        const SizedBox(height: 6),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF163224),
                  letterSpacing: -0.6,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF163224),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDotsIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isActive = _currentCardIndex == i;
        return GestureDetector(
          onTap: () => setState(() => _currentCardIndex = i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isActive ? 22 : 6,
            height: 6,
            decoration: BoxDecoration(
              color:
                  isActive ? const Color(0xFF163224) : const Color(0xFFB9CABC),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Primary Button: Start New Scan
          GestureDetector(
            onTap: () {
              if (widget.onScanPressed != null) {
                widget.onScanPressed!();
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AiScanScreen(childName: widget.childName),
                  ),
                );
              }
            },
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFF163224),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF163224).withOpacity(0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.crop_free_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Start New Scan',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Secondary Button: Nutrition Plan
          GestureDetector(
            onTap: () {
              if (widget.onNavRequested != null) {
                widget.onNavRequested!(3);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        NutritionPlanScreen(childName: widget.childName),
                  ),
                );
              }
            },
            child: Container(
              height: 58,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF163224),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(
                    Icons.flatware_rounded,
                    color: Color(0xFF163224),
                    size: 22,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Nutrition Plan',
                    style: TextStyle(
                      color: Color(0xFF163224),
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
