import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/credit_customer.dart';
import '../../shared/repositories/repositories.dart';
import '../../shared/theme/app_theme.dart';
import '../../shared/utils/credit_balance_display.dart';
import '../../shared/widgets/pockettill_app_bar.dart';
import '../stock/stock_ui.dart';
import 'add_customer_screen.dart';
import 'customer_detail_screen.dart';

enum _CreditFilter { all, owing, settled }

/// Credit customer list: search/filter, summary cards, and the scrollable
/// customer list. All reads/writes go through [creditRepositoryProvider] -
/// never directly to Isar.
class CreditScreen extends ConsumerStatefulWidget {
  const CreditScreen({super.key});

  @override
  ConsumerState<CreditScreen> createState() => _CreditScreenState();
}

class _CreditScreenState extends ConsumerState<CreditScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode(debugLabel: 'search');

  List<CreditCustomer> _customers = [];
  bool _loading = true;
  _CreditFilter _filter = _CreditFilter.all;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() => _loading = true);
    final customers = await ref.read(creditRepositoryProvider).getAll();
    if (!mounted) return;
    setState(() {
      _customers = customers;
      _loading = false;
    });
  }

  bool _matchesFilter(CreditCustomer customer, _CreditFilter filter) {
    switch (filter) {
      case _CreditFilter.all:
        return true;
      case _CreditFilter.owing:
        return customer.balance > 0;
      case _CreditFilter.settled:
        return customer.balance <= 0;
    }
  }

  int _countFor(_CreditFilter filter) =>
      _customers.where((c) => _matchesFilter(c, filter)).length;

  double get _totalOwing =>
      _customers.fold(0.0, (sum, c) => sum + c.balance);

  List<CreditCustomer> get _filteredCustomers {
    var list = _customers.where((c) => _matchesFilter(c, _filter));
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      list = list.where(
        (c) =>
            c.name.toLowerCase().contains(query) ||
            (c.phone ?? '').toLowerCase().contains(query),
      );
    }
    return list.toList();
  }

  Future<void> _openAddCustomer() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AddCustomerScreen()));
    await _loadCustomers();
  }

  Future<void> _openCustomerDetail(CreditCustomer customer) async {
    // The deleted customer object from CustomerDetailScreen's overflow menu,
    // or null for anything else (just backing out, editing in place, etc).
    final deleted = await Navigator.of(context).push<CreditCustomer>(
      MaterialPageRoute(
        builder: (_) => CustomerDetailScreen(customerUuid: customer.uuid),
      ),
    );
    await _loadCustomers();
    if (!mounted || deleted == null) return;
    _handleCustomerDeleted(deleted);
  }

  /// Soft-delete: removes [customer] from the list immediately and shows an
  /// Undo snackbar. The customer isn't actually removed from Isar until that
  /// snackbar closes without Undo having been tapped - so tapping Undo never
  /// needs to "restore" anything to Isar, since it was never deleted there
  /// in the first place.
  void _handleCustomerDeleted(CreditCustomer customer) {
    // Capture the repository now rather than reading it from `ref` inside
    // the delayed callback below - `ref` stops being usable if this screen
    // gets disposed before the undo window elapses, but a plain repository
    // reference doesn't care about this widget's lifecycle.
    final repo = ref.read(creditRepositoryProvider);

    setState(() {
      _customers = _customers.where((c) => c.uuid != customer.uuid).toList();
    });

    var restored = false;

    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    final snackBar = messenger.showSnackBar(
      SnackBar(
        content: const Text('Customer deleted'),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            restored = true;
            if (!mounted) return;
            setState(() {
              _customers = [..._customers, customer]
                ..sort((a, b) => a.name.compareTo(b.name));
            });
          },
        ),
      ),
    );

    // A snackbar with an action never auto-dismisses while an accessibility
    // service is running (Flutter ignores `duration` then, to keep the
    // action reachable) - so close it manually. `closed` fires either way,
    // which is also our cue to actually commit the delete if Undo wasn't
    // tapped.
    var closed = false;
    snackBar.closed.whenComplete(() {
      closed = true;
      if (!restored) repo.deleteCustomer(customer.uuid);
    });
    Timer(const Duration(seconds: 4), () {
      if (!closed) snackBar.close();
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCustomers;

    return GestureDetector(
      // Tapping anywhere outside the search field dismisses its focus -
      // without this, once focused it never lets go, even on an outside tap.
      onTap: () =>
          _searchFocusNode.unfocus(disposition: UnfocusDisposition.scope),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        appBar: const CustomAppBar(showMenuIcon: false, title: 'Customers'),
        backgroundColor: AppTheme.background,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openAddCustomer,
          backgroundColor: AppTheme.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'Add New Customer',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadCustomers,
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(child: _buildSearchBar()),
                    SliverToBoxAdapter(child: _buildFilterChips()),
                    SliverToBoxAdapter(child: _buildSummaryCards()),
                    SliverToBoxAdapter(
                      child: _SectionHeader(count: _customers.length),
                    ),
                    if (_customers.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(
                          icon: Icons.people_outline,
                          title: 'No customers yet',
                          subtitle: 'Tap Add New Customer to get started',
                        ),
                      )
                    else if (filtered.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _EmptyState(
                          icon: Icons.search_off,
                          title: 'No matching customers',
                          subtitle: 'Try a different search or filter',
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final customer = filtered[index];
                            return _CustomerListItem(
                              customer: customer,
                              onTap: () => _openCustomerDetail(customer),
                            );
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    const SliverToBoxAdapter(child: SizedBox(height: 96)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, 4),
              blurRadius: 6,
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.search,
              color: AppTheme.searchPlaceholder,
            ),
            hintText: 'Search customer name...',
            hintStyle: AppTheme.searchPlaceholderStyle,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            disabledBorder: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _FilterChipButton(
            label: 'All',
            count: _countFor(_CreditFilter.all),
            isActive: _filter == _CreditFilter.all,
            onTap: () => setState(() => _filter = _CreditFilter.all),
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            label: 'Owing',
            count: _countFor(_CreditFilter.owing),
            isActive: _filter == _CreditFilter.owing,
            onTap: () => setState(() => _filter = _CreditFilter.owing),
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            label: 'Settled',
            count: _countFor(_CreditFilter.settled),
            isActive: _filter == _CreditFilter.settled,
            onTap: () => setState(() => _filter = _CreditFilter.settled),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              label: 'Total Customers',
              value: '${_customers.length}',
              color: AppTheme.textPrimary,
              background: AppTheme.surface,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              label: 'Total Credit Taken',
              value: _totalOwing < 0
                  ? '-R${(-_totalOwing).toStringAsFixed(0)}'
                  : 'R${_totalOwing.toStringAsFixed(0)}',
              color: creditBalanceColor(_totalOwing),
              background: creditBalanceColor(_totalOwing).withValues(alpha: 0.1),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              label: 'Settled Customers',
              value: '${_countFor(_CreditFilter.settled)}',
              color: AppTheme.syncGreen,
              background: AppTheme.syncGreen.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          const Text(
            'ALL CUSTOMERS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const Spacer(),
          Text(
            '$count customer${count == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.count,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(9999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primary : AppTheme.surface,
            borderRadius: BorderRadius.circular(9999),
            border: isActive ? null : Border.all(color: AppTheme.divider),
          ),
          child: Text(
            '$label $count',
            style: TextStyle(
              color: isActive ? Colors.white : AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CustomerListItem extends StatelessWidget {
  const _CustomerListItem({required this.customer, required this.onTap});

  final CreditCustomer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final owing = customer.balance > 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              offset: const Offset(0, 2),
              blurRadius: 4,
            ),
          ],
        ),
        child: Row(
          children: [
            ProductAvatar(name: customer.name),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppTheme.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if ((customer.phone ?? '').isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(customer.phone!, style: AppTheme.bodySubtitle),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (owing)
              Text(
                'Owes ${formatCreditBalance(customer.balance)}',
                style: const TextStyle(
                  color: AppTheme.logoutRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              )
            else if (customer.balance < 0)
              Text(
                'Credit ${formatCreditBalance(customer.balance)}',
                style: const TextStyle(
                  color: AppTheme.syncGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.syncGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Settled',
                    style: TextStyle(
                      color: AppTheme.syncGreen,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: AppTheme.iconBorder),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: AppTheme.iconBorder),
            const SizedBox(height: 16),
            Text(title, style: AppTheme.mainTitle, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTheme.bodySubtitle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
