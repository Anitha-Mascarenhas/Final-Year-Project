import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/child_profile.dart';
import '../models/prediction_result.dart';
import '../models/vital_record.dart';

import 'analysis_results_screen.dart';
import 'dashboard_screen.dart';
import 'bmi_calculator_screen.dart';
import 'scan_screen.dart';
import 'nutrition_plan_screen.dart';
import 'profile_screen.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _activeTab = 0;

  late ChildProfile _child;
  late VitalRecord _vitals;

  PredictionResult? _predictionResult;

  @override
  void initState() {
    super.initState();

    _child = ChildProfile(
      name: 'Aarav',
      parentNames: 'Sarah & Leo',
      accountType: 'Premium Account',
      gender: 'boy',
      ageYears: 2,
      ageMonths: 3,
      avatarUrl:
          'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=120&q=80',
      status: 'On Track',
      statusDescription:
          'Following a healthy growth path compared to WHO standards.',
    );

    _vitals = VitalRecord(
      weight: 14.2,
      height: 92.5,
      muac: 14.5,
      date: 'Updated 2 days ago',
      bmi: 16.2,
      percentile: '75th',
    );
  }

  String _getPageTitle() {
    if (_predictionResult != null) {
      return 'Analysis Results';
    }

    switch (_activeTab) {
      case 0:
        return 'Home';
      case 1:
        return 'Growth Tracking';
      case 2:
        return 'AI Scan';
      case 3:
        return 'Nutrition Plan';
      case 4:
        return 'Child Profile';
      default:
        return 'PoshanEye';
    }
  }

  void _handleAnalysisComplete(PredictionResult result) {
    setState(() {
      _predictionResult = result;
    });
  }

  void _handleResetAnalysis() {
    setState(() {
      _predictionResult = null;
      _activeTab = 2;
    });
  }

  void _handleNavigateTab(int index) {
    setState(() {
      _predictionResult = null;
      _activeTab = index;
    });
  }

  void _handleAddRecord(VitalRecord record) {
    setState(() {
      _vitals = record;
    });
  }

  Widget _buildCurrentPage() {
    // Show prediction results after a successful AI scan.
    if (_predictionResult != null) {
      return AnalysisResultsScreen(
        result: _predictionResult!,
        onReset: _handleResetAnalysis,
      );
    }

    switch (_activeTab) {
      case 0:
        return DashboardScreen(
          child: _child,
          vitals: _vitals,
          onNavigateTab: _handleNavigateTab,
        );

      case 1:
        return BMICalculatorScreen(
          child: _child,
          vitals: _vitals,
          onAddRecord: _handleAddRecord,
        );

      case 2:
        return ScanScreen(
          child: _child,
          vitals: _vitals,
          onNavigateTab: _handleNavigateTab,
          onAnalysisComplete: _handleAnalysisComplete,
        );

      case 3:
        return NutritionPlanScreen(
          child: _child,
        );

      case 4:
        return ProfileScreen(
          child: _child,
          vitals: _vitals,
        );

      default:
        return DashboardScreen(
          child: _child,
          vitals: _vitals,
          onNavigateTab: _handleNavigateTab,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF120A21),

      appBar: AppBar(
        backgroundColor: const Color(0xFF120A21),
        elevation: 0,
        title: Text(
          _getPageTitle(),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      body: SafeArea(
        child: _buildCurrentPage(),
      ),

      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1235),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF3FFF80).withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),

      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                label: 'Home',
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
              ),

              _buildNavItem(
                index: 1,
                label: 'Growth',
                icon: Icons.trending_up,
                activeIcon: Icons.trending_up,
              ),

              _buildCenterScanFAB(),

              _buildNavItem(
                index: 3,
                label: 'Nutrition',
                icon: Icons.restaurant_outlined,
                activeIcon: Icons.restaurant,
              ),

              _buildNavItem(
                index: 4,
                label: 'Profile',
                icon: Icons.person_outline,
                activeIcon: Icons.person,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final isActive = _activeTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          _handleNavigateTab(index);
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive
                  ? const Color(0xFF3FFF80)
                  : Colors.white54,
              size: 22,
            ),

            const SizedBox(height: 2),

            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive
                    ? const Color(0xFF3FFF80)
                    : Colors.white54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterScanFAB() {
    final isActive = _activeTab == 2;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _predictionResult = null;
            _activeTab = 2;
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Transform.translate(
          offset: const Offset(0, -8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF3FFF80),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF1E1235),
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3FFF80)
                          .withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.qr_code_scanner,
                  color: Color(0xFF1E1235),
                  size: 26,
                ),
              ),

              Text(
                'AI Scan',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isActive
                      ? const Color(0xFF3FFF80)
                      : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}