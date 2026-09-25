import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../widgets/topo_header.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/auth_tabs.dart';
import 'auth_choice_screen.dart';
import '../state/session_provider.dart';

class SignUpScreen extends StatefulWidget {
  final UserRole role;

  const SignUpScreen({super.key, required this.role});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _emailController = TextEditingController();
  final _hospitalIdController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _emailController.dispose();
    _hospitalIdController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365)),
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryForest,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _dobController.text =
            '${picked.day.toString().padLeft(2, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.year}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isParent = widget.role == UserRole.parent;
    final title = isParent ? 'Create Account' : 'Join Clinician';
    final subtitle = isParent
        ? 'Set up your family account and track child growth.'
        : 'Create a protected workspace for clinical monitoring.';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
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
                        'Back',
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

              // Header
              TopoHeader(
                title: title,
                subtitle: subtitle,
              ),
              const SizedBox(height: 28),

              // Form fields
              if (isParent) ...[
                CustomTextField(
                  label: 'CHILD NAME',
                  hint: 'Aarav',
                  controller: _nameController,
                  prefixIcon: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.textSubtle,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'DATE OF BIRTH',
                  hint: 'dd-mm-yyyy',
                  controller: _dobController,
                  readOnly: true,
                  onTap: _selectDate,
                  prefixIcon: const Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.textSubtle,
                    size: 20,
                  ),
                  suffixIcon: IconButton(
                    icon: const Icon(
                      Icons.calendar_month_outlined,
                      color: AppColors.textSubtle,
                      size: 20,
                    ),
                    onPressed: _selectDate,
                  ),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'EMAIL',
                  hint: 'hello@poshaneye.com',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(
                    Icons.mail_outline_rounded,
                    color: AppColors.textSubtle,
                    size: 22,
                  ),
                ),
              ] else ...[
                CustomTextField(
                  label: 'NAME',
                  hint: 'Dr. Priya Nair',
                  controller: _nameController,
                  prefixIcon: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.textSubtle,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'EMAIL',
                  hint: 'doctor@hospital.org',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: const Icon(
                    Icons.mail_outline_rounded,
                    color: AppColors.textSubtle,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: 'HOSPITAL ID',
                  hint: 'HID-2341',
                  controller: _hospitalIdController,
                  prefixIcon: const Icon(
                    Icons.local_hospital_outlined,
                    color: AppColors.textSubtle,
                    size: 22,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              CustomTextField(
                label: 'PASSWORD',
                hint: 'Min 8 characters',
                controller: _passwordController,
                isPassword: true,
                prefixIcon: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.textSubtle,
                  size: 22,
                ),
              ),
              const SizedBox(height: 16),

              CustomTextField(
                label: 'CONFIRM PASSWORD',
                hint: 'Repeat password',
                controller: _confirmPasswordController,
                isPassword: true,
                prefixIcon: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.textSubtle,
                  size: 22,
                ),
              ),
              const SizedBox(height: 24),

              // Tabs
              AuthTabs(
                isSignIn: false,
                onTabChanged: (isSignIn) {
                  if (isSignIn) {
                    context.go('/sign-in/${widget.role.name}');
                  }
                },
              ),
              const SizedBox(height: 20),

              // CTA
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    final enteredName = _nameController.text.trim();
                    final fallback = widget.role == UserRole.parent ? 'Aarav' : 'Dr. Priya';
                    final childName = enteredName.isNotEmpty ? enteredName : fallback;
                    ProviderScope.containerOf(context, listen: false)
                        .read(sessionProvider.notifier)
                        .signInAs(childName);
                    context.go('/app', extra: childName);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryForest,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text(
                        'Create account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
