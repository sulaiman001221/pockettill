import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/repositories/store_config_provider.dart';
import '../../shared/theme/app_theme.dart';
import '../shell/shell_screen.dart';

/// One-time celebration shown right after registration to a store that
/// landed in PocketTill's first 100 (see `is_founding_store` in Supabase).
class FoundingStoreScreen extends ConsumerStatefulWidget {
  const FoundingStoreScreen({super.key});

  @override
  ConsumerState<FoundingStoreScreen> createState() =>
      _FoundingStoreScreenState();
}

class _FoundingStoreScreenState extends ConsumerState<FoundingStoreScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scale = CurvedAnimation(parent: _controller, curve: Curves.elasticOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storeName = ref.watch(storeConfigProvider)?.storeName ?? '';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFBEB), Color(0xFFFEF9C3)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 40),
              ScaleTransition(
                scale: _scale,
                child: const Icon(
                  Icons.emoji_events,
                  size: 100,
                  color: Color(0xFFD69E2E),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '🎉 Founding Store!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              if (storeName.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  storeName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  "You're one of PocketTill's first 100 stores. As a thank "
                  "you, you'll receive a 50% lifetime discount when billing "
                  'begins.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Color(0xFF4A5568)),
                ),
              ),
              const SizedBox(height: 32),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    _BenefitRow('Free during the entire beta period'),
                    SizedBox(height: 12),
                    _BenefitRow('50% lifetime discount when billing begins'),
                    SizedBox(height: 12),
                    _BenefitRow('Priority support from the PocketTill team'),
                    SizedBox(height: 12),
                    _BenefitRow('Help shape the product with your feedback'),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              const Expanded(child: SizedBox()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const ShellScreen()),
                      (route) => false,
                    ),
                    child: const Text(
                      'Start Using PocketTill →',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
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

class _BenefitRow extends StatelessWidget {
  const _BenefitRow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.check_circle_outline,
          color: AppTheme.syncGreen,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
          ),
        ),
      ],
    );
  }
}
