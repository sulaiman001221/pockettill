import 'package:isar/isar.dart';

part 'risk_log.g.dart';

/// A potentially suspicious stock or credit event, surfaced on the Risk Log
/// screen for the store owner to review - an append-only audit trail,
/// never edited or deleted once recorded.
///
/// [type] is one of: `manual_stock_reduction`, `product_deleted`,
/// `price_changed`, `manual_credit`, `credit_writeoff` - a plain string
/// (not a Dart enum) to match every other `type`/`reason`-style field in
/// this app (see `Sale.paymentType`, `ReturnRecord.reason`), and because
/// it's written unchanged straight into the `risk_log` table's own `type`
/// column.
@collection
class RiskLog {
  Id id = Isar.autoIncrement;

  late String uuid;
  late String type;
  late String description;
  String? beforeValue;
  String? afterValue;
  late String entityName;
  late DateTime timestamp;
  bool synced = false;
}
