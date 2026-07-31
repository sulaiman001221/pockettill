import 'printer_service.dart';

/// [PrinterService] fallback for devices with no printing hardware, such as
/// regular Android phones. Printing is silently skipped.
class NoopPrinterService implements PrinterService {
  @override
  Future<void> printReceipt(Map<String, dynamic> saleData) async {}

  @override
  Future<void> printEndOfDaySummary(Map<String, dynamic> summaryData) async {}

  @override
  Future<bool> isPrinterAvailable() async => false;
}
