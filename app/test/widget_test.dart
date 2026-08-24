// Diese Datei muss test/widget_test.dart heissen. Der Release-Workflow erzeugt
// das Android-Projekt mit `flutter create`, und das legt genau diesen Pfad mit
// einem Platzhalter an, der eine Klasse `MyApp` instanziiert -- die es hier
// nicht gibt, die App-Klasse heisst PostTerminalApp. `flutter analyze` bricht
// daran ab. Eine bereits vorhandene Datei laesst `flutter create` unberuehrt.
//
// Geprueft wird alles, was ohne Widget-Baum und ohne E-Mail-App pruefbar ist:
// Personalliste, Suche, Aufbau der mailto-Adresse und die Uebersetzungen.

import 'package:flutter_test/flutter_test.dart';
import 'package:frigemo_post_terminal/api_service.dart';
import 'package:frigemo_post_terminal/config.dart';
import 'package:frigemo_post_terminal/l10n.dart';

const _csv = '''
name,email,department,lang
Hans Muster,h.muster@frigemo.ch,Technik / Unterhalt,de
Claire Dubois,c.dubois@frigemo.ch,Production,fr
"Muller, Beat",b.muller@frigemo.ch,Logistique,de
Ohne Adresse,,Production,fr
''';

DeliveryDraft _draft({
  Employee? recipient,
  String kind = 'parcel',
  String note = '',
  int quantity = 1,
}) =>
    DeliveryDraft(
      carrierLabel: 'DHL',
      recipient: recipient,
      quantity: quantity,
      kind: kind,
      location: 'reception',
      note: note,
      terminalLang: AppLang.fr,
    );

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

  group('Personalliste', () {
    final staff = employeesFromCsv(_csv);

    test('liest die gepflegte Datei', () {
      // "Ohne Adresse" faellt raus: ohne E-Mail ist der Eintrag nutzlos.
      expect(staff.length, 3);
      expect(staff.first.name, 'Hans Muster');
      expect(staff.first.email, 'h.muster@frigemo.ch');
      expect(staff.first.lang, AppLang.de);
      expect(staff[1].lang, AppLang.fr);
    });

    test('haelt ein Komma im Namen zusammen', () {
      expect(staff[2].name, 'Muller, Beat');
      expect(staff[2].department, 'Logistique');
    });
  });

  group('Suche', () {
    final staff = employeesFromCsv(_csv);

    test('findet ueber Akzente hinweg', () {
      expect(foldForSearch('Müller'), 'muller');
      expect(foldForSearch('Perret Sophie'), 'perret sophie');
      expect(searchIn(staff, 'muller').single.name, 'Muller, Beat');
    });

    test('verlangt jeden Begriff', () {
      expect(searchIn(staff, 'claire production').length, 1);
      expect(searchIn(staff, 'claire logistique'), isEmpty);
    });

    test('findet auch ueber die Abteilung', () {
      expect(searchIn(staff, 'technik').single.name, 'Hans Muster');
    });

    test('achtet die Obergrenze', () {
      expect(searchIn(staff, 'e', limit: 2).length, lessThanOrEqualTo(2));
    });
  });

  group('mailto', () {
    const person = Employee(
      id: '1',
      name: 'Hans Muster',
      email: 'h.muster@frigemo.ch',
      department: 'Technik',
      lang: AppLang.de,
    );

    test('schickt an die Person, gemeinsames Postfach in Kopie', () {
      final uri = composeMail(_draft(recipient: person));
      expect(uri.scheme, 'mailto');
      expect(uri.path, 'h.muster@frigemo.ch');
      expect(uri.queryParameters['cc'], AppConfig.mailFallback);
    });

    test('ohne Namen geht die Meldung nur ans gemeinsame Postfach', () {
      final uri = composeMail(_draft());
      expect(uri.path, AppConfig.mailFallback);
      expect(uri.queryParameters['cc'], isNull);
      expect(uri.queryParameters['body'], contains(fr.t('recipient.unknown')));
    });

    test('folgt der Sprache der Person, nicht der des Terminals', () {
      // Terminal auf Franzoesisch, Empfaenger deutschsprachig.
      final uri = composeMail(_draft(recipient: person));
      expect(uri.queryParameters['subject'], contains('Lieferung für Sie'));
      expect(uri.queryParameters['body'], contains(de.t('mail.footer')));
    });

    test('markiert Kuehlware als dringend', () {
      final normal = composeMail(_draft(recipient: person));
      final chilled = composeMail(_draft(recipient: person, kind: 'chilled'));
      expect(normal.queryParameters['subject'], isNot(startsWith('[')));
      expect(chilled.queryParameters['subject'], startsWith('[DRINGEND]'));
      expect(chilled.queryParameters['body'], contains(de.t('mail.urgentNote')));
    });

    test('nimmt Menge und Bemerkung mit', () {
      final uri = composeMail(_draft(recipient: person, quantity: 4, note: 'Palette beschädigt'));
      final body = uri.queryParameters['body']!;
      expect(body, contains('${de.t('quantity')}: 4'));
      expect(body, contains('Palette beschädigt'));
    });

    test('laesst die Bemerkungszeile weg, wenn nichts drinsteht', () {
      final body = composeMail(_draft(recipient: person)).queryParameters['body']!;
      expect(body, isNot(contains(de.t('mail.note'))));
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
        'recipient.unknown',
        'recipient.unknown.hint',
        'success.body.unknown',
        'mail.subject',
        'mail.subject.unknown',
        'mail.urgent.prefix',
        'mail.intro',
        'mail.intro.unknown',
        'mail.carrier',
        'mail.recipient',
        'mail.note',
        'mail.time',
        'mail.urgentNote',
        'mail.footer',
        'phone.failed',
      ];

      for (final key in keys) {
        expect(fr.t(key), isNot(key), reason: 'FR fehlt zu: $key');
        expect(de.t(key), isNot(key), reason: 'DE fehlt zu: $key');
      }
    });
  });
}
