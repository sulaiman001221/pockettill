import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

import 'printer_service.dart';

/// [PrinterService] backed by Sunmi's integrated thermal receipt printer.
class SunmiPrinterService implements PrinterService {
  final SunmiPrinterPlus _printer = SunmiPrinterPlus();

  @override
  Future<bool> isPrinterAvailable() async {
    try {
      final status = await _printer.getStatus();
      return status != null;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<void> printReceipt(Map<String, dynamic> saleData) async {
    final storeName = saleData['storeName'] as String? ?? 'My Store';
    final items = (saleData['items'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();
    final total = saleData['total'] as num? ?? 0;
    final paymentMethod = saleData['paymentMethod'] as String? ?? 'Cash';
    final transactionNumber = saleData['transactionNumber'];
    final date = saleData['date'] as DateTime? ?? DateTime.now();
    final customerName = saleData['customerName'] as String?;

    await _printer.printText(
      text: storeName,
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true, fontSize: 32),
    );
    await _printer.printText(
      text: 'PocketTill POS',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
    );
    await _printer.line();

    await _printer.printText(text: DateFormat('dd/MM/yy HH:mm').format(date));
    await _printer.printText(text: 'Transaction: #$transactionNumber');
    if (customerName != null && customerName.isNotEmpty) {
      await _printer.printText(text: 'Customer: $customerName');
    }
    await _printer.line();

    for (final item in items) {
      final name = item['name'] as String? ?? '';
      final quantity = item['quantity'] as num? ?? 1;
      final price = item['price'] as num? ?? 0;
      await _printer.printRow(
        cols: [
          SunmiColumn(text: name, width: 2),
          SunmiColumn(
            text: '$quantity x R${price.toStringAsFixed(2)}',
            width: 1,
            style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
          ),
        ],
      );
    }

    await _printer.line();
    await _printer.printRow(
      cols: [
        SunmiColumn(text: 'TOTAL:', width: 1, style: SunmiTextStyle(bold: true)),
        SunmiColumn(
          text: 'R${total.toStringAsFixed(2)}',
          width: 1,
          style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );
    await _printer.printRow(
      cols: [
        SunmiColumn(text: 'Payment:', width: 1),
        SunmiColumn(
          text: paymentMethod,
          width: 1,
          style: SunmiTextStyle(align: SunmiPrintAlign.RIGHT),
        ),
      ],
    );
    await _printer.line();
    await _printer.printText(
      text: 'Thank you for your business!',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
    );
    await _printer.printText(
      text: 'Powered by PocketTill',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
    );
    await _printer.lineWrap(times: 2);
    await _printer.cutPaper();
  }

  @override
  Future<void> printEndOfDaySummary(Map<String, dynamic> summaryData) async {
    final storeName = summaryData['storeName'] as String? ?? 'My Store';
    final date = summaryData['date'] as DateTime? ?? DateTime.now();
    final totalRevenue = (summaryData['totalRevenue'] as num? ?? 0).toDouble();
    final cashSales = (summaryData['cashSales'] as num? ?? 0).toDouble();
    final cardSales = (summaryData['cardSales'] as num? ?? 0).toDouble();
    final creditSales = (summaryData['creditSales'] as num? ?? 0).toDouble();
    final cashRepayments =
        (summaryData['cashRepaymentsCollected'] as num? ?? 0).toDouble();
    final cardRepayments =
        (summaryData['cardRepaymentsCollected'] as num? ?? 0).toDouble();
    final returnsNet = (summaryData['returnsNet'] as num? ?? 0).toDouble();
    final totalExpected =
        (summaryData['totalExpected'] as num? ?? 0).toDouble();

    Future<void> row(String label, String value, {bool bold = false}) {
      return _printer.printRow(
        cols: [
          SunmiColumn(text: label, width: 2, style: SunmiTextStyle(bold: bold)),
          SunmiColumn(
            text: value,
            width: 1,
            style: SunmiTextStyle(bold: bold, align: SunmiPrintAlign.RIGHT),
          ),
        ],
      );
    }

    await _printer.printText(
      text: storeName,
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, bold: true, fontSize: 32),
    );
    await _printer.printText(
      text: 'End of Day Summary',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
    );
    await _printer.line();
    await _printer.printText(text: DateFormat('dd/MM/yy HH:mm').format(date));
    await _printer.line();

    await row('Total Revenue', 'R${totalRevenue.toStringAsFixed(2)}');
    await _printer.line();
    await row('Cash Sales', 'R${cashSales.toStringAsFixed(2)}');
    await row('Card Sales', 'R${cardSales.toStringAsFixed(2)}');
    await row('Credit Sales (not received)', 'R${creditSales.toStringAsFixed(2)}');
    if (cashRepayments > 0) {
      await row('Cash Repayments', 'R${cashRepayments.toStringAsFixed(2)}');
    }
    if (cardRepayments > 0) {
      await row('Card Repayments', 'R${cardRepayments.toStringAsFixed(2)}');
    }
    if (returnsNet != 0) {
      final label = returnsNet < 0 ? 'Returns (refunds given)' : 'Returns (extra paid)';
      await row(label, 'R${returnsNet.abs().toStringAsFixed(2)}');
    }
    await _printer.line();
    await row(
      'TOTAL EXPECTED',
      'R${totalExpected.toStringAsFixed(2)}',
      bold: true,
    );
    await _printer.line();
    await _printer.printText(
      text: 'Powered by PocketTill',
      style: SunmiTextStyle(align: SunmiPrintAlign.CENTER),
    );
    await _printer.lineWrap(times: 2);
    await _printer.cutPaper();
  }
}
