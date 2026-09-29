import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class SignInScreen extends StatefulWidget {
  final UserRole role;

  const SignInScreen({super.key, required this.role});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  bool _busy = false;

  final _idController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final l10n = context.l10n;
    final enteredId = _idController.text.trim().toUpperCase();
    final enteredPassword = _passwordController.text;

    if (enteredId.isEmpty || enteredPassword.isEmpty) {
      _showError(l10n.errorEnterIdPassword);
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await ApiService.login(
          id: enteredId,
          password: enteredPassword,
          parent: widget.role == UserRole.parent);
      if (!mounted) return;
      final childName = result['childName']?.toString() ?? 'Health worker';
      final childId = result['childId']?.toString();
      ProviderScope.containerOf(context, listen: false)
          .read(sessionProvider.notifier)
          .signInAs(childName,
              childId: childId,
              accessToken: result['access_token']?.toString(),
              dateOfBirth: result['dateOfBirth']?.toString());
      if (widget.role == UserRole.parent) {
        // Show child ID popup before navigating
        await _showChildIdDialog(childId ?? enteredId, childName);
        if (!mounted) return;
        context.go('/app', extra: childName);
      } else {
        context.go('/healthcare-dashboard');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showChildIdDialog(String childId, String childName) async {
    bool copied = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          backgroundColor: AppColors.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.primaryForest.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.badge_outlined,
                  color: AppColors.primaryForest,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome, $childName!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Save your Child ID — you\'ll need it every time you sign in.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSubtle,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              // Child ID box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.primaryForest.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primaryForest.withOpacity(0.25),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      childId,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryForest,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: childId));
                        setState(() => copied = true);
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: copied
                            ? const Icon(Icons.check_circle_rounded,
                                key: ValueKey('check'),
                                color: Colors.green,
                                size: 22)
                            : const Icon(Icons.copy_rounded,
                                key: ValueKey('copy'),
                                color: AppColors.textSubtle,
                                size: 22),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryForest,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Got it, Continue',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isParent = widget.role == UserRole.parent;
    final title = isParent ? l10n.welcomeBack : l10n.clinicalSignIn;
    final subtitle =
        isParent ? l10n.parentSignInSubtitle : l10n.healthcareSignInSubtitle;
    final idLabel = isParent ? l10n.childIdLabel : l10n.hospitalIdLabel;
    final idHint = isParent ? l10n.childIdHint : l10n.hospitalIdHint;
    final idIcon =
        isParent ? Icons.verified_user_outlined : Icons.badge_outlined;

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
              CustomTextField(
                label: idLabel,
                hint: idHint,
                controller: _idController,
                prefixIcon: Icon(idIcon, color: AppColors.textSubtle, size: 22),
              ),
              const SizedBox(height: 18),

              CustomTextField(
                label: l10n.passwordLabel,
                hint: l10n.passwordHint,
                controller: _passwordController,
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
                isSignIn: true,
                onTabChanged: (isSignIn) {
                  if (!isSignIn) {
                    context.go('/sign-up/${widget.role.name}');
                  }
                },
              ),
              const SizedBox(height: 20),

              // Continue CTA
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _busy ? null : _signIn,
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
                          l10n.continueButton,
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
