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
}
