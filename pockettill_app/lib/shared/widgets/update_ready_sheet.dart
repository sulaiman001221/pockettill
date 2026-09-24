import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Bottom sheet shown when the owner taps "Update Now" on the update banner.
///
/// Installing a downloaded update restarts the app, so it gets a confirmation
/// step - a sheet rather than a centred dialog because the restart is a
/// choice about *when* (finish the sale first, or go now), which reads as
/// "later / now" more naturally from the bottom of the screen. Visually the
/// twin of [ConfirmationDialog] (same title/body type, radius, close button
/// and button pair) so the two feel like one family.
///
/// Returns true if the owner chose to restart and update.
Future<bool> showUpdateReadySheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppTheme.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => const _UpdateReadySheet(),
  );
  return result ?? false;
}

class _UpdateReadySheet extends StatelessWidget {
  const _UpdateReadySheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 32, 32, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEBF8FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_outlined,
                    size: 28,
                    color: Color(0xFF3182CE),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Update ready',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'A newer version of PocketTill has finished downloading. '
                  'The app will restart to install it - your data is safe and '
                  'nothing you have saved will be lost.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Color(0xFF4A5568)),
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
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text(
                            'Later',
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
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text(
                            'Restart & Update',
                            style: TextStyle(
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
              onTap: () => Navigator.of(context).pop(false),
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
