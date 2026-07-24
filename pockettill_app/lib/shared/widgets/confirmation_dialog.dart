import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared "Are you sure?" dialog for every destructive/high-consequence
/// confirmation in the app (logout, delete customer, delete product, ...) -
/// one consistent look instead of each screen building its own AlertDialog.
class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog({
    super.key,
    this.title = 'Are you sure?',
    required this.message,
    required this.confirmLabel,
    this.confirmColor = AppTheme.logoutRed,
    required this.onConfirm,
    this.onCancel,
  });

  final String title;
  final String message;
  final String confirmLabel;

  /// Defaults to red (destructive actions like delete) - pass
  /// [AppTheme.primary] for non-destructive confirmations like logout.
  final Color confirmColor;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    // Pops this dialog's own route first, then runs the caller's callback -
    // not the other order. onConfirm can itself navigate (e.g. logout
    // clearing the whole stack back to Welcome), and popping a route that a
    // pushAndRemoveUntil has already swept away is the wrong order to risk.
    void handleCancel() {
      Navigator.of(context).pop();
      onCancel?.call();
    }

    void handleConfirm() {
      Navigator.of(context).pop();
      onConfirm();
    }

    return Dialog(
      backgroundColor: AppTheme.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, color: Color(0xFF4A5568)),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: AppTheme.textPrimary,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: handleCancel,
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: confirmColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: handleConfirm,
                          child: Text(
                            confirmLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: GestureDetector(
              onTap: handleCancel,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFF5F5F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  size: 18,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
