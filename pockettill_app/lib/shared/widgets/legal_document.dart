import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// One block of a [LegalSection]'s body - either a plain paragraph or a
/// bulleted list, in the order they should render.
sealed class LegalBlock {
  const LegalBlock();
}

class LegalParagraph extends LegalBlock {
  const LegalParagraph(this.text);
  final String text;
}

class LegalBullets extends LegalBlock {
  const LegalBullets(this.items);
  final List<String> items;
}

/// A numbered sub-heading within a section (e.g. "1.1 Account
/// Information") - rendered a step down from the section heading.
class LegalSubheading extends LegalBlock {
  const LegalSubheading(this.text);
  final String text;
}

/// One numbered section of a legal document (e.g. "3. Your Shop Data"),
/// made of an ordered mix of paragraphs and bullet lists.
class LegalSection {
  const LegalSection(this.heading, this.blocks);
  final String heading;
  final List<LegalBlock> blocks;
}

/// Renders a full legal document (Privacy Policy, Terms of Use) from a flat
/// list of [LegalSection]s - shared by [PrivacyPolicyScreen] and
/// [TermsOfServiceScreen] so both render the same way from the same data
/// shape, rather than each hand-rolling its own paragraph/bullet layout.
class LegalDocument extends StatelessWidget {
  const LegalDocument({
    super.key,
    required this.title,
    required this.effectiveDate,
    required this.intro,
    required this.sections,
  });

  final String title;
  final String effectiveDate;
  final List<String> intro;
  final List<LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(title, style: AppTheme.mainTitle),
        const SizedBox(height: 4),
        Text(
          effectiveDate,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),
        for (final paragraph in intro) ...[
          Text(
            paragraph,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 8),
        for (final section in sections) _buildSection(section),
      ],
    );
  }

  Widget _buildSection(LegalSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.heading,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          for (final block in section.blocks) _buildBlock(block),
        ],
      ),
    );
  }

  Widget _buildBlock(LegalBlock block) {
    return switch (block) {
      LegalSubheading(:final text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
      LegalParagraph(:final text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textPrimary,
            height: 1.5,
          ),
        ),
      ),
      LegalBullets(:final items) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(Icons.circle, size: 5, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    };
  }
}
