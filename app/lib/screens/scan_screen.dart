import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../l10n.dart';

/// Kuerzeste Sendungsnummer, die ein Transporteur druckt: DPD 14 Stellen,
/// GLS 11, DHL ab 10, Post CH 18. Alles darunter ist auf dem Etikett etwas
/// anderes -- die Schweizer Post setzt neben die Sendungsnummer einen
/// kleinen Strichcode mit einem vierstelligen Leitcode.
const int kMinTrackingLength = 8;

/// Waehlt aus allem, was im Bild steht, die Sendungsnummer aus.
///
/// Auf einem Etikett steht selten nur ein Code: neben der Sendungsnummer
/// liegen ein kleiner Leitcode und oft ein DataMatrix des Absenders. Der
/// erste Treffer der Kamera ist deshalb Gluecksache -- am Empfang kam so
/// ein Leitcode "2307" statt der Sendungsnummer in der Meldung an.
///
/// Zwei Regeln reichen, ohne auf einen bestimmten Transporteur zu setzen:
/// Flaechencodes (QR, DataMatrix, PDF417, Aztec) tragen Absenderdaten, nie
/// die Sendungsnummer -- die drucken alle als Strichcode. Und von den
/// Strichcodes ist die Sendungsnummer der laengste; der Leitcode faellt
/// schon an [kMinTrackingLength] durch.
///
/// Gibt null zurueck, wenn nichts Brauchbares dabei war -- dann wird
/// weitergesucht, statt eine falsche Nummer zu melden.
String? pickTrackingCode(List<Barcode> barcodes) {
  const flaechencodes = {
    BarcodeFormat.qrCode,
    BarcodeFormat.dataMatrix,
    BarcodeFormat.pdf417,
    BarcodeFormat.aztec,
  };

  String? best;
  for (final barcode in barcodes) {
    if (flaechencodes.contains(barcode.format)) continue;
    final value = barcode.rawValue?.trim() ?? '';
    if (value.length < kMinTrackingLength) continue;
    if (best == null || value.length > best.length) best = value;
  }
  return best;
}

/// Vollbild-Scanner fuer den Barcode auf dem Etikett. Liefert die erkannte
/// Sendungsnummer zurueck und schliesst sich sofort -- der Fahrer soll
/// nicht zielen muessen, bis ein Knopf gedrueckt ist.
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

  /// Die Kamera sieht etwas, aber nichts, was eine Sendungsnummer sein
  /// kann. Ohne diesen Hinweis wirkt der Scanner in dem Fall kaputt: der
  /// Fahrer haelt auf den kleinen Leitcode, und es passiert einfach nichts.
  bool _onlyOther = false;

  L10n get _l => L10n(widget.locale.value);

  void _onDetect(BarcodeCapture capture) {
    if (_done || !mounted) return;
    final code = pickTrackingCode(capture.barcodes);
    if (code == null) {
      // Nur bei der Flanke neu zeichnen -- onDetect laeuft im Kamerratakt.
      if (capture.barcodes.isNotEmpty && !_onlyOther) {
        setState(() => _onlyOther = true);
      }
      return;
    }
    _done = true;
    Navigator.of(context).pop(code);
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _l.t('scan.hint'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  if (_onlyOther) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            _l.t('scan.wrongcode'),
                            textAlign: TextAlign.center,
                            // Weiss und fett: der Akzentton der App waere
                            // auf dem dunklen Kamerabild kaum zu lesen.
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
