import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/hardware/camera_scanner_service.dart';
import '../../core/hardware/scanner_service.dart';
import '../../main.dart';

/// Lazily initializes whichever [ScannerService] this device uses, exactly
/// once for the app's lifetime - [ScannerService.init] binds hardware (the
/// Sunmi service) or starts the camera stream (the phone service), and
/// isn't safe to call more than once.
final scannerInitProvider = FutureProvider<void>((ref) async {
  await ref.watch(scannerServiceProvider).init();
});

/// Full-screen barcode scanning UI, shared by the Stock search bar's scan
/// icon and AddProductScreen's "Rescan" button. Pops with the scanned
/// barcode string, or null if the user backs out.
class BarcodeScannerScreen extends ConsumerStatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  ConsumerState<BarcodeScannerScreen> createState() =>
      _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends ConsumerState<BarcodeScannerScreen> {
  @override
  void dispose() {
    // Pause the camera (if this device has one) rather than disposing the
    // service - the same ScannerService instance is reused for the next
    // scan, and its stream must stay open for that to work.
    final scanner = ref.read(scannerServiceProvider);
    if (scanner is CameraScannerService) {
      scanner.controller.stop();
    }
    super.dispose();
  }

  void _finish(String barcode) {
    if (!mounted) return;
    Navigator.of(context).pop(barcode);
  }

  @override
  Widget build(BuildContext context) {
    final scannerInit = ref.watch(scannerInitProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: scannerInit.when(
          data: (_) => _ScannerBody(onScanned: _finish),
          loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
          error: (error, stackTrace) => _ScannerError(
            message: 'Could not start the scanner: $error',
          ),
        ),
      ),
    );
  }
}

class _ScannerBody extends ConsumerStatefulWidget {
  const _ScannerBody({required this.onScanned});

  final ValueChanged<String> onScanned;

  @override
  ConsumerState<_ScannerBody> createState() => _ScannerBodyState();
}

class _ScannerBodyState extends ConsumerState<_ScannerBody> {
  bool _handled = false;
  final DateTime _mountedAt = DateTime.now();
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    // The MobileScanner widget built below starts the controller itself
    // (via its autoStart lifecycle) once it's actually attached - starting
    // it manually here, before that widget exists, throws
    // MobileScannerException(controllerNotAttached).
    final scanner = ref.read(scannerServiceProvider);
    _subscription = scanner.onBarcodeScanned.listen(_handleBarcode);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void _handleBarcode(String barcode) {
    if (_handled || barcode.isEmpty) return;
    // Ignore detections in the first moment after this screen opens: the
    // camera can still be delivering a buffered/residual decode left over
    // from a previous scan session before it's actually seen anything new,
    // which would otherwise show up as an unrelated "stale" barcode here.
    if (DateTime.now().difference(_mountedAt) < const Duration(milliseconds: 600)) {
      return;
    }
    _handled = true;
    widget.onScanned(barcode);
  }

  @override
  Widget build(BuildContext context) {
    final scanner = ref.watch(scannerServiceProvider);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (scanner is CameraScannerService)
          MobileScanner(controller: scanner.controller)
        else
          const _WaitingForHardwareScan(),
        _ScannerOverlay(onManualEntry: () => _promptManualEntry(context)),
      ],
    );
  }

  Future<void> _promptManualEntry(BuildContext context) async {
    final controller = TextEditingController();
    final barcode = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Enter Barcode Manually'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Barcode number'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Use Barcode'),
          ),
        ],
      ),
    );
    if (barcode != null && barcode.isNotEmpty) {
      _handleBarcode(barcode);
    }
  }
}

class _WaitingForHardwareScan extends StatelessWidget {
  const _WaitingForHardwareScan();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Press the scanner button on your device to scan a barcode.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay({required this.onManualEntry});

  final VoidCallback onManualEntry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const Expanded(
                child: Text(
                  'Scan Barcode',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Container(
              width: 260,
              height: 180,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blueAccent, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onManualEntry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white24,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.keyboard),
                  label: const Text('Enter Barcode Manually'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                // Give up on scanning and let the caller fall back to the
                // main search bar's name search - no barcode result.
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Search by Product Name',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ScannerError extends StatelessWidget {
  const _ScannerError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white70, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
