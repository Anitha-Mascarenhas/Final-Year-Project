import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/child_profile.dart';
import '../models/vital_record.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/vanta_globe_background.dart';
import 'dashboard_screen.dart';
import 'bmi_calculator_screen.dart';
import 'scan_screen.dart';
import 'nutrition_plan_screen.dart';
import 'profile_screen.dart';
import 'voice_assistant_sheet.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _activeTab = 0; // 0=Home, 1=Growth, 2=Scan, 3=Nutrition, 4=Profile, 5=PoshanAi

  late ChildProfile _child;
  late VitalRecord _vitals;

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
      avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=120&q=80',
      status: 'On Track',
      statusDescription: 'Following a healthy growth path compared to WHO standards.',
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
      case 5:
        return 'PoshanAi Voice';
      default:
        return 'PoshanEye';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Scan screen (tab 2) keeps background occluded to ensure camera view is 100% clear
    final isGlobeVisible = _activeTab != 2;

    return VantaGlobeBackground(
      isBackgroundVisible: isGlobeVisible,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true,
        body: Stack(
          children: [
            // Body Content View
            Positioned.fill(
              child: IndexedStack(
                index: _activeTab,
                children: [
                  DashboardScreen(
                    child: _child,
                    vitals: _vitals,
                    onNavigateTab: (tab) => setState(() => _activeTab = tab),
                  ),
                  BMICalculatorScreen(
                    child: _child,
                    vitals: _vitals,
                    onAddRecord: (record) => setState(() => _vitals = record),
                  ),
                  ScanScreen(
                    child: _child,
                    vitals: _vitals,
                    onNavigateTab: (tab) => setState(() => _activeTab = tab),
                  ),
                  NutritionPlanScreen(child: _child),
                  ProfileScreen(child: _child, vitals: _vitals),
                  VoiceAssistantSheet(child: _child, vitals: _vitals),
                ],
              ),
            ),

            // Fixed Top Header
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppHeader(
                title: _getPageTitle(),
                showBack: _activeTab != 0,
                onBackClick: () => setState(() => _activeTab = 0),
                onProfileClick: () => setState(() => _activeTab = 4),
                avatarUrl: _child.avatarUrl,
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1235).withValues(alpha: 0.92),
        border: Border(top: BorderSide(color: const Color(0xFF3FFF80).withValues(alpha: 0.15), width: 1)),
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
              // 0: Home
              _buildNavItem(index: 0, label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home),

              // 1: Growth
              _buildNavItem(index: 1, label: 'Growth', icon: Icons.trending_up, activeIcon: Icons.trending_up),

              // 2: Center Elevated Scan FAB
              _buildCenterScanFAB(),

              // 3: Nutrition
              _buildNavItem(index: 3, label: 'Nutrition', icon: Icons.restaurant_outlined, activeIcon: Icons.restaurant),

              // 4: Profile
              _buildNavItem(index: 4, label: 'Profile', icon: Icons.person_outline, activeIcon: Icons.person),
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
        onTap: () => setState(() => _activeTab = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              color: isActive ? const Color(0xFF3FFF80) : Colors.white54,
              size: 22,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? const Color(0xFF3FFF80) : Colors.white54,
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
        onTap: () => setState(() => _activeTab = 2),
        child: Transform.translate(
          offset: const Offset(0, -12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF3FFF80),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF1E1235), width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3FFF80).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.qr_code_scanner, color: Color(0xFF1E1235), size: 26),
              ),
              Text(
                'AI Scan',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: isActive ? const Color(0xFF3FFF80) : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
