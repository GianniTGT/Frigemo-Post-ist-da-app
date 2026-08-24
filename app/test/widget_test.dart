// Diese Datei muss test/widget_test.dart heissen. Der Release-Workflow erzeugt
// das Android-Projekt mit `flutter create`, und das legt genau diesen Pfad mit
// einem Platzhalter an, der eine Klasse `MyApp` instanziiert -- die es hier
// nicht gibt, die App-Klasse heisst PostTerminalApp. `flutter analyze` bricht
// daran ab. Eine bereits vorhandene Datei laesst `flutter create` unberuehrt.
//
// Geprueft wird, was ohne Server und ohne Widget-Baum pruefbar ist: die
// Sprachumschaltung und die Uebersetzungstabelle. Der Bildschirm selbst haengt
// an HTTP-Aufrufen und laufenden Timern und braucht einen eigenen Testaufbau.

import 'package:flutter_test/flutter_test.dart';
import 'package:frigemo_post_terminal/l10n.dart';

void main() {
  const fr = L10n(AppLang.fr);
  const de = L10n(AppLang.de);

  group('LocaleController', () {
    test('leitet die Sprache aus dem Code ab', () {
      expect(LocaleController.fromCode('de'), AppLang.de);
      expect(LocaleController.fromCode('DE-CH'), AppLang.de);
      expect(LocaleController.fromCode('fr'), AppLang.fr);
      // Alles Unbekannte faellt auf Franzoesisch zurueck -- Standardsprache
      // des Terminals in Cressier.
      expect(LocaleController.fromCode('it'), AppLang.fr);
      expect(LocaleController.fromCode(''), AppLang.fr);
    });

    test('schaltet zwischen den beiden Sprachen um', () {
      final controller = LocaleController(AppLang.fr);
      controller.toggle();
      expect(controller.value, AppLang.de);
      controller.toggle();
      expect(controller.value, AppLang.fr);
    });
  });

  group('L10n', () {
    test('liefert die Texte in beiden Sprachen', () {
      expect(fr.t('send'), 'Envoyer la notification');
      expect(de.t('send'), 'Benachrichtigung senden');
      expect(fr.code, 'fr');
      expect(de.code, 'de');
    });

    test('setzt Platzhalter ein', () {
      final text = fr.t('success.body', args: {'name': 'Claire'});
      expect(text, contains('Claire'));
      expect(text, isNot(contains('{name}')));
    });

    test('gibt bei unbekanntem Schluessel den Schluessel zurueck', () {
      expect(fr.t('gibt.es.nicht'), 'gibt.es.nicht');
    });

    // Fehlt eine Sprache zu einem Schluessel, liefert t() den Schluessel
    // selbst -- auf dem Terminal stuende dann 'error.network' statt eines
    // Satzes. Dieser Test faengt das ab, bevor es jemand am Empfang sieht.
    test('kennt jeden Schluessel in beiden Sprachen', () {
      const keys = [
        'app.title',
        'app.subtitle',
        'lang.switch',
        'step.carrier',
        'step.recipient',
        'step.details',
        'carrier.other',
        'search.hint',
        'search.min',
        'search.none',
        'search.change',
        'quantity',
        'kind.parcel',
        'kind.pallet',
        'kind.letter',
        'kind.chilled',
        'kind.label',
        'location.label',
        'location.reception',
        'location.dock',
        'location.coldroom',
        'note.label',
        'chilled.warning',
        'send',
        'sending',
        'success.title',
        'success.body',
        'success.next',
        'error.title',
        'error.network',
        'error.timeout',
        'error.server',
        'error.auth',
        'error.mail',
        'retry',
        'close',
        'offline',
        'phone.title',
        'phone.button',
        'phone.failed',
      ];

      for (final key in keys) {
        expect(fr.t(key), isNot(key), reason: 'FR fehlt zu: $key');
        expect(de.t(key), isNot(key), reason: 'DE fehlt zu: $key');
      }
    });
  });
}
