import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One titled section of bullet points - shared by the Privacy Policy and
/// Terms of Service screens, which are both just a list of these.
class PolicySection extends StatelessWidget {
  const PolicySection({super.key, required this.title, required this.points});

  final String title;
  final List<String> points;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          for (final point in points)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      point,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
