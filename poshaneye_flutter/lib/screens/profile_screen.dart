import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/child_profile.dart';
import '../models/vital_record.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  final ChildProfile child;
  final VitalRecord vitals;
  final VoidCallback? onLogout;

  const ProfileScreen({
    super.key,
    required this.child,
    required this.vitals,
    this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _toastMessage;

  void _showToast(String msg) {
    setState(() => _toastMessage = msg);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _toastMessage = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProvider.of(context);
    final textColor = AppTheme.textColorPrimary(context);
    final textSecondary = AppTheme.textColorSecondary(context);
    final cardBg = AppTheme.cardBgColor(context);
    final borderColor = AppTheme.borderColorValue(context);
    final borderAccent = AppTheme.borderAccentColor(context);
    final accentMint = AppTheme.accentMint;
    final iconBtnBg = AppTheme.iconBtnBgColor(context);

    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Parent & Child Header Card
              _buildParentHeader(textColor, textSecondary, cardBg, borderColor, borderAccent, accentMint, iconBtnBg),
              const SizedBox(height: 16),

              // Child Overview Mint Badge
              _buildChildBadge(),
              const SizedBox(height: 24),

              // Preferences Section
              _buildSectionHeader('PREFERENCES', context),
              const SizedBox(height: 8),
              _buildGroupContainer([
                _buildSettingsRow(
                  icon: Icons.notifications_none,
                  label: 'Notifications',
                  onTap: () => _showToast('Notifications updated'),
                  textColor: textColor,
                  iconBg: accentMint,
                  context: context,
                ),
                _buildDivider(context),

                // Dark Mode Toggle
                _buildDarkModeToggle(themeProvider, textColor, accentMint, context),
                _buildDivider(context),

                _buildSettingsRow(
                  icon: Icons.tune,
                  label: 'App Settings',
                  onTap: () => _showToast('App Settings opened'),
                  textColor: textColor,
                  iconBg: accentMint,
                  context: context,
                ),
                _buildDivider(context),
                _buildSettingsRow(
                  icon: Icons.child_care,
                  label: 'Manage Profiles',
                  onTap: () => _showToast('Managing profiles'),
                  textColor: textColor,
                  iconBg: accentMint,
                  context: context,
                ),
              ], context),

              const SizedBox(height: 24),

              // Support Section
              _buildSectionHeader('SUPPORT', context),
              const SizedBox(height: 8),
              _buildGroupContainer([
                _buildSettingsRow(
                  icon: Icons.help_outline,
                  label: 'Help Center',
                  onTap: () => _showToast('Help Center loaded'),
                  textColor: textColor,
                  iconBg: accentMint,
                  context: context,
                ),
                _buildDivider(context),
                _buildSettingsRow(
                  icon: Icons.verified_user_outlined,
                  label: 'Privacy & Security',
                  onTap: () => _showToast('Privacy & Security verified'),
                  textColor: textColor,
                  iconBg: accentMint,
                  context: context,
                ),
              ], context),

              const SizedBox(height: 32),

              // Sign Out Button
              Center(
                child: OutlinedButton(
                  onPressed: widget.onLogout ?? () => _showToast('Signed out safely'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                    side: const BorderSide(color: Color(0xFFBA1A1A)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: Text(
                    'Sign Out',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFBA1A1A),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),

        // Floating Toast Popup
        if (_toastMessage != null)
          Positioned(
            top: 75,
            left: 20,
            right: 20,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _toastMessage!,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDarkModeToggle(ThemeProvider themeProvider, Color textColor, Color accentMint, BuildContext context) {
    final isDark = themeProvider.isDark;

    return InkWell(
      onTap: () => themeProvider.toggleTheme(),
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                color: AppTheme.accentMint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                color: AppTheme.accentSage,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Dark Mode',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            Switch(
              value: isDark,
              onChanged: (_) => themeProvider.toggleTheme(),
              activeThumbColor: AppTheme.accentGreen,
              activeTrackColor: AppTheme.accentGreen.withValues(alpha: 0.3),
              inactiveThumbColor: AppTheme.textColorMuted(context),
              inactiveTrackColor: AppTheme.borderColorValue(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParentHeader(Color textColor, Color textSecondary, Color cardBg, Color borderColor, Color borderAccent, Color accentMint, Color iconBtnBg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: borderAccent, width: 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: Image.network(
                widget.child.avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: accentMint,
                  child: const Icon(Icons.person, color: AppTheme.primary),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.child.parentNames,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.child.accountType,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, color: textColor, size: 20),
            onPressed: () => _showToast('Profile details updated'),
            style: IconButton.styleFrom(
              backgroundColor: iconBtnBg,
              shape: const CircleBorder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildBadge() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.accentMint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.child_care, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.child.name,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.child.ageYears}y ${widget.child.ageMonths}m • ${widget.child.gender == "boy" ? "Male" : "Female"} • ${widget.child.status}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.accentSage,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, BuildContext context) {
    final sectionColor = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.accentSage
        : AppTheme.primaryContainer;

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: sectionColor,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildGroupContainer(List<Widget> children, BuildContext context) {
    final cardBg = AppTheme.cardBgColor(context);
    final borderColor = AppTheme.borderColorValue(context);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color textColor,
    required Color iconBg,
    required BuildContext context,
  }) {
    final mutedColor = AppTheme.textColorMuted(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.accentSage, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: mutedColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final borderColor = AppTheme.borderColorValue(context);
    return Divider(height: 1, color: borderColor, indent: 16, endIndent: 16);
  }
}
