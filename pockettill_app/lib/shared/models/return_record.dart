import 'package:isar/isar.dart';

part 'return_record.g.dart';

/// One return transaction against a past [Sale] - covers one or more
/// [ReturnItem]s processed together with a single reason, stock action, and
/// resolution. A sale can have several ReturnRecords over time (partial
/// returns processed on separate occasions).
@collection
class ReturnRecord {
  Id id = Isar.autoIncrement;

  late String uuid;
  late String saleUuid;
  late String deviceId;

  late String reason; // expired_broken | wrong_item | change_of_mind
  late String stockAction; // write_off | restock
  late String resolutionType; // refund | exchange | store_credit

  late double itemsValue; // sum(unitPrice * quantity) of items returned
  double customerOwes = 0; // cash the customer pays (exchange costs more)
  double customerReceives = 0; // cash/credit value the customer gets back

  // Credit customer affected - a refund against a credit sale, or whoever
  // was chosen to receive store credit.
  String? customerId;

  String? exchangeProductUuid;
  String? exchangeProductName; // snapshot

  bool synced = false;
  late DateTime createdAt;

  /// The actual money that moved during this return - positive if the
  /// customer paid extra (an exchange for a pricier replacement), negative
  /// if they got cash or credit back (a refund, store credit, or an
  /// exchange for a cheaper replacement), zero if nothing changed hands (an
  /// even-value exchange). This is what Sales History should show and
  /// total - NOT [itemsValue], which is the value of the goods returned,
  /// not necessarily what actually moved financially (an exchange only
  /// moves the *difference*, not the full item value).
  double get netMoneyMovement {
    if (customerOwes > 0) return customerOwes;
    if (customerReceives > 0) return -customerReceives;
    return 0;
  }
}
