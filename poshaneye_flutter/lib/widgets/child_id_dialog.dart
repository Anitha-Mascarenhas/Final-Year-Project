import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

bool isValidChildId(Object? value) =>
    value is String && RegExp(r'^CHD\d{3,}$').hasMatch(value.trim());

Future<void> showChildIdDialog(
  BuildContext context, {
  required String childId,
  required String childName,
}) async {
  if (!isValidChildId(childId)) {
    throw ArgumentError.value(
        childId, 'childId', 'Expected an assigned Child ID.');
  }

  var copied = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        backgroundColor: AppColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryForest.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.badge_outlined,
                  color: AppColors.primaryForest, size: 32),
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
                  fontSize: 13.5, color: AppColors.textSubtle, height: 1.4),
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.primaryForest.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.primaryForest.withValues(alpha: 0.25),
                    width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      childId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryForest,
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: childId));
                      setDialogState(() => copied = true);
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
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryForest,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('Got it, Continue',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
