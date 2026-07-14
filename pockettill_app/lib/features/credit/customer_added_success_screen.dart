import 'package:flutter/material.dart';

import '../../shared/models/credit_customer.dart';
import '../../shared/theme/app_theme.dart';
import '../stock/stock_ui.dart';
import 'add_customer_screen.dart';

/// Shown after successfully adding a new credit customer.
class CustomerAddedSuccessScreen extends StatefulWidget {
  const CustomerAddedSuccessScreen({super.key, required this.customer});

  final CreditCustomer customer;

  @override
  State<CustomerAddedSuccessScreen> createState() =>
      _CustomerAddedSuccessScreenState();
}

class _CustomerAddedSuccessScreenState
    extends State<CustomerAddedSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );
  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.elasticOut,
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addAnother() {
    // pushReplacement only swaps out this Success screen - the AddCustomer
    // screen that led here would still sit underneath, stale form data and
    // all. Pop both, then push a genuinely fresh form.
    Navigator.of(context)
      ..pop()
      ..pop();
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddCustomerScreen()));
  }

  void _goToCustomers() {
    // Stack is Shell -> Credit -> AddCustomer -> Success; pop the last two.
    Navigator.of(context)
      ..pop()
      ..pop();
  }

  void _returnHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final customer = widget.customer;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 32),
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppTheme.syncGreen.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppTheme.syncGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Customer Added!', style: AppTheme.mainTitle),
              const SizedBox(height: 8),
              Text(
                '${customer.name} has been added to your customer list.',
                textAlign: TextAlign.center,
                style: AppTheme.bodySubtitle,
              ),
              const SizedBox(height: 24),
              _CustomerSummaryCard(customer: customer),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _addAnother,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Another Customer'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: _goToCustomers,
                  child: const Text('Go to Customers'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _returnHome,
                child: const Text(
                  'Return Home',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _CustomerSummaryCard extends StatelessWidget {
  const _CustomerSummaryCard({required this.customer});

  final CreditCustomer customer;

  @override
  Widget build(BuildContext context) {
    final phone = customer.phone;
    final limit = customer.creditLimit;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Row(
            children: [
              ProductAvatar(name: customer.name),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  customer.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.divider, height: 1),
          const SizedBox(height: 16),
          _row('Phone', (phone == null || phone.isEmpty) ? 'Not provided' : phone),
          const SizedBox(height: 12),
          _row(
            'Credit Limit',
            limit != null ? 'R${limit.toStringAsFixed(2)}' : 'No limit',
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Row(
      children: [
        Text(label, style: AppTheme.bodySubtitle),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
