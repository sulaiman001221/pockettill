import 'package:isar/isar.dart';

part 'extra_income.g.dart';

/// One-off income that isn't a regular sale - e.g. airtime vouchers or
/// electricity tokens sold outside the normal checkout flow. Counted toward
/// the day's revenue total (Sales History, End of Day Summary) but
/// deliberately excluded from sale counts/averages, since it isn't a sale.
@collection
class ExtraIncome {
  Id id = Isar.autoIncrement;

  late String uuid;
  late double amount;
  late String description;
  bool synced = false;
  late DateTime createdAt;
}
