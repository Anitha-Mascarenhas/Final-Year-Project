import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../utils/l10n_extension.dart';
import '../widgets/topo_header.dart';
import '../widgets/role_card.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TopoHeader(
                title: l10n.welcomeTitle,
                subtitle: l10n.welcomeSubtitle,
              ).animate().fadeIn(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                  ).slideY(
                    begin: 0.08,
                    end: 0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                  ),
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  l10n.whoAreYou,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              RoleCard(
                title: l10n.roleParentTitle,
                description: l10n.roleParentDesc,
                icon: Icons.person_outline_rounded,
                onTap: () {
                  context.push('/auth/parent');
                },
              ).animate(delay: const Duration(milliseconds: 100)).fadeIn(
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                  ).slideX(
                    begin: 0.08,
                    end: 0,
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                  ),
              const SizedBox(height: 16),
              RoleCard(
                title: l10n.roleHealthcareTitle,
                description: l10n.roleHealthcareDesc,
                icon: Icons.medical_services_outlined,
                onTap: () {
                  context.push('/auth/healthcare');
                },
              ).animate(delay: const Duration(milliseconds: 180)).fadeIn(
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                  ).slideX(
                    begin: 0.08,
                    end: 0,
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                  ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
