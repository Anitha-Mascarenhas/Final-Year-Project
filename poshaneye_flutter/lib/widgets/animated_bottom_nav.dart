import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class AnimatedBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AnimatedBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final navBg = AppTheme.navBgColor(context);
    final navBorder = AppTheme.navBorderColor(context);
    final navActive = AppTheme.navActiveColor(context);
    final navInactive = AppTheme.navInactiveColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final totalHeight = 64.0 + bottomPadding;

    return Container(
      height: totalHeight,
      decoration: BoxDecoration(color: navBg),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Navigation bar background
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 64,
            child: Container(
              decoration: BoxDecoration(
                color: navBg,
                border: Border(top: BorderSide(color: navBorder, width: 1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
            ),
          ),

          // Navigation items with animated indicator
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 64,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    index: 0,
                    label: 'Home',
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    isActive: currentIndex == 0,
                    activeColor: navActive,
                    inactiveColor: navInactive,
                    context: context,
                  ),
                  _buildNavItem(
                    index: 1,
                    label: 'Growth',
                    icon: Icons.show_chart_rounded,
                    activeIcon: Icons.show_chart_rounded,
                    isActive: currentIndex == 1,
                    activeColor: navActive,
                    inactiveColor: navInactive,
                    context: context,
                  ),
                  // Spacer for center FAB
                  const SizedBox(width: 64),
                  _buildNavItem(
                    index: 3,
                    label: 'Nutrition',
                    icon: Icons.restaurant_outlined,
                    activeIcon: Icons.restaurant,
                    isActive: currentIndex == 3,
                    activeColor: navActive,
                    inactiveColor: navInactive,
                    context: context,
                  ),
                  _buildNavItem(
                    index: 4,
                    label: 'Profile',
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    isActive: currentIndex == 4,
                    activeColor: navActive,
                    inactiveColor: navInactive,
                    context: context,
                  ),
                ],
              ),
            ),
          ),

          // Center AI Scan FAB
          Positioned(
            top: -26,
            left: 0,
            right: 0,
            child: Center(
              child: _buildCenterFAB(
                isActive: currentIndex == 2,
                isDark: isDark,
                context: context,
              ),
            ),
          ),

          // Bottom safe area
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: bottomPadding,
            child: SizedBox.expand(child: ColoredBox(color: navBg)),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required BuildContext context,
  }) {
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: 56,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey(isActive),
                color: isActive ? activeColor : inactiveColor,
                size: isActive ? 24 : 22,
              ),
            ),
            const SizedBox(height: 3),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? activeColor : inactiveColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterFAB({
    required bool isActive,
    required bool isDark,
    required BuildContext context,
  }) {
    final navActive = AppTheme.navActiveColor(context);
    final navInactive = AppTheme.navInactiveColor(context);

    return GestureDetector(
      onTap: () => onTap(2),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: isActive ? 56 : 52,
              height: isActive ? 56 : 52,
              decoration: BoxDecoration(
                color: AppTheme.accentGreen,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentGreen.withValues(alpha: isActive ? 0.5 : 0.3),
                    blurRadius: isActive ? 16 : 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                Icons.qr_code_scanner_rounded,
                color: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
                size: isActive ? 28 : 26,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isActive ? navActive : navInactive,
              ),
              child: const Text('AI Scan'),
            ),
          ],
        ),
      ),
    );
  }
}
