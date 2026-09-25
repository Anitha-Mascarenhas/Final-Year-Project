import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/topo_header.dart';
import '../widgets/role_card.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const TopoHeader(
                title: 'Welcome',
                subtitle:
                    'Continue with the role that matches your journey and keep every child milestone in view.',
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  'Who are you?',
                  style: TextStyle(
                    color: AppColors.textDark,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              RoleCard(
                title: 'Parent',
                description: "Manage your child's growth and nutrition",
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
                title: 'Healthcare Worker',
                description: 'Monitor and manage child health records',
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
