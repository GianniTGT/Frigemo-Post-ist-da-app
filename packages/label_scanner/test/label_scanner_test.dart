// Die Werte stammen von echten Etiketten: Post CH, eine Digitec-Retoure
// und das Fahrzeug-Etikett eines 2019 Buick Encore.
//
// Geprueft wird nur die Auswahl -- reine Funktionen, keine Kamera, kein
// Widget. Genau deshalb ist sie aus dem Bildschirm herausgeloest: der Teil,
// der schiefgehen kann, laesst sich ohne Geraet pruefen.

import 'package:flutter_test/flutter_test.dart';
import 'package:label_scanner/label_scanner.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  Barcode strich(String value) =>
      Barcode(rawValue: value, format: BarcodeFormat.code128);
  Barcode qr(String value) =>
      Barcode(rawValue: value, format: BarcodeFormat.qrCode);
  Barcode matrix(String value) =>
      Barcode(rawValue: value, format: BarcodeFormat.dataMatrix);

  const vin = 'KL4CJESB8KB924970';

  group('Paketetikett', () {
    test('nimmt die Sendungsnummer, nicht den kleinen Leitcode', () {
      // Der Fehler aus dem Betrieb: gemeldet wurde '2307'.
      expect(
        pickBestCode([strich('2307'), strich('996013148238551546')]),
        '996013148238551546',
      );
    });

    test('die Reihenfolge der Kamera spielt keine Rolle', () {
      expect(
        pickBestCode([strich('996002680700338482'), strich('0509')]),
        '996002680700338482',
      );
    });

    test('ein DataMatrix des Absenders gewinnt nie', () {
      expect(
        pickBestCode([
          matrix('AT199851133-4501443337-Returns-Dintikon'),
          strich('996013148238551546'),
        ]),
        '996013148238551546',
      );
    });

    test('nur Leitcode im Bild: lieber nichts als das Falsche', () {
      expect(pickBestCode([strich('2307')]), isNull);
      expect(pickBestCode([]), isNull);
    });

    test('leerer und fehlender Inhalt fallen durch', () {
      expect(pickBestCode([strich('   '), const Barcode()]), isNull);
    });

    test('Leerraum wird abgeschnitten', () {
      expect(
        pickBestCode([strich('  996013148238551546  ')]),
        '996013148238551546',
      );
    });

    test('kurze Nummern anderer Transporteure gehen durch', () {
      // GLS 11 Stellen, DHL ab 10 -- die Grenze darf sie nicht wegwerfen.
      expect(pickBestCode([strich('12345678901')]), '12345678901');
    });
  });

  group('Fahrzeug-Etikett', () {
    test('nimmt die VIN vom Strichcode', () {
      expect(
        pickBestCode([strich(vin)], rule: LabelCodeRule.vin),
        vin,
      );
    });

    test('nimmt die VIN auch aus dem QR-Code', () {
      // Das Etikett traegt beides. Weil die Pruefziffer jeden Fund
      // kontrolliert, duerfen hier auch Flaechencodes gewinnen.
      expect(
        pickBestCode([qr(vin)], rule: LabelCodeRule.vin),
        vin,
      );
    });

    test('ein QR mit Haendlerdaten gewinnt nicht gegen die VIN', () {
      expect(
        pickBestCode([
          qr('{"dealer":"Downtown Auto Sales LLC","model":"2019 Buick Encore"}'),
          strich(vin),
        ], rule: LabelCodeRule.vin),
        vin,
      );
    });

    test('ohne gueltige VIN im Bild kommt nichts zurueck', () {
      expect(
        pickBestCode([
          qr('{"dealer":"Downtown Auto Sales LLC"}'),
          strich('2019 BUICK ENCORE'),
        ], rule: LabelCodeRule.vin),
        isNull,
      );
    });

    test('die Paket-Regel wuerde hier den Haendlertext nehmen', () {
      // Zeigt, warum die Regel zum Etikett passen muss: ohne Pruefung
      // gewinnt schlicht der laengste Strichcode -- hier der Fliesstext
      // mit 21 Zeichen gegen die VIN mit 17.
      expect(
        pickBestCode([strich('2019 BUICK ENCORE LLC'), strich(vin)]),
        '2019 BUICK ENCORE LLC',
      );
      // Mit der richtigen Regel gewinnt die VIN.
      expect(
        pickBestCode(
          [strich('2019 BUICK ENCORE LLC'), strich(vin)],
          rule: LabelCodeRule.vin,
        ),
        vin,
      );
    });
  });

  group('VIN pruefen', () {
    test('erkennt die echte Nummer vom Etikett', () {
      expect(isValidVin(vin), isTrue);
      expect(isValidVin(vin.toLowerCase()), isTrue);
    });

    test('ein verlesenes Zeichen faellt auf', () {
      // S statt 5 und 7 statt 8 -- die haeufigen Verwechslungen.
      expect(isValidVin('KL4CJE5B8KB924970'), isFalse);
      expect(isValidVin('KL4CJESB8KB924870'), isFalse);
      expect(isValidVin('KL4CJESB8KB924971'), isFalse);
    });

    test('falsche Laenge faellt durch', () {
      expect(isValidVin('KL4CJESB8KB92497'), isFalse);
      expect(isValidVin('KL4CJESB8KB9249700'), isFalse);
      expect(isValidVin(''), isFalse);
    });

    test('I, O und Q sind in einer VIN nicht zugelassen', () {
      expect(isVinShaped('KL4CJESB8KB92497O'), isFalse);
      expect(isVinShaped('KL4CJESB8KB92497I'), isFalse);
      expect(isVinShaped('KL4CJESB8KB92497Q'), isFalse);
    });

    test('isVinShaped prueft Form, aber nicht die Pruefziffer', () {
      expect(isVinShaped('KL4CJESB8KB924970'), isTrue);
      // Falsche Pruefziffer, richtige Form.
      expect(isVinShaped('KL4CJESB1KB924970'), isTrue);
      expect(isValidVin('KL4CJESB1KB924970'), isFalse);
    });

    test('X als Pruefziffer wird akzeptiert', () {
      // Rest 10 wird als X geschrieben. 1M8GDM9AXKP042788 ist die
      // Beispielnummer aus der Norm.
      expect(isValidVin('1M8GDM9AXKP042788'), isTrue);
    });
  });
}
