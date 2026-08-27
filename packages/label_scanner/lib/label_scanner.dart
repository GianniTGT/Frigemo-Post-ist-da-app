// Den richtigen Code von einem Etikett scannen.
//
// Haengt nur an flutter und mobile_scanner. Sprache, Farben und die Regel,
// was als gueltiger Code zaehlt, kommen von aussen.
//
//   final code = await LabelScannerScreen.open(context);                 // Paket
//   final vin  = await LabelScannerScreen.open(context, rule: LabelCodeRule.vin);
//
// Erprobt an Paketetiketten (Post CH, DPD, FedEx) und an
// Fahrzeug-Etiketten mit VIN.

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// ---------------------------------------------------------------------------
// Die Regel: was zaehlt als der gesuchte Code
// ---------------------------------------------------------------------------

/// Flaechencodes. Sie tragen auf Etiketten meist Absender-, Routing- oder
/// Herstellerdaten -- ganze Datensaetze, keine einzelne Nummer.
const Set<BarcodeFormat> kAreaFormats = {
  BarcodeFormat.qrCode,
  BarcodeFormat.dataMatrix,
  BarcodeFormat.pdf417,
  BarcodeFormat.aztec,
};

/// Beschreibt, welcher Code auf dem Etikett gemeint ist.
///
/// Der Kniff steckt im Verhaeltnis von [accept] zu [areaFormats]: eine Regel
/// mit Pruefung kann es sich leisten, ueberall zu suchen, weil ein falscher
/// Fund ohnehin durchfaellt. Eine Regel ohne Pruefung muss vorsichtig sein
/// und sich auf Strichcodes beschraenken.
class LabelCodeRule {
  const LabelCodeRule({
    this.minLength = 8,
    this.accept,
    this.areaFormats = false,
  });

  /// Kuerzester Code, der noch in Frage kommt. Alles darunter ist auf dem
  /// Etikett etwas anderes.
  final int minLength;

  /// Zusaetzliche Pruefung. Gibt sie false zurueck, gilt der Code als nicht
  /// gemeint -- unabhaengig von seiner Laenge.
  final bool Function(String value)? accept;

  /// Duerfen auch QR, DataMatrix, PDF417 und Aztec gewinnen?
  ///
  /// Nur sinnvoll zusammen mit [accept]. Ohne Pruefung wuerde sonst ein
  /// Herstellerdatensatz aus dem QR-Code gewinnen, bloss weil er laenger ist.
  final bool areaFormats;

  /// Paketetikett: Sendungsnummer eines Transporteurs.
  ///
  /// Acht Zeichen lassen DHL (ab 10 Stellen), GLS (11), DPD (14), UPS und
  /// Post CH (18) durch. Der vierstellige Leitcode, den die Post neben die
  /// Sendungsnummer druckt, faellt an der Grenze durch.
  ///
  /// Keine Pruefung moeglich -- jeder Transporteur nummeriert anders --,
  /// deshalb bleiben Flaechencodes hier aussen vor.
  static const LabelCodeRule parcel = LabelCodeRule();

  /// Fahrzeug-Etikett: Fahrgestellnummer (VIN, ISO 3779).
  ///
  /// Anders als eine Sendungsnummer kann sich eine VIN selbst beweisen: 17
  /// Zeichen, ein festes Alphabet ohne I, O und Q, und eine Pruefziffer an
  /// Stelle 9. Ein verlesenes Zeichen faellt damit auf.
  ///
  /// Weil [isValidVin] jeden Fund prueft, duerfen hier auch Flaechencodes
  /// gewinnen: Etiketten tragen die VIN oft im QR-Code, und ein QR mit
  /// anderem Inhalt scheitert an der Pruefziffer.
  static const LabelCodeRule vin = LabelCodeRule(
    minLength: 17,
    accept: isValidVin,
    areaFormats: true,
  );
}

/// Waehlt aus allem, was im Bild steht, den gesuchten Code aus.
///
/// Das ist der Kern. Auf einem Etikett steht selten nur ein Code: neben der
/// Nummer liegen ein Leitcode, ein QR des Absenders, manchmal ein
/// Herstellerdatensatz. Wer einfach den ersten Treffer der Kamera nimmt,
/// bekommt Gluecksache -- am Empfang kam so ein vierstelliges "2307" statt
/// der achtzehnstelligen Sendungsnummer in der Meldung an, und niemand
/// merkte es, weil "2307" wie eine Nummer aussieht.
///
/// Der teure Fehler ist nicht der Absturz, sondern das plausible falsche
/// Ergebnis. Deshalb wird ausgewaehlt statt gegriffen, und deshalb gibt
/// diese Funktion null zurueck, wenn nichts passt: dann wird weitergesucht,
/// statt das Naechstbeste zu melden.
String? pickBestCode(
  List<Barcode> barcodes, {
  LabelCodeRule rule = LabelCodeRule.parcel,
}) {
  String? best;
  for (final barcode in barcodes) {
    if (!rule.areaFormats && kAreaFormats.contains(barcode.format)) continue;
    final value = barcode.rawValue?.trim() ?? '';
    if (value.length < rule.minLength) continue;
    if (rule.accept != null && !rule.accept!(value)) continue;
    // Der laengste gewinnt: die gesuchte Nummer ist auf dem Etikett
    // praktisch immer laenger als das Beiwerk daneben.
    if (best == null || value.length > best.length) best = value;
  }
  return best;
}

// ---------------------------------------------------------------------------
// VIN
// ---------------------------------------------------------------------------

/// Zahlenwerte der Buchstaben fuer die Pruefziffer (ISO 3779).
/// I, O und Q fehlen absichtlich: sie sind in einer VIN nicht zugelassen,
/// weil sie sich mit 1 und 0 verwechseln lassen.
const Map<String, int> _vinValues = {
  '0': 0, '1': 1, '2': 2, '3': 3, '4': 4,
  '5': 5, '6': 6, '7': 7, '8': 8, '9': 9,
  'A': 1, 'B': 2, 'C': 3, 'D': 4, 'E': 5, 'F': 6, 'G': 7, 'H': 8,
  'J': 1, 'K': 2, 'L': 3, 'M': 4, 'N': 5, 'P': 7, 'R': 9,
  'S': 2, 'T': 3, 'U': 4, 'V': 5, 'W': 6, 'X': 7, 'Y': 8, 'Z': 9,
};

/// Gewichte der 17 Stellen. Stelle 9 traegt 0 -- sie ist die Pruefziffer
/// selbst und darf sich nicht mitrechnen.
const List<int> _vinWeights = [8, 7, 6, 5, 4, 3, 2, 10, 0, 9, 8, 7, 6, 5, 4, 3, 2];

/// Prueft eine Fahrgestellnummer nach ISO 3779.
///
/// Laenge, Alphabet und Pruefziffer an Stelle 9. Ein einzelnes verlesenes
/// Zeichen -- S statt 5, 1 statt 7 -- faellt damit auf, statt als plausible
/// Nummer weiterzuwandern.
///
/// Hinweis fuer den Feldeinsatz: Fahrzeuge aus Europa und Asien fuehren die
/// Pruefziffer nicht immer korrekt, in Nordamerika ist sie Pflicht. Wenn
/// eure Etiketten durchfallen, obwohl die Nummer stimmt, nehmt eine eigene
/// Regel mit [isVinShaped] statt dieser hier.
bool isValidVin(String value) {
  if (!isVinShaped(value)) return false;
  final vin = value.toUpperCase();
  var sum = 0;
  for (var i = 0; i < 17; i++) {
    sum += _vinValues[vin[i]]! * _vinWeights[i];
  }
  final rest = sum % 11;
  final expected = rest == 10 ? 'X' : '$rest';
  return vin[8] == expected;
}

/// Prueft nur Laenge und Alphabet einer VIN, ohne die Pruefziffer.
///
/// Fuer Bestaende, in denen die Pruefziffer nicht verlaesslich gefuehrt
/// wird. Faengt Verleser deutlich schlechter als [isValidVin], ist aber
/// immer noch besser als gar keine Pruefung.
bool isVinShaped(String value) {
  final vin = value.toUpperCase();
  if (vin.length != 17) return false;
  for (var i = 0; i < 17; i++) {
    if (!_vinValues.containsKey(vin[i])) return false;
  }
  return true;
}

// ---------------------------------------------------------------------------
// Bildschirm
// ---------------------------------------------------------------------------

/// Die Texte des Scanners. Ohne eigene Uebersetzungsschicht, damit der
/// Baustein in jedes Projekt passt -- reich die Strings aus deiner eigenen
/// l10n herein.
class LabelScannerTexts {
  const LabelScannerTexts({
    this.title = 'Barcode scannen',
    this.hint = 'Barcode vor die Kamera halten.',
    this.wrongCode = 'Das ist nicht der gesuchte Code – auf den grossen Barcode halten.',
    this.cameraError = 'Kamera nicht verfügbar – ohne Scan weiterfahren.',
    this.permissionDenied =
        'Der Kamera-Zugriff ist blockiert. In den Android-Einstellungen dieser App die Kamera erlauben.',
  });

  /// Ueberschrift der Seite.
  final String title;

  /// Steht dauerhaft unten: was der Bediener tun soll.
  final String hint;

  /// Erscheint, sobald die Kamera nur Codes sieht, die nicht der gesuchte
  /// sein koennen. Ohne diesen Satz wirkt der Scanner kaputt: er zeigt das
  /// Bild, und es passiert einfach nichts.
  final String wrongCode;

  /// Kamera liess sich nicht oeffnen.
  final String cameraError;

  /// Berechtigung fehlt -- mit dem Weg dorthin, sonst hilft der Satz nicht.
  final String permissionDenied;
}

/// Vollbild-Scanner. Liefert den erkannten Code zurueck und schliesst sich
/// sofort -- der Bediener soll nicht zielen muessen, bis er einen Knopf
/// drueckt. Abbrechen gibt null zurueck und laesst alles beim Alten.
class LabelScannerScreen extends StatefulWidget {
  const LabelScannerScreen({
    super.key,
    this.rule = LabelCodeRule.parcel,
    this.texts = const LabelScannerTexts(),
  });

  final LabelCodeRule rule;
  final LabelScannerTexts texts;

  /// Oeffnet den Scanner und gibt den Code zurueck, oder null bei Abbruch.
  static Future<String?> open(
    BuildContext context, {
    LabelCodeRule rule = LabelCodeRule.parcel,
    LabelScannerTexts texts = const LabelScannerTexts(),
  }) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => LabelScannerScreen(rule: rule, texts: texts),
      ),
    );
  }

  @override
  State<LabelScannerScreen> createState() => _LabelScannerScreenState();
}

class _LabelScannerScreenState extends State<LabelScannerScreen> {
  /// Die Kamera meldet denselben Code viele Male pro Sekunde -- nur der
  /// erste Treffer darf die Seite schliessen.
  bool _done = false;

  /// Die Kamera sieht etwas, aber nichts, was der gesuchte Code sein kann.
  bool _onlyOther = false;

  void _onDetect(BarcodeCapture capture) {
    if (_done || !mounted) return;
    final code = pickBestCode(capture.barcodes, rule: widget.rule);
    if (code == null) {
      // Nur bei der Flanke neu zeichnen -- onDetect laeuft im Kameratakt.
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
          widget.texts.title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      body: Stack(
        children: [
          MobileScanner(onDetect: _onDetect, errorBuilder: _buildError),
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
                    widget.texts.hint,
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
                            widget.texts.wrongCode,
                            textAlign: TextAlign.center,
                            // Weiss und fett. Ein Akzentton der App waere auf
                            // dem dunklen Kamerabild kaum zu lesen.
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

  /// Der eingebaute Fehlerbildschirm von mobile_scanner zeigt im Release
  /// grundsaetzlich nur "An unexpected error occurred" -- den wirklichen
  /// Grund druckt er ausschliesslich unter kDebugMode. Damit laesst sich vor
  /// Ort nichts beheben.
  ///
  /// Dieser hier nennt den Grund im Klartext und darunter klein den
  /// technischen Pfad. Genau diese Zeile hat den R8-Fehler gefunden, der im
  /// README beschrieben ist. Lass sie drin.
  Widget _buildError(
    BuildContext context,
    MobileScannerException error,
    Widget? child,
  ) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
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
              denied ? widget.texts.permissionDenied : widget.texts.cameraError,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 19),
            ),
            const SizedBox(height: 12),
            Text(
              [
                error.errorCode.name,
                if (error.errorDetails?.code != null) error.errorDetails!.code!,
                if (error.errorDetails?.message != null)
                  error.errorDetails!.message!,
              ].join(' · '),
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
