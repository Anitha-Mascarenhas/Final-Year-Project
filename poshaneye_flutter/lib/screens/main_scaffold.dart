import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/child_profile.dart';
import '../models/prediction_result.dart';
import '../models/vital_record.dart';
import '../theme/app_theme.dart';
import '../widgets/animated_grid_background.dart';
import '../widgets/animated_bottom_nav.dart';

import 'dashboard_screen.dart';
import 'bmi_calculator_screen.dart';
import 'scan_screen.dart';
import 'nutrition_plan_screen.dart';
import 'profile_screen.dart';
import 'health_report_screen.dart';

class MainScaffold extends StatefulWidget {
  final VoidCallback? onLogout;

  const MainScaffold({super.key, this.onLogout});

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
      headCircumference: null, // Not yet recorded
      date: 'Updated 2 days ago',
      bmi: 16.2,
      percentile: '75th',
    );
  }

  String _getPageTitle() {
    if (_predictionResult != null) {
      return 'Health Report';
    }

    switch (_activeTab) {
      case 0:
        return 'Home';
      case 1:
        return 'Growth';
      case 2:
        return 'AI Scan';
      case 3:
        return 'Nutrition';
      case 4:
        return 'Profile';
      default:
        return 'PoshanEye';
    }
  }

  void _handleAnalysisComplete(PredictionResult result) {
    setState(() {
      _predictionResult = result;
    });
  }

  void _handleNewScan() {
    setState(() {
      _predictionResult = null;
      _activeTab = 2;
    });
  }

  void _handleViewNutritionPlan() {
    setState(() {
      _predictionResult = null;
      _activeTab = 3;
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
    if (_predictionResult != null) {
      return HealthReportScreen(
        child: _child,
        vitals: _vitals,
        result: _predictionResult!,
        onNewScan: _handleNewScan,
        onViewNutritionPlan: _handleViewNutritionPlan,
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
          onLogout: widget.onLogout,
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
    final scaffoldBg = AppTheme.scaffoldBgColor(context);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: _predictionResult != null
          ? AppBar(
              backgroundColor: scaffoldBg,
              elevation: 0,
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_rounded,
                  color: AppTheme.textColorPrimary(context),
                  size: 20,
                ),
                onPressed: _handleNewScan,
              ),
              title: Text(
                _getPageTitle(),
                style: GoogleFonts.inter(
                  color: AppTheme.textColorPrimary(context),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      body: SafeArea(
        child: Stack(
          children: [
            const AnimatedGridBackground(),
            _buildCurrentPage(),
          ],
        ),
      ),
      bottomNavigationBar: _predictionResult != null
          ? null // Hide nav when viewing report
          : AnimatedBottomNav(
              currentIndex: _activeTab,
              onTap: _handleNavigateTab,
            ),
    );
  }
}
