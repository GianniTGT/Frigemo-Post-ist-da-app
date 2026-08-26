import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n.dart';

/// Vollbild-Scanner fuer den Barcode auf dem Etikett. Liefert die erste
/// erkannte Sendungsnummer zurueck und schliesst sich sofort -- der Fahrer
/// soll nicht zielen muessen, bis ein Knopf gedrueckt ist.
class ScanScreen extends StatefulWidget {
  final LocaleController locale;

  const ScanScreen({super.key, required this.locale});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  /// Die Kamera meldet denselben Code viele Male pro Sekunde -- nur der
  /// erste Treffer darf die Seite schliessen.
  bool _done = false;

  L10n get _l => L10n(widget.locale.value);

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim() ?? '';
      if (value.isEmpty) continue;
      _done = true;
      Navigator.of(context).pop(value);
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          _l.t('scan.title'),
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              child: Text(
                _l.t('scan.hint'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
