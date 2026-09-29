import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../state/vitals_provider.dart';
import '../state/nutrition_provider.dart';
import '../state/session_provider.dart';
import '../theme/app_theme.dart';
import '../utils/l10n_extension.dart';
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
class HomeDashboardScreenBody extends ConsumerStatefulWidget {
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
  ConsumerState<HomeDashboardScreenBody> createState() =>
      _HomeDashboardScreenBodyState();
}

class _HomeDashboardScreenBodyState
    extends ConsumerState<HomeDashboardScreenBody> {
  int _currentCardIndex = 0;
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshVitals());
  }

  Future<void> _refreshVitals() async {
    final session = ref.read(sessionProvider);
    if (session.childId == null || session.accessToken == null) return;
    try {
      await ref.read(vitalsProvider.notifier)
          .loadForChild(session.childId!, session.accessToken!);
    } catch (_) {
      // The Current Vitals card reads the shared error state and offers retry.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (previous, next) {
      if (previous?.childId != next.childId ||
          previous?.accessToken != next.accessToken) {
        _refreshVitals();
      }
    });
    final latestVitals = ref.watch(latestVitalsProvider);
    final vitalsLoadError = ref.watch(vitalsHistoryErrorProvider);
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
              _buildRotatingCardStack(cardWidth, latestVitals, vitalsLoadError),
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
    final l10n = context.l10n;
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
                l10n.navHome,
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
    final l10n = context.l10n;
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.goodMorning;
    if (hour < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  Widget _buildGreeting() {
    final l10n = context.l10n;
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
            l10n.doingWellSubtitle(widget.childName),
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

  Widget _buildRotatingCardStack(
      double cardWidth, VitalsRecord? latestVitals, String? vitalsLoadError) {
    final l10n = context.l10n;
    final cachedNutrition = ref.watch(nutritionRecommendationProvider);
    final childId = ref.watch(sessionProvider).childId;
    final nutritionPlan = cachedNutrition != null && cachedNutrition['child_id'] == childId
        ? cachedNutrition['nutrition_plan'] as Map?
        : null;
    return Container(
      // Allow room for the full vitals card and the two stacked cards behind it.
      height: 278,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      child: CardSwapStack(
        currentIndex: _currentCardIndex,
        onCardChanged: (index) => setState(() => _currentCardIndex = index),
        cardWidth: cardWidth,
        cardHeight: 252,
        cardDistance: 14,
        verticalDistance: 12,
        autoSwapDuration: const Duration(seconds: 5),
        animDuration: const Duration(milliseconds: 850),
        cards: [
          // Card 0: Current Vitals
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.currentVitals,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF163224),
                        letterSpacing: -0.3,
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          latestVitals?.recordedAt == null
                              ? 'Not recorded'
                              : DateFormat('d MMM yyyy')
                                  .format(latestVitals!.recordedAt!),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6C7C70),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Refresh vitals',
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints.tightFor(
                              width: 36, height: 36),
                          onPressed: _refreshVitals,
                          icon: const Icon(Icons.refresh_rounded,
                              size: 18, color: Color(0xFF6C7C70)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                        child: _buildVitalColumn(
                            l10n.weightLabel,
                            latestVitals?.weightKg == null
                                ? 'Not recorded'
                                : '${latestVitals!.weightKg} kg',
                            '')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildVitalColumn(
                            l10n.heightLabel,
                            latestVitals?.heightCm == null
                                ? 'Not recorded'
                                : '${latestVitals!.heightCm} cm',
                            '')),
                    const SizedBox(width: 8),
                    Expanded(
                        child: _buildVitalColumn(
                            l10n.muacLabel,
                            latestVitals?.muacCm == null
                                ? 'Not recorded'
                                : '${latestVitals!.muacCm} cm',
                            '')),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                    'Age: ${latestVitals?.ageLabel ?? 'Not recorded'}  •  Gender: ${latestVitals?.gender ?? 'Not recorded'}  •  BMI: ${latestVitals?.formattedBmi ?? 'Not recorded'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF4D6053))),
                const SizedBox(height: 2),
                Text(
                    'Head circumference: ${VitalsRecord.value(latestVitals?.headCircumferenceCm, 'cm')}  •  Waist: ${VitalsRecord.value(latestVitals?.waistCm, 'cm')}',
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF4D6053))),
                if (vitalsLoadError != null)
                  const Text('Unable to refresh saved vitals.',
                      style: TextStyle(fontSize: 10, color: Colors.redAccent)),
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
                    Text(
                      l10n.growthStatusHeader,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.4,
                        color: Color(0xFF163224),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.normalGrowthTitle,
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF163224),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.growthStatusDesc(widget.childName),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF5A6C60),
                  ),
                ),
                const Spacer(),
                Text(
                  l10n.viewGrowthDetails,
                  style: const TextStyle(
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
                    Text(
                      l10n.nutritionMilestonesHeader,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.4,
                        color: Color(0xFF163224),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Personalized nutrition plan',
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF163224),
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  nutritionPlan?['summary']?.toString() ??
                      'Open the plan to generate guidance from the latest screening history.',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: Color(0xFF5A6C60),
                  ),
                ),
                const Spacer(),
                Text(
                  l10n.viewNutritionPlan,
                  style: const TextStyle(
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
        Text(
          unit.isEmpty ? value : '$value $unit',
          softWrap: true,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: Color(0xFF163224),
            letterSpacing: -0.3,
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
    final l10n = context.l10n;
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
                children: [
                  const Icon(
                    Icons.crop_free_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.startNewScan,
                    style: const TextStyle(
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
                children: [
                  const Icon(
                    Icons.flatware_rounded,
                    color: Color(0xFF163224),
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    l10n.nutritionPlanBtn,
                    style: const TextStyle(
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
