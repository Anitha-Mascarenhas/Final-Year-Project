import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'scan_screen.dart';
import 'analysis_results_screen.dart';
import 'nutrition_plan_screen.dart';
import 'bmi_calculator_screen.dart';
import 'clinical_benchmarks_screen.dart';
import 'voice_assistant_sheet.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _activeIndex = 0;
  bool _scanComplete = false;

  final List<_NavItem> _navItems = const [
    _NavItem(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home),
    _NavItem(label: 'Charts', icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart),
    _NavItem(label: 'Scan', icon: Icons.qr_code_scanner, activeIcon: Icons.qr_code_scanner),
    _NavItem(label: 'Diet', icon: Icons.restaurant_outlined, activeIcon: Icons.restaurant),
    _NavItem(label: 'BMI', icon: Icons.monitor_weight_outlined, activeIcon: Icons.monitor_weight),
  ];

  void _onNavTap(int index) {
    setState(() {
      _activeIndex = index;
      if (index != 2) _scanComplete = false;
    });
  }

  Widget _buildScreen() {
    switch (_activeIndex) {
      case 0:
        return const DashboardScreen();
      case 1:
        return const ClinicalBenchmarksScreen();
      case 2:
        if (_scanComplete) {
          return AnalysisResultsScreen(onReset: () => setState(() => _scanComplete = false));
        }
        return ScanScreen(onComplete: () => setState(() => _scanComplete = true));
      case 3:
        return const NutritionPlanScreen();
      case 4:
        return const BMICalculatorScreen();
      default:
        return const DashboardScreen();
    }
  }

  void _openVoiceAssistant() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceAssistantSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.surface,
      extendBody: true,
      body: Stack(
        children: [
          // Main content
          SafeArea(
            bottom: false,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
                      .animate(animation),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(_activeIndex),
                child: _buildBody(),
              ),
            ),
          ),

          // Floating AI Mic button (only on home)
          if (_activeIndex == 0)
            Positioned(
              bottom: 110,
              right: 24,
              child: FloatingActionButton(
                onPressed: _openVoiceAssistant,
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                elevation: 6,
                child: const Icon(Icons.mic, size: 28),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            child: _buildScreen(),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundImage: NetworkImage(
              'https://lh3.googleusercontent.com/aida-public/AB6AXuAeR_pQqkUYm6G60-ZaJvJBj5orVwDj4SOOZ3tbEOmx0tW3hILD7czLfg1tCanIyTflUs-u6jN1QyZqGZWyc9hwbV1LsTf3z1_hp0TBKF-hdS3MLGUYy1vhJtYdbG12NHfUavbHL-BToJ88VpDrV89AJPjOmFYZFDq1NWolmgWeU0y8ClCXwHBprEFjJuwKChsHHi1DKXp3t_KiMLtRe9yD8xcC3eCJ54bfLMNX2N-F_cH60lPNBQAG0VHZkx8z0VJcwAcTyX-3-l7i',
            ),
            onBackgroundImageError: (_, __) {},
          ),
          const SizedBox(width: 12),
          Text(
            'PoshanEye',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppTheme.primary,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: AppTheme.primary),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (i) {
              if (i == 2) {
                // Center scan button elevated
                return _buildScanButton();
              }
              return _buildNavItem(i);
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final item = _navItems[index];
    final isActive = _activeIndex == index;
    return GestureDetector(
      onTap: () => _onNavTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? item.activeIcon : item.icon,
              color: isActive ? AppTheme.primary : Colors.grey[400],
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isActive ? AppTheme.primary : Colors.grey[400],
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanButton() {
    final isActive = _activeIndex == 2;
    return GestureDetector(
      onTap: () => _onNavTap(2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 2),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isActive ? AppTheme.primary : AppTheme.primary.withOpacity(0.8),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.qr_code_scanner, color: Colors.white, size: 26),
          ),
          Text(
            'Scan',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isActive ? AppTheme.primary : Colors.grey[400],
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavItem({required this.label, required this.icon, required this.activeIcon});
}
