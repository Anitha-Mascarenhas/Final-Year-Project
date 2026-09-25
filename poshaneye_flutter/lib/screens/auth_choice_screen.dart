import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/topo_header.dart';
import '../widgets/auth_option_card.dart';

enum UserRole { parent, healthcare }

class AuthChoiceScreen extends StatelessWidget {
  final UserRole role;

  const AuthChoiceScreen({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final isParent = role == UserRole.parent;
    final roleTitle = isParent ? 'Parent' : 'Healthcare\nWorker';
    final roleIcon = isParent ? Icons.person_outline_rounded : Icons.medical_services_outlined;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back to roles button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 20, top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: AppColors.textDark,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Back to roles',
                        style: TextStyle(
                          color: AppColors.textDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Topo header with icon pill
              TopoHeader(
                title: roleTitle,
                subtitle: 'Choose how you would like to continue with your PoshanEye account.',
                trailing: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Hero(
                      tag: 'role-icon-${isParent ? 'Parent' : 'Healthcare Worker'}',
                      child: Icon(
                        roleIcon,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Existing: Sign In
              AuthOptionCard(
                tag: 'EXISTING',
                title: 'Sign In',
                description: 'Existing account login',
                isPrimary: true,
                onTap: () {
                  context.push('/sign-in/${role.name}');
                },
              ),
              const SizedBox(height: 16),

              // New: Create Account
              AuthOptionCard(
                tag: 'NEW',
                title: 'Create Account',
                description: 'Register new account',
                isPrimary: false,
                onTap: () {
                  context.push('/sign-up/${role.name}');
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
