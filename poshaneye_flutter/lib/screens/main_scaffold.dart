import 'package:flutter/material.dart';
import '../widgets/interactive_bottom_nav.dart';
import 'home_dashboard_screen.dart';
import 'growth_tracking_screen.dart';
import 'ai_scan_screen.dart';
import 'nutrition_plan_screen.dart';
import 'profile_screen.dart';
import 'role_selection_screen.dart';

/// Central scaffold that owns the bottom navigation state.
/// All main tab screens are rendered within this widget so that
/// switching tabs never pushes a new route onto the stack.
class MainScaffold extends StatefulWidget {
  final String childName;
  final int initialIndex;

  const MainScaffold({
    Key? key,
    this.childName = 'Aarav',
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onTabSelected(int idx) {
    if (idx == 2) return; // Scan is handled by onScanPressed
    setState(() => _currentIndex = idx);
  }

  void _onScanPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AiScanScreen(childName: widget.childName),
      ),
    );
  }

  Widget _buildCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return HomeDashboardScreenBody(
          childName: widget.childName,
          onNavRequested: _onTabSelected,
          onScanPressed: _onScanPressed,
        );
      case 1:
        return GrowthTrackingScreenBody(
          childName: widget.childName,
        );
      case 3:
        return NutritionPlanScreen(childName: widget.childName);
      case 4:
        return ProfileScreen(
          childName: widget.childName,
          onLogout: () {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
              (route) => false,
            );
          },
        );
      default:
        return HomeDashboardScreenBody(
          childName: widget.childName,
          onNavRequested: _onTabSelected,
          onScanPressed: _onScanPressed,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // For screens that already have their own scroll/layout (Nutrition, Profile),
    // we overlay the bottom nav; for screens that don't include it, we stack it.
    final bool screenOwnsLayout = _currentIndex == 3 || _currentIndex == 4;

    if (screenOwnsLayout) {
      // These screens have their own Scaffold — wrap them and overlay the nav
      return Stack(
        children: [
          _buildCurrentScreen(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: InteractiveBottomNav(
              currentIndex: _currentIndex,
              onTabSelected: _onTabSelected,
              onScanPressed: _onScanPressed,
            ),
          ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFEAF1E9),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: _buildCurrentScreen(),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: InteractiveBottomNav(
                currentIndex: _currentIndex,
                onTabSelected: _onTabSelected,
                onScanPressed: _onScanPressed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
