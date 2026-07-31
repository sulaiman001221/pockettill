import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../shared/theme/app_theme.dart';

enum _QuickPreset { last7, last30, thisMonth }

/// Full-page date range picker: quick-select presets, manually-typeable
/// start/end date fields, and a two-tap calendar grid. Pops with the chosen
/// [DateTimeRange], or null if closed without applying.
class SelectDateRangeScreen extends StatefulWidget {
  const SelectDateRangeScreen({super.key, this.initialRange});

  final DateTimeRange? initialRange;

  @override
  State<SelectDateRangeScreen> createState() => _SelectDateRangeScreenState();
}

class _SelectDateRangeScreenState extends State<SelectDateRangeScreen> {
  static final DateFormat _format = DateFormat('dd/MM/yyyy');

  late DateTime _visibleMonth;
  DateTime? _start;
  DateTime? _end;
  _QuickPreset? _activePreset;

  final TextEditingController _startController = TextEditingController();
  final TextEditingController _endController = TextEditingController();
  final FocusNode _startFocus = FocusNode(debugLabel: 'startDate');
  final FocusNode _endFocus = FocusNode(debugLabel: 'endDate');

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _start = widget.initialRange?.start;
    _end = widget.initialRange?.end;
    _visibleMonth = DateTime(
      _start?.year ?? now.year,
      _start?.month ?? now.month,
    );
    _syncControllers();
    // Repaint the boxes' borders when focus moves so the active field is
    // visibly highlighted.
    _startFocus.addListener(() => setState(() {}));
    _endFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _startFocus.dispose();
    _endFocus.dispose();
    super.dispose();
  }

  DateTime get _today {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Writes _start/_end into the text fields without fighting the user's
  /// in-progress typing.
  void _syncControllers() {
    final startText = _start != null ? _format.format(_start!) : '';
    final endText = _end != null ? _format.format(_end!) : '';
    if (_startController.text != startText && !_startFocus.hasFocus) {
      _startController.text = startText;
    }
    if (_endController.text != endText && !_endFocus.hasFocus) {
      _endController.text = endText;
    }
  }

  void _onStartTyped(String value) {
    if (value.length != 10) return;
    DateTime parsed;
    try {
      parsed = _format.parseStrict(value);
    } on FormatException {
      return;
    }
    if (parsed.isAfter(_today)) return;
    setState(() {
      _start = parsed;
      if (_end != null && _end!.isBefore(parsed)) _end = null;
      _activePreset = null;
      _visibleMonth = DateTime(parsed.year, parsed.month);
      _syncControllers();
    });
  }

  void _onEndTyped(String value) {
    if (value.length != 10) return;
    DateTime parsed;
    try {
      parsed = _format.parseStrict(value);
    } on FormatException {
      return;
    }
    if (parsed.isAfter(_today)) return;
    if (_start != null && parsed.isBefore(_start!)) return;
    setState(() {
      _end = parsed;
      _activePreset = null;
      _visibleMonth = DateTime(parsed.year, parsed.month);
      _syncControllers();
    });
  }

  void _selectPreset(_QuickPreset preset) {
    final today = _today;
    setState(() {
      _activePreset = preset;
      switch (preset) {
        case _QuickPreset.last7:
          _end = today;
          _start = today.subtract(const Duration(days: 6));
        case _QuickPreset.last30:
          _end = today;
          _start = today.subtract(const Duration(days: 29));
        case _QuickPreset.thisMonth:
          _start = DateTime(today.year, today.month, 1);
          _end = today;
      }
      _visibleMonth = DateTime(_start!.year, _start!.month);
      _syncControllers();
    });
  }

  void _onDayTap(DateTime day) {
    setState(() {
      if (_start == null || _end != null) {
        _start = day;
        _end = null;
      } else if (day.isBefore(_start!)) {
        _start = day;
      } else {
        _end = day;
      }
      _activePreset = null;
      _syncControllers();
    });
  }

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  void _apply() {
    if (_start == null) return;
    Navigator.of(
      context,
    ).pop(DateTimeRange(start: _start!, end: _end ?? _start!));
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: _DateRangeAppBar(
          onClose: () => Navigator.of(context).pop(),
        ),
        resizeToAvoidBottomInset: false,
        body: Column(
          children: [
            Expanded(
              child: ListView(
                // The body doesn't resize for the keyboard, so pad the list
                // bottom by the keyboard height instead - without this, the
                // typed date fields (and the Apply button below them) can
                // end up hidden behind the keyboard with no way to scroll
                // past it.
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  16 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                children: [
                  const Text(
                    'QUICK SELECT',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _quickChip('Last 7 Days', _QuickPreset.last7),
                      _quickChip('Last 30 Days', _QuickPreset.last30),
                      _quickChip('This Month', _QuickPreset.thisMonth),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _dateField(
                          label: 'START DATE',
                          controller: _startController,
                          focusNode: _startFocus,
                          hasValue: _start != null,
                          onChanged: _onStartTyped,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _dateField(
                          label: 'END DATE',
                          controller: _endController,
                          focusNode: _endFocus,
                          hasValue: _end != null,
                          onChanged: _onEndTyped,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.divider),
                    ),
                    child: _buildCalendar(),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.syncAmber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 14,
                          color: AppTheme.syncAmber,
                        ),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Tap on a start date and an end date to select a '
                            'custom range for your history.',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppTheme.syncAmber,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    offset: const Offset(0, -4),
                    blurRadius: 12,
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 25),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _start != null ? _apply : null,
                  child: const Text('Apply Range'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickChip(String label, _QuickPreset preset) {
    final isActive = _activePreset == preset;
    return InkWell(
      onTap: () => _selectPreset(preset),
      borderRadius: BorderRadius.circular(9999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(9999),
          border: isActive ? null : Border.all(color: AppTheme.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool hasValue,
    required ValueChanged<String> onChanged,
  }) {
    final highlighted = focusNode.hasFocus || hasValue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlighted ? AppTheme.primary : AppTheme.divider,
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 13,
                color: AppTheme.primary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.number,
                  inputFormatters: [_DateSlashFormatter()],
                  onChanged: onChanged,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'DD/MM/YYYY',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: AppTheme.searchPlaceholder,
                    ),
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month, 1);
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leading = firstOfMonth.weekday - 1; // Monday-first grid
    final maxSelectable = _today;

    final cells = <DateTime>[];
    for (var i = leading; i > 0; i--) {
      cells.add(firstOfMonth.subtract(Duration(days: i)));
    }
    for (var d = 1; d <= daysInMonth; d++) {
      cells.add(DateTime(_visibleMonth.year, _visibleMonth.month, d));
    }
    while (cells.length % 7 != 0) {
      cells.add(cells.last.add(const Duration(days: 1)));
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _changeMonth(-1),
            ),
            Text(
              DateFormat('MMMM yyyy').format(_visibleMonth),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _changeMonth(1),
            ),
          ],
        ),
        Row(
          children: ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su']
              .map(
                (d) => Expanded(
                  child: Center(
                    child: Text(
                      d,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < cells.length / 7; row++)
          Row(
            children: List.generate(7, (col) {
              final day = cells[row * 7 + col];
              final inMonth = day.month == _visibleMonth.month;
              final isFuture = day.isAfter(maxSelectable);
              final isStart = _start != null && _isSameDay(day, _start!);
              final isEnd = _end != null && _isSameDay(day, _end!);
              final inRange =
                  _start != null &&
                  _end != null &&
                  day.isAfter(_start!) &&
                  day.isBefore(_end!);
              final selectable = inMonth && !isFuture;

              return Expanded(
                child: GestureDetector(
                  onTap: selectable ? () => _onDayTap(day) : null,
                  child: Container(
                    height: 36,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    decoration: BoxDecoration(
                      color: (isStart || isEnd)
                          ? AppTheme.primary
                          : (inRange
                                ? AppTheme.primary.withValues(alpha: 0.12)
                                : null),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: (isStart || isEnd)
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: (isStart || isEnd)
                              ? Colors.white
                              : !selectable
                              ? AppTheme.iconBorder.withValues(alpha: 0.4)
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }
}

class _DateRangeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _DateRangeAppBar({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.divider, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textPrimary),
                onPressed: onClose,
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Select Date Range',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(72);
}

/// Digits-only date input that inserts the `/` separators itself, so typing
/// "12102026" reads back as "12/10/2026".
class _DateSlashFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final limited = digits.length > 8 ? digits.substring(0, 8) : digits;

    final buffer = StringBuffer();
    for (var i = 0; i < limited.length; i++) {
      buffer.write(limited[i]);
      if ((i == 1 || i == 3) && i != limited.length - 1) {
        buffer.write('/');
      }
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
