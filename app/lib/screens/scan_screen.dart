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
          MobileScanner(
            onDetect: _onDetect,
            // Der eingebaute Fehlerbildschirm zeigt im Release immer nur
            // "An unexpected error occurred" -- ohne den wirklichen Grund
            // laesst sich am Empfang nichts beheben.
            errorBuilder: (context, error, child) {
              final denied =
                  error.errorCode == MobileScannerErrorCode.permissionDenied;
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        denied ? Icons.no_photography : Icons.error_outline,
                        color: Colors.white,
                        size: 56,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _l.t(denied ? 'scan.permission' : 'scan.error'),
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 19),
                      ),
                      const SizedBox(height: 12),
                      // Fuer die Fehlersuche: Code plus die genauere Meldung
                      // der Plattform -- 'genericError' allein sagt nicht,
                      // welcher der vielen Pfade gescheitert ist.
                      Text(
                        [
                          error.errorCode.name,
                          if (error.errorDetails?.code != null)
                            error.errorDetails!.code!,
                          if (error.errorDetails?.message != null)
                            error.errorDetails!.message!,
                        ].join(' · '),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
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
