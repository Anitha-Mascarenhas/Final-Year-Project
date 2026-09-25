import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/vitals_provider.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';
import '../widgets/interactive_eye_logo.dart';

/// Standalone screen version of Growth Tracking (pushed via Navigator).
/// Has its own Scaffold + back navigation, no bottom nav.
class GrowthTrackingScreen extends ConsumerStatefulWidget {
  final String childName;

  const GrowthTrackingScreen({
    Key? key,
    this.childName = 'Aarav',
  }) : super(key: key);

  @override
  ConsumerState<GrowthTrackingScreen> createState() => _GrowthTrackingScreenState();
}

/// Body-only version of Growth Tracking (rendered inside MainScaffold for tab 1).
/// No Scaffold, no bottom nav.
class GrowthTrackingScreenBody extends ConsumerStatefulWidget {
  final String childName;

  const GrowthTrackingScreenBody({
    Key? key,
    this.childName = 'Aarav',
  }) : super(key: key);

  @override
  ConsumerState<GrowthTrackingScreenBody> createState() => _GrowthTrackingBodyState();
}

class _GrowthTrackingScreenState extends ConsumerState<GrowthTrackingScreen>
    with SingleTickerProviderStateMixin, _GrowthTrackingMixin {
  @override
  String get childName => widget.childName;

  @override
  Widget build(BuildContext context) {
    return AppThemeTransition(
      isDark: _isDarkMode,
      child: Scaffold(
        backgroundColor:
            _isDarkMode ? const Color(0xFF14241B) : const Color(0xFFEAF1E9),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, canPop: true),
                const SizedBox(height: 6),
                _buildTitleSection(),
                const SizedBox(height: 10),
                _buildSegmentControl(),
                const SizedBox(height: 12),
                if (_selectedSegment == 0) ...[
                  _buildCurrentStatusCard(),
                  const SizedBox(height: 10),
                  _buildDualMetrics(),
                  const SizedBox(height: 10),
                  _buildMetricTabs(),
                  const SizedBox(height: 10),
                  _buildChartCard(),
                  const SizedBox(height: 10),
                  _buildLogMeasurementCard(),
                ] else ...[
                  _buildCalculatorView(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GrowthTrackingBodyState extends ConsumerState<GrowthTrackingScreenBody>
    with SingleTickerProviderStateMixin, _GrowthTrackingMixin {
  @override
  String get childName => widget.childName;

  @override
  Widget build(BuildContext context) {
    return AppThemeTransition(
      isDark: _isDarkMode,
      child: Container(
        color: _isDarkMode ? const Color(0xFF14241B) : const Color(0xFFEAF1E9),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, canPop: false),
              const SizedBox(height: 6),
              _buildTitleSection(),
              const SizedBox(height: 10),
              _buildSegmentControl(),
              const SizedBox(height: 12),
              if (_selectedSegment == 0) ...[
                _buildCurrentStatusCard(),
                const SizedBox(height: 10),
                _buildDualMetrics(),
                const SizedBox(height: 10),
                _buildMetricTabs(),
                const SizedBox(height: 10),
                _buildChartCard(),
                const SizedBox(height: 10),
                _buildLogMeasurementCard(),
              ] else ...[
                _buildCalculatorView(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class GrowthVitalsCalculatorScreen extends ConsumerStatefulWidget {
  final String childName;
  final void Function(double weight, double height)? onSaved;

  const GrowthVitalsCalculatorScreen({
    Key? key,
    this.childName = 'Aarav',
    this.onSaved,
  }) : super(key: key);

  @override
  ConsumerState<GrowthVitalsCalculatorScreen> createState() =>
      _GrowthVitalsCalculatorScreenState();
}

class _GrowthVitalsCalculatorScreenState
    extends ConsumerState<GrowthVitalsCalculatorScreen>
    with SingleTickerProviderStateMixin, _GrowthTrackingMixin {
  @override
  String get childName => widget.childName;

  @override
  void Function(double weight, double height)? get onCalculatorSaved =>
      widget.onSaved;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEAF1E9),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: _buildCalculatorView(),
        ),
      ),
    );
  }
}

// Shared mixin holding all state and build methods for Growth Tracking.
mixin _GrowthTrackingMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T>, SingleTickerProviderStateMixin<T> {
  // Subclass must provide childName
  String get childName;
  void Function(double weight, double height)? get onCalculatorSaved => null;

  int _selectedSegment = 0; // 0: Trends, 1: Calculator
  int _selectedMetric = 0; // 0: Weight, 1: Height, 2: MUAC
  bool _isDarkMode = false;
  int? _selectedMilestoneIndex;

  // Calculator wizard state
  int _calcStep = 1;
  String _calcGender = 'Boy';
  int _calcAgeYears = 2;
  int _calcAgeMonths = 3;
  late final TextEditingController _ageYearsController;
  double _calcWeight = 14.2;
  double _calcHeight = 92.5;
  late final TextEditingController _weightController;
  late final TextEditingController _heightController;
  late final FocusNode _weightFocusNode;
  late final FocusNode _heightFocusNode;
  double _currentWeight = 14.2;
  double _currentHeight = 92.5;
  String _currentPercentile = '75th percentile';

  late AnimationController _counterController;
  late Animation<double> _counterAnimation;

  final List<String> _metricTitles = ['Weight', 'Height', 'Muac'];

  // Milestones per metric
  final List<Map<String, dynamic>> _weightMilestones = [
    {'age': 'Birth', 'who': 3.3, 'child': 3.9, 'unit': 'kg'},
    {'age': '6 M', 'who': 7.3, 'child': 8.0, 'unit': 'kg'},
    {'age': '12 M', 'who': 9.6, 'child': 10.2, 'unit': 'kg'},
    {'age': '18 M', 'who': 11.5, 'child': 12.0, 'unit': 'kg'},
    {'age': '24 M', 'who': 12.8, 'child': 14.2, 'unit': 'kg'},
  ];

  final List<Map<String, dynamic>> _heightMilestones = [
    {'age': 'Birth', 'who': 49.5, 'child': 50.0, 'unit': 'cm'},
    {'age': '6 M', 'who': 65.5, 'child': 67.0, 'unit': 'cm'},
    {'age': '12 M', 'who': 74.0, 'child': 76.0, 'unit': 'cm'},
    {'age': '18 M', 'who': 80.5, 'child': 82.5, 'unit': 'cm'},
    {'age': '24 M', 'who': 86.5, 'child': 88.5, 'unit': 'cm'},
  ];

  final List<Map<String, dynamic>> _muacMilestones = [
    {'age': 'Birth', 'who': 11.0, 'child': 11.5, 'unit': 'cm'},
    {'age': '6 M', 'who': 13.2, 'child': 13.8, 'unit': 'cm'},
    {'age': '12 M', 'who': 13.8, 'child': 14.2, 'unit': 'cm'},
    {'age': '18 M', 'who': 14.1, 'child': 14.4, 'unit': 'cm'},
    {'age': '24 M', 'who': 14.3, 'child': 14.5, 'unit': 'cm'},
  ];

  @override
  void initState() {
    super.initState();
    _ageYearsController = TextEditingController(text: '$_calcAgeYears');
    _weightController =
        TextEditingController(text: _calcWeight.toStringAsFixed(1));
    _heightController =
        TextEditingController(text: _calcHeight.toStringAsFixed(1));
    _weightFocusNode = FocusNode();
    _heightFocusNode = FocusNode();
    _counterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _counterAnimation = CurvedAnimation(
      parent: _counterController,
      curve: Curves.easeOutCubic,
    );
    _counterController.forward();
  }

  @override
  void dispose() {
    _ageYearsController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _weightFocusNode.dispose();
    _heightFocusNode.dispose();
    _counterController.dispose();
    super.dispose();
  }

  void _updateCalcAgeYears(int newYears) {
    final clamped = newYears.clamp(0, 25);
    setState(() {
      _calcAgeYears = clamped;
      _ageYearsController.text = '$clamped';
      _ageYearsController.selection = TextSelection.fromPosition(
        TextPosition(offset: _ageYearsController.text.length),
      );
    });
  }

  List<Map<String, dynamic>> get _currentMilestones {
    if (_selectedMetric == 0) return _weightMilestones;
    if (_selectedMetric == 1) return _heightMilestones;
    return _muacMilestones;
  }

  // build() is defined in each concrete State class — not in the mixin.

  Widget _buildHeader(BuildContext context, {bool canPop = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (canPop)
                IconButton(
                  icon: Icon(
                    Icons.arrow_back,
                    color: _isDarkMode
                        ? const Color(0xFFE8F2EA)
                        : const Color(0xFF0C2417),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.forestGreen.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const InteractiveEyeLogo(
                  width: 22,
                  color: AppColors.forestGreen,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Growth Tracking',
                style: TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w800,
                  color: _isDarkMode
                      ? const Color(0xFFE8F2EA)
                      : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _isDarkMode = !_isDarkMode),
                child: Container(
                  width: 44,
                  height: 24,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBE6DB),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Align(
                    alignment: _isDarkMode
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2AE196),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isDarkMode
                            ? Icons.nightlight_round
                            : Icons.wb_sunny_rounded,
                        size: 12,
                        color: const Color(0xFF0C2417),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.forestGreen,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.person_rounded,
                    color: Colors.white, size: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Growth Tracking',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color:
                  _isDarkMode ? const Color(0xFFE8F2EA) : AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "Monitor ${childName}'s development milestones.",
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _isDarkMode
                  ? const Color(0xFFA9C0B1)
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentControl() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFFDCE6DC),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  setState(() => _selectedSegment = 0);
                  _counterController.forward(from: 0.0);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedSegment == 0
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'GROWTH TRENDS',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: _selectedSegment == 0
                            ? const Color(0xFF0C2417)
                            : const Color(0xFF5A7263),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedSegment = 1),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: _selectedSegment == 1
                        ? Colors.white
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'CALCULATOR',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: _selectedSegment == 1
                            ? const Color(0xFF0C2417)
                            : const Color(0xFF5A7263),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        childName: childName,
                        initialHistoryView: true,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      'HISTORY',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5A7263),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatusCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.forestGreen,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: AppColors.forestGreen.withOpacity(0.2),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.auto_awesome, color: Color(0xFF2AE196), size: 14),
                SizedBox(width: 6),
                Text(
                  'CURRENT STATUS',
                  style: TextStyle(
                    color: Color(0xFF2AE196),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'On Track',
              style: TextStyle(
                color: Colors.white,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'WHO Percentile: 75th percentile',
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Count-up dual metrics (3.9 -> 14.2 kg & 25.3 -> 92.5 cm as in video 00:02-00:03)
  Widget _buildDualMetrics() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedBuilder(
        animation: _counterAnimation,
        builder: (context, child) {
          final w =
              (3.9 + (14.2 - 3.9) * _counterAnimation.value).toStringAsFixed(1);
          final h = (25.3 + (92.5 - 25.3) * _counterAnimation.value)
              .toStringAsFixed(1);

          return Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2EAE2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8F5E9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.scale_rounded,
                                size: 16, color: Color(0xFF0F3827)),
                          ),
                          const SizedBox(width: 6),
                          const Text('WEIGHT',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF667D6F))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(w,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace')),
                          const SizedBox(width: 3),
                          const Text('kg',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('75TH PERCENTILE',
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF065F46))),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2EAE2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: Color(0xFFE8F5E9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.straighten_rounded,
                                size: 16, color: Color(0xFF0F3827)),
                          ),
                          const SizedBox(width: 6),
                          const Text('HEIGHT',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF667D6F))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(h,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'monospace')),
                          const SizedBox(width: 3),
                          const Text('cm',
                              style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD1FAE5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('WHO NORMAL BAND',
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF065F46))),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(3, (i) {
          final isSel = _selectedMetric == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedMetric = i;
                  _selectedMilestoneIndex = null;
                });
              },
              child: Container(
                margin: EdgeInsets.only(right: i < 2 ? 8 : 0),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color:
                      isSel ? const Color(0xFF0F3827) : const Color(0xFFD8E3D8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    _metricTitles[i].toUpperCase(),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: isSel ? Colors.white : const Color(0xFF556D5E),
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildChartCard() {
    final title = '${_metricTitles[_selectedMetric]} Progress Curve';
    final milestones = _currentMilestones;
    final activeData = _selectedMilestoneIndex != null
        ? milestones[_selectedMilestoneIndex!]
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2EAE2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0C2417))),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: Stack(
                children: [
                  CustomPaint(
                    size: const Size(double.infinity, 120),
                    painter: _GrowthCurvePainter(
                      selectedIndex: _selectedMilestoneIndex,
                    ),
                  ),
                  if (activeData != null)
                    Positioned(
                      left: 40.0 +
                          (_selectedMilestoneIndex! * 50.0).clamp(0.0, 160.0),
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2EAE2)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(activeData['age'],
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(
                                '• WHO Standard: ${activeData['who']} ${activeData['unit']}',
                                style: const TextStyle(
                                    fontSize: 11, color: Color(0xFF556D5E))),
                            Text(
                                '• Child Growth: ${activeData['child']} ${activeData['unit']}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F3827))),
                          ],
                        ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(milestones.length, (idx) {
                        final isSel = _selectedMilestoneIndex == idx;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedMilestoneIndex = isSel ? null : idx;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? const Color(0xFF0C2417)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              milestones[idx]['age'],
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight:
                                    isSel ? FontWeight.bold : FontWeight.w600,
                                color: isSel
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogMeasurementCard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE2EAE2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Want to calculate & log a new measurement for ${childName}?',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF445B4E),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => GrowthVitalsCalculatorScreen(
                      childName: childName,
                      onSaved: (weight, height) {
                        setState(() {
                          _currentWeight = weight;
                          _currentHeight = height;
                          _weightMilestones[4]['child'] = weight;
                          _heightMilestones[4]['child'] = height;
                          _selectedMilestoneIndex = null;
                          _counterController.forward(from: 0.0);
                        });
                      },
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.forestGreen,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.add, size: 18),
                  SizedBox(width: 6),
                  Text('Log New Vitals',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalculatorView() {
    final isAgeValid = _calcAgeYears >= 0 && _calcAgeYears <= 18;
    final isWeightValid = _calcWeight >= 2.0 && _calcWeight <= 80.0;
    final isHeightValid = _calcHeight >= 45.0 && _calcHeight <= 190.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Progress bar (e.g. 1/5, 2/5)
          Row(
            children: [
              if (_calcStep > 1)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0C2417)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _calcStep--),
                )
              else
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF0C2417)),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => setState(() => _selectedSegment = 0),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _calcStep / 5.0,
                    backgroundColor: const Color(0xFFDBE6DB),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Color(0xFF84CC16)),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$_calcStep/5',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF5A7263),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // STEP 1: Select Gender
          if (_calcStep == 1) ...[
            const Text('WHO GROWTH STANDARDS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF556D5E),
                    letterSpacing: 0.8)),
            const SizedBox(height: 4),
            const Text('Select gender',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0C2417))),
            const SizedBox(height: 4),
            const Text(
                'Gender helps us compare measurements with the right WHO growth standard.',
                style: TextStyle(fontSize: 13, color: Color(0xFF5A7263))),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _calcGender = 'Boy'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: _calcGender == 'Boy'
                            ? const Color(0xFFECF7ED)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _calcGender == 'Boy'
                              ? const Color(0xFF10B981)
                              : const Color(0xFFE2EAE2),
                          width: _calcGender == 'Boy' ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: _calcGender == 'Boy'
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : const Color(0xFFF3F4F6),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: CustomPaint(
                                size: const Size(36, 44),
                                painter: _BoySilhouettePainter(
                                  color: _calcGender == 'Boy'
                                      ? const Color(0xFF0C2417)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text('Boy',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0C2417))),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _calcGender = 'Girl'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      decoration: BoxDecoration(
                        color: _calcGender == 'Girl'
                            ? const Color(0xFFECF7ED)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _calcGender == 'Girl'
                              ? const Color(0xFF10B981)
                              : const Color(0xFFE2EAE2),
                          width: _calcGender == 'Girl' ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: _calcGender == 'Girl'
                                  ? const Color(0xFF10B981).withValues(alpha: 0.15)
                                  : const Color(0xFFF3F4F6),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: CustomPaint(
                                size: const Size(36, 44),
                                painter: _GirlSilhouettePainter(
                                  color: _calcGender == 'Girl'
                                      ? const Color(0xFF0C2417)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text('Girl',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0C2417))),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ]

          // STEP 2: Enter Age
          else if (_calcStep == 2) ...[
            const Text('WHO GROWTH STANDARDS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF556D5E),
                    letterSpacing: 0.8)),
            const SizedBox(height: 4),
            const Text('Enter age',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0C2417))),
            const SizedBox(height: 4),
            const Text("Choose the child's age in years and months.",
                style: TextStyle(fontSize: 13, color: Color(0xFF5A7263))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2EAE2)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Listener(
                    onPointerSignal: (pointerSignal) {
                      if (pointerSignal is PointerScrollEvent) {
                        if (pointerSignal.scrollDelta.dy > 0) {
                          _updateCalcAgeYears(_calcAgeYears - 1);
                        } else if (pointerSignal.scrollDelta.dy < 0) {
                          _updateCalcAgeYears(_calcAgeYears + 1);
                        }
                      }
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onVerticalDragUpdate: (details) {
                        if (details.primaryDelta! < -5) {
                          _updateCalcAgeYears(_calcAgeYears + 1);
                        } else if (details.primaryDelta! > 5) {
                          _updateCalcAgeYears(_calcAgeYears - 1);
                        }
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (_calcAgeYears > 0)
                            GestureDetector(
                              onTap: () =>
                                  _updateCalcAgeYears(_calcAgeYears - 1),
                              child: Text('${_calcAgeYears - 1}',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      color: Color(0xFFCBD5E1),
                                      fontWeight: FontWeight.w600)),
                            )
                          else
                            const SizedBox(height: 22),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IntrinsicWidth(
                                child: TextField(
                                  controller: _ageYearsController,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(2),
                                  ],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 52,
                                    fontWeight: FontWeight.w900,
                                    color: isAgeValid
                                        ? const Color(0xFF0C2417)
                                        : const Color(0xFFEF4444),
                                  ),
                                  cursorColor: isAgeValid
                                      ? const Color(0xFF0C2417)
                                      : const Color(0xFFEF4444),
                                  cursorWidth: 3.0,
                                  cursorHeight: 42.0,
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    disabledBorder: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.zero,
                                  ),
                                  onChanged: (val) {
                                    final parsed = int.tryParse(val);
                                    if (parsed != null) {
                                      setState(() {
                                        _calcAgeYears = parsed.clamp(0, 25);
                                      });
                                    } else if (val.isEmpty) {
                                      setState(() {
                                        _calcAgeYears = 0;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () =>
                                _updateCalcAgeYears(_calcAgeYears + 1),
                            child: Text('${_calcAgeYears + 1}',
                                style: const TextStyle(
                                    fontSize: 18,
                                    color: Color(0xFFCBD5E1),
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isAgeValid)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Age exceeds standard WHO chart (max 18)',
                          style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2EAE2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('MONTHS',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF556D5E))),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove, size: 16),
                        onPressed: () => setState(() =>
                            _calcAgeMonths = (_calcAgeMonths - 1).clamp(0, 11)),
                      ),
                      Text('$_calcAgeMonths',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add, size: 16),
                        onPressed: () => setState(() =>
                            _calcAgeMonths = (_calcAgeMonths + 1).clamp(0, 11)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ]

          // STEP 3: Enter Weight (Measurement Scale)
          else if (_calcStep == 3) ...[
            const Text('WHO GROWTH STANDARDS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF556D5E),
                    letterSpacing: 0.8)),
            const SizedBox(height: 4),
            const Text('Enter weight',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0C2417))),
            const SizedBox(height: 4),
            const Text('Move the dial to set the latest measured weight.',
                style: TextStyle(fontSize: 13, color: Color(0xFF5A7263))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: isWeightValid
                        ? const Color(0xFFE2EAE2)
                        : const Color(0xFFEF4444).withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  // Arch Dial Gauge Widget
                  Center(
                    child: Listener(
                      onPointerSignal: (pointerSignal) {
                        if (pointerSignal is PointerScrollEvent) {
                          final delta = pointerSignal.scrollDelta.dy / 10.0;
                          final next =
                              (_calcWeight + delta).clamp(2.0, 80.0);
                          setState(() {
                            _calcWeight =
                                double.parse(next.toStringAsFixed(1));
                            if (!_weightFocusNode.hasFocus) {
                              _weightController.text =
                                  _calcWeight.toStringAsFixed(1);
                            }
                          });
                        }
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onHorizontalDragUpdate: (details) {
                          final delta = details.primaryDelta! / 5.0;
                          final next =
                              (_calcWeight + delta).clamp(2.0, 80.0);
                          setState(() {
                            _calcWeight =
                                double.parse(next.toStringAsFixed(1));
                            if (!_weightFocusNode.hasFocus) {
                              _weightController.text =
                                  _calcWeight.toStringAsFixed(1);
                            }
                          });
                        },
                        child: SizedBox(
                          width: 280,
                          height: 220,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: const Size(280, 220),
                                painter: _WeightDialPainter(
                                  value: _calcWeight,
                                  activeColor: isWeightValid
                                      ? const Color(0xFF86BF15)
                                      : const Color(0xFFEF4444),
                                ),
                              ),
                              Positioned(
                                top: 50,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IntrinsicWidth(
                                          child: TextField(
                                            controller: _weightController,
                                            focusNode: _weightFocusNode,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            inputFormatters: [
                                              FilteringTextInputFormatter.allow(
                                                  RegExp(r'^\d*\.?\d{0,1}')),
                                            ],
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 48,
                                              fontWeight: FontWeight.w900,
                                              color: isWeightValid
                                                  ? const Color(0xFF0C2417)
                                                  : const Color(0xFFEF4444),
                                              fontFamily: 'monospace',
                                              letterSpacing: -1,
                                            ),
                                            cursorColor: isWeightValid
                                                ? const Color(0xFF0C2417)
                                                : const Color(0xFFEF4444),
                                            cursorWidth: 3.0,
                                            cursorHeight: 40.0,
                                            decoration: const InputDecoration(
                                              border: InputBorder.none,
                                              focusedBorder: InputBorder.none,
                                              enabledBorder: InputBorder.none,
                                              errorBorder: InputBorder.none,
                                              disabledBorder: InputBorder.none,
                                              isDense: true,
                                              contentPadding: EdgeInsets.zero,
                                            ),
                                            onChanged: (val) {
                                              final parsed =
                                                  double.tryParse(val);
                                              if (parsed != null) {
                                                setState(() {
                                                  _calcWeight =
                                                      parsed.clamp(2.0, 80.0);
                                                });
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'kg',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: isWeightValid
                                            ? const Color(0xFF556D5E)
                                            : const Color(0xFFEF4444),
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!isWeightValid)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Invalid weight: Must be 2 kg to 80 kg',
                          style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ]

          // STEP 4: Enter Height (Measurement Ruler)
          else if (_calcStep == 4) ...[
            const Text('WHO GROWTH STANDARDS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF556D5E),
                    letterSpacing: 0.8)),
            const SizedBox(height: 4),
            const Text('Enter height',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0C2417))),
            const SizedBox(height: 4),
            const Text('Move the ruler to set the latest measured height.',
                style: TextStyle(fontSize: 13, color: Color(0xFF5A7263))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: isHeightValid
                        ? const Color(0xFFE2EAE2)
                        : const Color(0xFFEF4444).withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  // Central Vertical Ruler Box
                  Center(
                    child: Container(
                      width: 210,
                      height: 270,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF6EC),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: isHeightValid
                              ? const Color(0xFFD3E4D1)
                              : const Color(0xFFEF4444).withValues(alpha: 0.4),
                          width: 1.5,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Listener(
                          onPointerSignal: (pointerSignal) {
                            if (pointerSignal is PointerScrollEvent) {
                              final delta = pointerSignal.scrollDelta.dy / 12.0;
                              final next =
                                  (_calcHeight + delta).clamp(45.0, 190.0);
                              setState(() {
                                _calcHeight =
                                    double.parse(next.toStringAsFixed(1));
                                if (!_heightFocusNode.hasFocus) {
                                  _heightController.text =
                                      _calcHeight.toStringAsFixed(1);
                                }
                              });
                            }
                          },
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onVerticalDragUpdate: (details) {
                              final delta = -details.primaryDelta! / 8.0;
                              final next =
                                  (_calcHeight + delta).clamp(45.0, 190.0);
                              setState(() {
                                _calcHeight =
                                    double.parse(next.toStringAsFixed(1));
                                if (!_heightFocusNode.hasFocus) {
                                  _heightController.text =
                                      _calcHeight.toStringAsFixed(1);
                                }
                              });
                            },
                            child: CustomPaint(
                              painter: _HeightRulerPainter(
                                value: _calcHeight,
                                minValue: 45.0,
                                maxValue: 190.0,
                                activeColor: isHeightValid
                                    ? const Color(0xFF86BF15)
                                    : const Color(0xFFEF4444),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Large Editable Number Input directly below ruler
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IntrinsicWidth(
                        child: TextField(
                          controller: _heightController,
                          focusNode: _heightFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d{0,1}')),
                          ],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.w900,
                            color: isHeightValid
                                ? const Color(0xFF0C2417)
                                : const Color(0xFFEF4444),
                            fontFamily: 'monospace',
                            letterSpacing: -1,
                          ),
                          cursorColor: isHeightValid
                              ? const Color(0xFF0C2417)
                              : const Color(0xFFEF4444),
                          cursorWidth: 3.0,
                          cursorHeight: 44.0,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (val) {
                            final parsed = double.tryParse(val);
                            if (parsed != null) {
                              setState(() {
                                _calcHeight = parsed.clamp(45.0, 190.0);
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  if (!isHeightValid)
                    const Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text('Invalid height: Must be 45 cm to 190 cm',
                          style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          ]

          // STEP 5: Growth Report
          else if (_calcStep == 5) ...[
            const Text('WHO GROWTH STANDARDS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF556D5E),
                    letterSpacing: 0.8)),
            const SizedBox(height: 4),
            const Text('Growth report',
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF0C2417))),
            const SizedBox(height: 4),
            Text(
                "${childName}'s measurements compared with WHO growth standards.",
                style: const TextStyle(fontSize: 13, color: Color(0xFF5A7263))),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  const Text('On Track',
                      style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0C2417))),
                  const SizedBox(height: 2),
                  Text(
                      '${childName} is tracking within the current recorded range.',
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF5A7263))),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2EAE2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('BELOW',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B))),
                      Text('HEALTHY RANGE',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B))),
                      Text('ABOVE',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF6EE7B7),
                          Color(0xFF34D399),
                          Color(0xFFF87171)
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text('${_calcWeight.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w900)),
                      Text('${_calcHeight.toStringAsFixed(1)} cm',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w900)),
                      const Text('75th percentile',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF0F3827))),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Bottom Action
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.info_outline, size: 14, color: Color(0xFF556D5E)),
              SizedBox(width: 4),
              Text('This will be saved to your profile',
                  style: TextStyle(fontSize: 11.5, color: Color(0xFF556D5E))),
            ],
          ),
          const SizedBox(height: 10),

          ElevatedButton(
            onPressed: () {
              if (_calcStep < 4) {
                if (_calcStep == 2 && !isAgeValid) return;
                if (_calcStep == 3 && !isWeightValid) return;
                setState(() => _calcStep++);
              } else if (_calcStep == 4) {
                if (!isHeightValid) return;
                setState(() => _calcStep = 5);
              } else {
                // Save to profile and switch back to Trends with animated numbers
                ref.read(vitalsProvider.notifier).addRecord(
                  childName: childName,
                  gender: _calcGender,
                  ageYears: _calcAgeYears,
                  ageMonths: _calcAgeMonths,
                  weight: _calcWeight,
                  height: _calcHeight,
                  status: 'On Track',
                );

                final savedCallback = onCalculatorSaved;
                if (savedCallback != null) {
                  savedCallback(_calcWeight, _calcHeight);
                  Navigator.of(context).pop();
                } else {
                  setState(() {
                    _currentWeight = _calcWeight;
                    _currentHeight = _calcHeight;
                    _weightMilestones[4]['child'] = _calcWeight;
                    _heightMilestones[4]['child'] = _calcHeight;
                    _selectedSegment = 0;
                    _counterController.forward(from: 0.0);
                  });
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.forestGreen,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _calcStep < 4
                      ? 'Continue →'
                      : _calcStep == 4
                          ? 'View Growth Report →'
                          : 'Save to Profile ✓',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GrowthCurvePainter extends CustomPainter {
  final int? selectedIndex;

  _GrowthCurvePainter({this.selectedIndex});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFFE8EFE8)
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 3; i++) {
      final y = (size.height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final whoPaint = Paint()
      ..color = const Color(0xFF8DA895)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final childPaint = Paint()
      ..color = const Color(0xFF0F3827)
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final whoPath = Path();
    whoPath.moveTo(20, size.height * 0.85);
    whoPath.quadraticBezierTo(size.width * 0.4, size.height * 0.5,
        size.width - 20, size.height * 0.25);
    canvas.drawPath(whoPath, whoPaint);

    final childPath = Path();
    childPath.moveTo(20, size.height * 0.8);
    childPath.quadraticBezierTo(size.width * 0.4, size.height * 0.45,
        size.width - 20, size.height * 0.2);
    canvas.drawPath(childPath, childPaint);

    final dotPaint = Paint()..color = const Color(0xFF0F3827);
    final dotBorder = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 5; i++) {
      final x = 20.0 + (size.width - 40.0) * (i / 4.0);
      final t = i / 4.0;
      final y = (size.height * 0.8) * (1 - t) * (1 - t) +
          (size.height * 0.45) * 2 * (1 - t) * t +
          (size.height * 0.2) * t * t;

      canvas.drawCircle(Offset(x, y), 5, dotPaint);
      canvas.drawCircle(Offset(x, y), 5, dotBorder);
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthCurvePainter oldDelegate) =>
      oldDelegate.selectedIndex != selectedIndex;
}

// ─────────────────────────────────────────────────────────────────────────────
// Measurement Ruler Widget (Weight & Height input scale)
// ─────────────────────────────────────────────────────────────────────────────

class _WeightDialPainter extends CustomPainter {
  final double value;
  final Color activeColor;

  _WeightDialPainter({
    required this.value,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2.0;
    final double pivotY = size.height * 0.82;
    final double radius = size.width * 0.38;

    // 1. Draw Arch Background Track Band
    final trackPaint = Paint()
      ..color = const Color(0xFFE2EDE0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28.0
      ..strokeCap = StrokeCap.round;

    final Rect rect =
        Rect.fromCircle(center: Offset(centerX, pivotY), radius: radius);
    // Draw semi-circle arch from pi (180 deg) to 2*pi (360 deg)
    canvas.drawArc(rect, math.pi, math.pi, false, trackPaint);

    // 2. Draw Ticks around outer boundary of the arch (crossing the track)
    const int totalTicks = 21;
    for (int i = 0; i < totalTicks; i++) {
      final double angle = math.pi + (i / (totalTicks - 1)) * math.pi;
      final bool isMajor = (i % 2 == 0);
      final double innerR = isMajor ? radius - 16.0 : radius - 9.0;
      final double outerR = isMajor ? radius + 16.0 : radius + 9.0;

      final double dx1 = centerX + innerR * math.cos(angle);
      final double dy1 = pivotY + innerR * math.sin(angle);
      final double dx2 = centerX + outerR * math.cos(angle);
      final double dy2 = pivotY + outerR * math.sin(angle);

      final tickPaint = Paint()
        ..color = isMajor ? const Color(0xFF2C4334) : const Color(0xFF5A7363)
        ..strokeWidth = isMajor ? 2.5 : 1.6
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(Offset(dx1, dy1), Offset(dx2, dy2), tickPaint);
    }

    // 3. Draw Vertical Pointer Needle (pointing straight up from center to top tick)
    final pointerPaint = Paint()
      ..color = activeColor
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(centerX, pivotY),
      Offset(centerX, pivotY - radius - 20.0),
      pointerPaint,
    );

    // 4. Draw Center Pivot Dark Node Circle
    final pivotPaint = Paint()..color = const Color(0xFF0C2417);
    canvas.drawCircle(Offset(centerX, pivotY), 11.0, pivotPaint);
  }

  @override
  bool shouldRepaint(covariant _WeightDialPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.activeColor != activeColor;
}

class _HeightRulerPainter extends CustomPainter {
  final double value;
  final double minValue;
  final double maxValue;
  final Color activeColor;

  _HeightRulerPainter({
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width * 0.48;
    final double centerY = size.height / 2.0;

    // Green vertical center line
    final axisPaint = Paint()
      ..color = activeColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(centerX, 0), Offset(centerX, size.height), axisPaint);

    // 28px per 1 cm height difference
    const double pixelsPerUnit = 28.0;

    final int startHeight = (value - (centerY / pixelsPerUnit)).floor() - 1;
    final int endHeight = (value + (centerY / pixelsPerUnit)).ceil() + 1;

    for (int h = startHeight; h <= endHeight; h++) {
      if (h < minValue || h > maxValue) continue;

      final double dy = centerY - (h - value) * pixelsPerUnit;
      if (dy < -15 || dy > size.height + 15) continue;

      final bool isCenterVal = ((h - value).abs() < 0.4);

      // 1. Right Side Horizontal Ticks
      final double tickLength = isCenterVal ? 32.0 : 20.0;
      final tickPaint = Paint()
        ..color = isCenterVal ? activeColor : const Color(0xFFB0C4B4)
        ..strokeWidth = isCenterVal ? 3.5 : 1.5
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(centerX + 6, dy),
        Offset(centerX + 6 + tickLength, dy),
        tickPaint,
      );

      // 2. Left Side Height Numbers
      final textPainter = TextPainter(
        text: TextSpan(
          text: '$h',
          style: TextStyle(
            fontSize: isCenterVal ? 16 : 13.5,
            fontWeight: isCenterVal ? FontWeight.w900 : FontWeight.w600,
            color: isCenterVal
                ? const Color(0xFF0C2417)
                : const Color(0xFF678270),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        Offset(centerX - textPainter.width - 12, dy - textPainter.height / 2),
      );
    }

    // 3. Active horizontal pointer line on left side extending across center line
    final pointerPaint = Paint()
      ..color = activeColor
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(centerX - 68, centerY),
      Offset(centerX, centerY),
      pointerPaint,
    );

    // 4. Green thumb dot on the center axis line
    final dotPaint = Paint()..color = activeColor;
    canvas.drawCircle(Offset(centerX, centerY), 5.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _HeightRulerPainter oldDelegate) =>
      oldDelegate.value != value || oldDelegate.activeColor != activeColor;
}



class _MeasurementRulerWidget extends StatefulWidget {
  final double value;
  final double minValue;
  final double maxValue;
  final double majorStep; // e.g. 5 for weight, 10 for height
  final double minorStep; // e.g. 1 for weight, 2 for height
  final bool isValid;
  final ValueChanged<double> onChanged;

  const _MeasurementRulerWidget({
    Key? key,
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.majorStep,
    required this.minorStep,
    required this.isValid,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<_MeasurementRulerWidget> createState() =>
      _MeasurementRulerWidgetState();
}

class _MeasurementRulerWidgetState extends State<_MeasurementRulerWidget> {
  // Pixels per unit value — controls sensitivity
  static const double _pixelsPerUnit = 5.0;

  double get _range => widget.maxValue - widget.minValue;

  /// Convert a ruler value to a horizontal offset from the center.
  double _valueToOffset(double val) {
    final centered = val - widget.value; // offset from current center value
    return centered * _pixelsPerUnit;
  }

  @override
  Widget build(BuildContext context) {
    final indicatorColor =
        widget.isValid ? const Color(0xFF0F3827) : const Color(0xFFEF4444);
    final tickColor = widget.isValid
        ? const Color(0xFFB0C4B8)
        : const Color(0xFFEF4444).withOpacity(0.4);
    final majorTickColor = widget.isValid
        ? const Color(0xFF3D7059)
        : const Color(0xFFEF4444).withOpacity(0.6);

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        final delta = details.primaryDelta ?? 0.0;
        final newVal = (widget.value - delta / _pixelsPerUnit)
            .clamp(widget.minValue, widget.maxValue);
        // Round to minorStep precision
        final snapped = (newVal / widget.minorStep).round() * widget.minorStep;
        widget.onChanged(double.parse(snapped
            .clamp(widget.minValue, widget.maxValue)
            .toStringAsFixed(1)));
      },
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        height: 72,
        child: ClipRect(
          child: CustomPaint(
            painter: _MeasurementRulerPainter(
              value: widget.value,
              minValue: widget.minValue,
              maxValue: widget.maxValue,
              majorStep: widget.majorStep,
              minorStep: widget.minorStep,
              pixelsPerUnit: _pixelsPerUnit,
              tickColor: tickColor,
              majorTickColor: majorTickColor,
              indicatorColor: indicatorColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _MeasurementRulerPainter extends CustomPainter {
  final double value;
  final double minValue;
  final double maxValue;
  final double majorStep;
  final double minorStep;
  final double pixelsPerUnit;
  final Color tickColor;
  final Color majorTickColor;
  final Color indicatorColor;

  _MeasurementRulerPainter({
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.majorStep,
    required this.minorStep,
    required this.pixelsPerUnit,
    required this.tickColor,
    required this.majorTickColor,
    required this.indicatorColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2.0;
    final centerY = size.height;

    // Draw track background
    final trackPaint = Paint()
      ..color = const Color(0xFFF0F5F1)
      ..style = PaintingStyle.fill;
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      const Radius.circular(12),
    );
    canvas.drawRRect(trackRect, trackPaint);

    // Minor tick paint
    final minorPaint = Paint()
      ..color = tickColor
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    // Major tick paint
    final majorPaint = Paint()
      ..color = majorTickColor
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    // Label style
    final textStyle = TextStyle(
      color: majorTickColor,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.3,
    );

    // Calculate the range of values to draw (what's visible on screen)
    final visibleHalfRange = (size.width / 2.0) / pixelsPerUnit;
    final startVal =
        (value - visibleHalfRange - majorStep).clamp(minValue, maxValue);
    final endVal =
        (value + visibleHalfRange + majorStep).clamp(minValue, maxValue);

    // Find the first minor tick >= startVal (aligned to minorStep grid)
    double firstTick = (startVal / minorStep).floor() * minorStep;

    double tickVal = firstTick;
    while (tickVal <= endVal) {
      final offset = (tickVal - value) * pixelsPerUnit;
      final x = centerX + offset;

      if (x >= 0 && x <= size.width) {
        final isMajor =
            ((tickVal / majorStep).round() * majorStep - tickVal).abs() < 0.01;
        final tickHeight = isMajor ? 28.0 : 14.0;

        final paint = isMajor ? majorPaint : minorPaint;
        canvas.drawLine(
          Offset(x, centerY - tickHeight),
          Offset(x, centerY),
          paint,
        );

        if (isMajor) {
          // Draw label above major tick
          final label = tickVal == tickVal.truncate()
              ? tickVal.toInt().toString()
              : tickVal.toStringAsFixed(0);
          final span = TextSpan(text: label, style: textStyle);
          final tp = TextPainter(
            text: span,
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(
            canvas,
            Offset(x - tp.width / 2, centerY - tickHeight - tp.height - 3),
          );
        }
      }
      tickVal = double.parse((tickVal + minorStep).toStringAsFixed(6));
    }

    // Draw center indicator line (triangle pointer)
    final indicatorPaint = Paint()
      ..color = indicatorColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, centerY),
      indicatorPaint,
    );

    // Draw indicator dot at top
    final dotPaint = Paint()
      ..color = indicatorColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, 6), 5, dotPaint);
    canvas.drawCircle(
      Offset(centerX, 6),
      5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant _MeasurementRulerPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.indicatorColor != indicatorColor;
}

class _BoySilhouettePainter extends CustomPainter {
  final Color color;
  const _BoySilhouettePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final scaleX = size.width / 32.0;
    final scaleY = size.height / 40.0;
    canvas.scale(scaleX, scaleY);

    // Head
    canvas.drawCircle(const Offset(16, 9), 7, paint);

    // Hair tuft
    final hairPath = Path()
      ..moveTo(14, 2.5)
      ..quadraticBezierTo(20, 1.5, 22, 6)
      ..quadraticBezierTo(18, 5, 15, 3.5)
      ..close();
    canvas.drawPath(hairPath, paint);

    // Body (Torso)
    final torso = RRect.fromRectAndRadius(
      const Rect.fromLTRB(9.5, 17, 22.5, 28),
      const Radius.circular(4.5),
    );
    canvas.drawRRect(torso, paint);

    // Legs
    final leftLeg = RRect.fromRectAndRadius(const Rect.fromLTRB(10.5, 27, 15, 39), const Radius.circular(2.5));
    final rightLeg = RRect.fromRectAndRadius(const Rect.fromLTRB(17, 27, 21.5, 39), const Radius.circular(2.5));
    canvas.drawRRect(leftLeg, paint);
    canvas.drawRRect(rightLeg, paint);

    // Arms
    final leftArm = RRect.fromRectAndRadius(const Rect.fromLTRB(6.5, 18, 9, 28), const Radius.circular(2.5));
    final rightArm = RRect.fromRectAndRadius(const Rect.fromLTRB(23, 18, 25.5, 28), const Radius.circular(2.5));
    canvas.drawRRect(leftArm, paint);
    canvas.drawRRect(rightArm, paint);
  }

  @override
  bool shouldRepaint(covariant _BoySilhouettePainter oldDelegate) =>
      oldDelegate.color != color;
}

class _GirlSilhouettePainter extends CustomPainter {
  final Color color;
  const _GirlSilhouettePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final scaleX = size.width / 32.0;
    final scaleY = size.height / 40.0;
    canvas.scale(scaleX, scaleY);

    // Head
    canvas.drawCircle(const Offset(16, 9), 6.5, paint);

    // Left Pigtail
    final leftPigtail = Path()
      ..moveTo(10.5, 9)
      ..cubicTo(5, 4.5, 3, 12, 8, 15)
      ..cubicTo(9.5, 13.5, 10.5, 11, 10.5, 9)
      ..close();
    canvas.drawPath(leftPigtail, paint);

    // Right Pigtail
    final rightPigtail = Path()
      ..moveTo(21.5, 9)
      ..cubicTo(27, 4.5, 29, 12, 24, 15)
      ..cubicTo(22.5, 13.5, 21.5, 11, 21.5, 9)
      ..close();
    canvas.drawPath(rightPigtail, paint);

    // Dress (A-line silhouette)
    final dressPath = Path()
      ..moveTo(11.5, 17)
      ..lineTo(20.5, 17)
      ..lineTo(25, 29)
      ..quadraticBezierTo(16, 30.5, 7, 29)
      ..close();
    canvas.drawPath(dressPath, paint);

    // Legs
    final leftLeg = RRect.fromRectAndRadius(const Rect.fromLTRB(11, 28, 14.5, 39), const Radius.circular(2.5));
    final rightLeg = RRect.fromRectAndRadius(const Rect.fromLTRB(17.5, 28, 21, 39), const Radius.circular(2.5));
    canvas.drawRRect(leftLeg, paint);
    canvas.drawRRect(rightLeg, paint);

    // Arms
    final leftArm = RRect.fromRectAndRadius(const Rect.fromLTRB(6.5, 18, 9.5, 26), const Radius.circular(2.5));
    final rightArm = RRect.fromRectAndRadius(const Rect.fromLTRB(22.5, 18, 25.5, 26), const Radius.circular(2.5));
    canvas.drawRRect(leftArm, paint);
    canvas.drawRRect(rightArm, paint);
  }

  @override
  bool shouldRepaint(covariant _GirlSilhouettePainter oldDelegate) =>
      oldDelegate.color != color;
}
