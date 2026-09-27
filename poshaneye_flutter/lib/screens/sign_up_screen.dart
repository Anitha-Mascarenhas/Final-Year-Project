import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../utils/l10n_extension.dart';
import '../widgets/topo_header.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/auth_tabs.dart';
import 'auth_choice_screen.dart';
import '../state/session_provider.dart';
import '../services/api_service.dart';

class SignUpScreen extends StatefulWidget {
  final UserRole role;

  const SignUpScreen({super.key, required this.role});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  bool _busy = false;
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

  Future<void> _createAccount() async {
    final parent = widget.role == UserRole.parent;
    final password = _passwordController.text;
    if (password.length < 8 || password != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Enter matching passwords with at least 8 characters.')));
      return;
    }
    final body = <String, dynamic>{
      'email': _emailController.text.trim().isEmpty
          ? null
          : _emailController.text.trim(),
      'password': password,
      'confirmPassword': _confirmPasswordController.text,
      if (parent) ...{
        'childName': _nameController.text.trim(),
        'dob': _parseDob(),
      } else ...{
        'name': _nameController.text.trim(),
        'hospitalId': _hospitalIdController.text.trim(),
      },
    };
    if (_nameController.text.trim().isEmpty ||
        (parent && _dobController.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Complete all required fields.')));
      return;
    }
    setState(() => _busy = true);
    try {
      final created = await ApiService.signUp(parent: parent, body: body);
      final id = (created[parent ? 'childId' : 'workerId'] ?? '').toString();
      final session =
          await ApiService.login(id: id, password: password, parent: parent);
      if (!mounted) return;
      final name =
          parent ? _nameController.text.trim() : _nameController.text.trim();
      ProviderScope.containerOf(context, listen: false)
          .read(sessionProvider.notifier)
          .signInAs(name,
              childId: parent ? id : null,
              accessToken: session['access_token']?.toString(),
              dateOfBirth: session['dateOfBirth']?.toString());
      context.go('/app', extra: name);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not create account: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _parseDob() {
    final bits = _dobController.text.split('-');
    if (bits.length != 3) return '';
    return '${bits[2]}-${bits[1]}-${bits[0]}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isParent = widget.role == UserRole.parent;
    final title = isParent ? l10n.createAccountTitle : l10n.joinClinician;
    final subtitle =
        isParent ? l10n.parentSignUpSubtitle : l10n.healthcareSignUpSubtitle;

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
                    children: [
                      const Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: AppColors.textDark,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.backButton,
                        style: const TextStyle(
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
                  label: l10n.childNameLabel,
                  hint: l10n.childNameHint,
                  controller: _nameController,
                  prefixIcon: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.textSubtle,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: l10n.dobLabel,
                  hint: l10n.dobHint,
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
                  label: l10n.emailLabel,
                  hint: l10n.emailHint,
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
                  label: l10n.nameLabel,
                  hint: l10n.doctorNameHint,
                  controller: _nameController,
                  prefixIcon: const Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.textSubtle,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 16),
                CustomTextField(
                  label: l10n.emailLabel,
                  hint: l10n.doctorEmailHint,
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
                  label: l10n.hospitalIdLabel,
                  hint: l10n.hospitalIdHint,
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
                label: l10n.passwordLabel,
                hint: l10n.passwordMinHint,
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
                label: l10n.confirmPasswordLabel,
                hint: l10n.confirmPasswordHint,
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
                  onPressed: _busy ? null : _createAccount,
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
                    children: [
                      if (_busy)
                        const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                      else
                        Text(
                          l10n.createAccountButton,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 18),
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
