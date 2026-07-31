/// Abstraction over receipt printing hardware.
///
/// Implementations exist for Sunmi's integrated printer
/// ([SunmiPrinterService]) and a no-op fallback ([NoopPrinterService]) for
/// devices without printing hardware, such as regular Android phones.
abstract class PrinterService {
  /// Prints a receipt for the given sale.
  Future<void> printReceipt(Map<String, dynamic> saleData);

  /// Prints the end-of-day reconciliation summary.
  ///
  /// [summaryData] carries the same shape [HistorySummary] does, plus a
  /// `date` and `storeName` - see `EndOfDayScreen` for exactly what's built.
  Future<void> printEndOfDaySummary(Map<String, dynamic> summaryData);

  /// Whether printing hardware is currently available.
  Future<bool> isPrinterAvailable();
}
