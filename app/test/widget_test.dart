// Diese Datei muss test/widget_test.dart heissen. Der Release-Workflow erzeugt
// das Android-Projekt mit `flutter create`, und das legt genau diesen Pfad mit
// einem Platzhalter an, der eine Klasse `MyApp` instanziiert -- die es hier
// nicht gibt, die App-Klasse heisst PostTerminalApp. `flutter analyze` bricht
// daran ab. Eine bereits vorhandene Datei laesst `flutter create` unberuehrt.
//
// Geprueft wird alles, was ohne Widget-Baum und ohne E-Mail-App pruefbar ist:
// Personalliste, Suche, Aufbau der mailto-Adresse und die Uebersetzungen.

import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frigemo_post_terminal/api_service.dart';
import 'package:frigemo_post_terminal/l10n.dart';
import 'package:frigemo_post_terminal/mail_update.dart';
import 'package:frigemo_post_terminal/screens/scan_screen.dart';
import 'package:frigemo_post_terminal/settings.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

const _csv = '''
name,email,department,lang
Hans Muster,h.muster@frigemo.ch,Technik / Unterhalt,de
Claire Dubois,c.dubois@frigemo.ch,Production,fr
"Muller, Beat",b.muller@frigemo.ch,Logistique,de
Ohne Adresse,,Production,fr
''';

DeliveryDraft _draft({
  Employee? recipient,
  String? recipientName,
  bool urgent = false,
  String kindLabel = 'Colis',
  String? locationLabel,
  String note = '',
  String trackingCode = '',
  String terminalName = '',
  int quantity = 1,
}) =>
    DeliveryDraft(
      carrierLabel: 'DHL',
      recipient: recipient,
      recipientName: recipientName,
      quantity: quantity,
      kindLabel: kindLabel,
      locationLabel: locationLabel,
      urgent: urgent,
      note: note,
      trackingCode: trackingCode,
      terminalName: terminalName,
      terminalLang: AppLang.fr,
    );

void main() {
  const fr = L10n(AppLang.fr);
  const de = L10n(AppLang.de);
  const en = L10n(AppLang.en);

  group('LocaleController', () {
    test('leitet die Sprache aus dem Code ab', () {
      expect(LocaleController.fromCode('de'), AppLang.de);
      expect(LocaleController.fromCode('DE-CH'), AppLang.de);
      expect(LocaleController.fromCode('fr'), AppLang.fr);
      expect(LocaleController.fromCode('en'), AppLang.en);
      expect(LocaleController.fromCode('EN-GB'), AppLang.en);
      // Alles Unbekannte faellt auf Franzoesisch zurueck -- Standardsprache
      // des Terminals in Cressier.
      expect(LocaleController.fromCode('it'), AppLang.fr);
      expect(LocaleController.fromCode(''), AppLang.fr);
    });

    test('schaltet der Reihe nach durch alle Sprachen', () {
      final controller = LocaleController(AppLang.fr);
      controller.toggle();
      expect(controller.value, AppLang.de);
      controller.toggle();
      expect(controller.value, AppLang.en);
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

  group('Meldungstext', () {
    const shared = 'paket@frigemo.ch';
    const person = Employee(
      id: '1',
      name: 'Hans Muster',
      email: 'h.muster@frigemo.ch',
      department: 'Technik',
      lang: AppLang.de,
    );

    test('geht an die Person, gemeinsames Postfach in Kopie', () {
      final mail = composeDelivery(_draft(recipient: person),
          sharedMailbox: shared);
      expect(mail.to, ['h.muster@frigemo.ch']);
      expect(mail.cc, [shared]);
    });

    test('ohne Namen geht die Meldung nur ans gemeinsame Postfach', () {
      final mail = composeDelivery(_draft(), sharedMailbox: shared);
      expect(mail.to, [shared]);
      expect(mail.cc, isEmpty);
      expect(mail.body, contains(fr.t('recipient.unknown')));
    });

    test('ohne gemeinsames Postfach bleibt die Kopie weg', () {
      final mail = composeDelivery(_draft(recipient: person));
      expect(mail.to, ['h.muster@frigemo.ch']);
      expect(mail.cc, isEmpty);
    });

    test('ohne Postfach und ohne Namen gibt es keine Adresse', () {
      expect(() => composeDelivery(_draft()), throwsA(isA<ApiException>()));
    });

    // Steht der Name auf dem Paket, aber die Person nicht in der Liste,
    // waere es Verschwendung, den Namen wegzuwerfen.
    test('nimmt einen Namen mit, den die Liste nicht kennt', () {
      final mail = composeDelivery(
        _draft(recipientName: 'Beat Käser'),
        sharedMailbox: shared,
      );
      expect(mail.to, [shared]);
      expect(mail.subject, contains('Beat Käser'));
      expect(mail.body, contains('Beat Käser'));
      // Nicht als "unbekannt" melden -- der Name ist ja bekannt.
      expect(mail.body, isNot(contains(fr.t('recipient.unknown'))));
    });

    test('sagt dazu, dass die Person nicht in der Liste steht', () {
      final mail = composeDelivery(
        _draft(recipientName: 'Beat Käser'),
        sharedMailbox: shared,
      );
      expect(mail.body, contains(fr.t('mail.intro.name', args: {'name': 'Beat Käser'})));
    });

    test('die Person aus der Liste geht dem getippten Namen vor', () {
      final mail = composeDelivery(
        _draft(recipient: person, recipientName: 'Tippfehler'),
        sharedMailbox: shared,
      );
      expect(mail.to, ['h.muster@frigemo.ch']);
      expect(mail.body, isNot(contains('Tippfehler')));
    });

    test('folgt der Sprache der Person, nicht der des Terminals', () {
      // Terminal auf Franzoesisch, Empfaenger deutschsprachig.
      final mail = composeDelivery(_draft(recipient: person),
          sharedMailbox: shared);
      expect(mail.subject, contains('Lieferung für Sie'));
      expect(mail.body, contains(de.t('mail.footer')));
    });

    test('markiert Kuehlware als dringend', () {
      final normal = composeDelivery(_draft(recipient: person));
      final chilled = composeDelivery(
        _draft(recipient: person, urgent: true, kindLabel: 'Kühlware'),
      );
      expect(normal.subject, isNot(startsWith('[')));
      expect(chilled.subject, startsWith('[DRINGEND]'));
      expect(chilled.body, contains(de.t('mail.urgentNote')));
    });

    test('nimmt die firmeninterne Bezeichnung mit', () {
      final mail = composeDelivery(
        _draft(recipient: person, kindLabel: 'Palette Kühlraum 3'),
      );
      expect(mail.body, contains('Palette Kühlraum 3'));
    });

    // Der Fahrer wird nicht nach dem Abholort gefragt -- dann darf auch
    // keine Zeile dazu in der Meldung stehen.
    test('laesst den Abholort weg, wenn er nicht gefragt wird', () {
      final ohne = composeDelivery(_draft(recipient: person));
      expect(ohne.body, isNot(contains(de.t('location.label'))));

      final mit = composeDelivery(
        _draft(recipient: person, locationLabel: 'Kühlraum'),
      );
      expect(mit.body, contains('Kühlraum'));
    });

    test('nimmt Menge und Bemerkung mit', () {
      final mail = composeDelivery(
        _draft(recipient: person, quantity: 4, note: 'Palette beschädigt'),
      );
      expect(mail.body, contains('${de.t('quantity')}: 4'));
      expect(mail.body, contains('Palette beschädigt'));
    });

    test('laesst die Bemerkungszeile weg, wenn nichts drinsteht', () {
      final mail = composeDelivery(_draft(recipient: person));
      expect(mail.body, isNot(contains(de.t('mail.note'))));
    });

    // Die Sendungsnummer kommt von der Kamera, nicht von Hand -- gescannt
    // steht sie in der Meldung, ohne Scan fehlt auch die Zeile.
    test('nimmt die gescannte Sendungsnummer mit', () {
      final mail = composeDelivery(
        _draft(recipient: person, trackingCode: '99.60.131482.38551546'),
      );
      expect(mail.body, contains('99.60.131482.38551546'));
      expect(mail.body, contains(de.t('tracking.label')));
    });

    test('laesst die Sendungsnummer weg, wenn nicht gescannt wurde', () {
      final mail = composeDelivery(_draft(recipient: person));
      expect(mail.body, isNot(contains(de.t('tracking.label'))));
    });

    // Mehrere Terminals im selben Werk: der Name sagt, wo die Sendung
    // abgegeben wurde. Ohne gesetzten Namen fehlt auch die Zeile.
    test('nennt das Terminal, wenn ein Name gesetzt ist', () {
      final mail = composeDelivery(_draft(recipient: person, terminalName: 'F11'));
      expect(mail.body, contains('${de.t('mail.terminal')}: F11'));

      final ohne = composeDelivery(_draft(recipient: person));
      expect(ohne.body, isNot(contains('${de.t('mail.terminal')}:')));
    });

    test('meldet einen englischsprachigen Empfaenger auf Englisch', () {
      const english = Employee(
        id: '9',
        name: 'John Carter',
        email: 'j.carter@frigemo.ch',
        department: 'Logistics',
        lang: AppLang.en,
      );
      final mail = composeDelivery(_draft(recipient: english));
      expect(mail.subject, contains('Delivery for you'));
      expect(mail.body, contains(en.t('mail.footer')));
    });
  });

  group('Anmeldefehler', () {
    // Beim Einrichten ist "Benutzer oder Passwort falsch" der haeufigste
    // Fall. Er verdient eine Meldung, mit der man etwas anfangen kann.
    test('erkennt die Antworten des Mailservers', () {
      expect(isAuthFailure('Authentication Failed (code: 535)'), isTrue);
      expect(isAuthFailure('< 5.7.8 Error: authentication failed'), isTrue);
      expect(isAuthFailure('authentication failure'), isTrue);
    });

    test('haelt andere Stoerungen auseinander', () {
      expect(isAuthFailure('Failed host lookup: smtp.example.com'), isFalse);
      expect(isAuthFailure('Connection timed out'), isFalse);
      expect(isAuthFailure('550 mailbox unavailable'), isFalse);
    });
  });

  group('Einstellungen', () {
    test('blendet den eingeschriebenen Brief zunaechst aus', () {
      final settings = TerminalSettings();
      expect(settings.kinds.map((e) => e.id), contains('letter'));
      expect(settings.visibleKinds.map((e) => e.id), isNot(contains('letter')));
      // Ausgeblendet, nicht geloescht: ohne neues APK zurueckholbar.
      expect(settings.kinds.length, kDefaultKinds.length);
    });

    test('markiert Kuehlware als dringend', () {
      final settings = TerminalSettings();
      expect(settings.kindById('chilled')?.urgent, isTrue);
      expect(settings.kindById('parcel')?.urgent, isFalse);
    });

    test('firmeninterne Bezeichnung geht vor der Uebersetzung', () {
      final settings = TerminalSettings();
      final entry = settings.kinds.firstWhere((e) => e.id == 'pallet');
      expect(settings.labelOf(entry, fr, 'kind'), 'Palette');

      settings.updateKind('pallet', (e) => e.copyWith(customLabel: 'Euro-Palette'));
      final renamed = settings.kinds.firstWhere((e) => e.id == 'pallet');
      expect(settings.labelOf(renamed, fr, 'kind'), 'Euro-Palette');
      expect(settings.labelOf(renamed, de, 'kind'), 'Euro-Palette');
    });

    test('nimmt eigene Eintraege auf und wieder heraus', () {
      final settings = TerminalSettings();
      final id = settings.addLocation('Rampe Nord');
      final added = settings.locations.firstWhere((e) => e.id == id);
      expect(added.isBuiltIn, isFalse);
      expect(settings.labelOf(added, fr, 'location'), 'Rampe Nord');

      settings.remove(id);
      expect(settings.locations.any((e) => e.id == id), isFalse);
    });

    test('loescht eingebaute Eintraege nicht', () {
      final settings = TerminalSettings();
      settings.remove('parcel');
      expect(settings.kinds.any((e) => e.id == 'parcel'), isTrue);
    });

    test('uebersteht Speichern und Laden', () {
      final settings = TerminalSettings();
      settings.addKind('Tiefkühl intern', urgent: true);
      settings.updateKind('letter', (e) => e.copyWith(visible: true));
      settings.setSharedMailbox('paket@frigemo.ch');

      final restored = TerminalSettings.fromJson(settings.toJson());
      expect(restored.visibleKinds.map((e) => e.id), contains('letter'));
      expect(restored.sharedMailbox, 'paket@frigemo.ch');
      expect(restored.kinds.last.customLabel, 'Tiefkühl intern');
      expect(restored.kinds.last.urgent, isTrue);
    });

    test('hat ohne Vorgabe keinen Code', () {
      // 1234 stand im Quelltext und damit im oeffentlichen Repository.
      // Ohne gesetzten Code verlangt die Verwaltung, zuerst einen zu
      // vergeben.
      final settings = TerminalSettings();
      expect(settings.pin, isEmpty);
      expect(settings.hasPin, isFalse);
    });

    test('uebernimmt einen im Build hinterlegten Code', () {
      final settings = TerminalSettings(pin: '8462');
      expect(settings.hasPin, isTrue);
    });

    test('erkennt zu kurze Codes', () {
      final settings = TerminalSettings();
      settings.setPin('12');
      expect(settings.hasPin, isFalse);
      settings.setPin('8462');
      expect(settings.hasPin, isTrue);
    });

    test('vergisst den Code beim Zuruecksetzen', () {
      final settings = TerminalSettings(pin: '8462');
      settings.resetToDefaults();
      // Danach wird beim naechsten Zugriff ein neuer verlangt.
      expect(settings.hasPin, isFalse);
    });

    test('nutzt ohne Import die mitgelieferte Liste', () {
      final settings = TerminalSettings();
      expect(settings.staffCsv, isNull);
      expect(settings.hasOwnStaffList, isFalse);
    });

    test('merkt sich eine eingelesene Liste', () {
      final settings = TerminalSettings();
      settings.setStaffCsv(_csv);
      expect(settings.hasOwnStaffList, isTrue);

      final restored = TerminalSettings.fromJson(settings.toJson());
      expect(restored.hasOwnStaffList, isTrue);
      expect(employeesFromCsv(restored.staffCsv!).length, 3);
    });

    test('kehrt zur mitgelieferten Liste zurueck', () {
      final settings = TerminalSettings();
      settings.setStaffCsv(_csv);
      settings.setStaffCsv(null);
      expect(settings.hasOwnStaffList, isFalse);

      // Auch eine leere Datei zaehlt nicht als eigene Liste.
      settings.setStaffCsv('   ');
      expect(settings.hasOwnStaffList, isFalse);
    });

    test('merkt sich den Terminal-Namen und behaelt ihn beim Zuruecksetzen', () {
      final settings = TerminalSettings();
      expect(settings.hasTerminalName, isFalse);

      settings.setTerminalName('  F11  ');
      expect(settings.terminalName, 'F11');

      final restored = TerminalSettings.fromJson(settings.toJson());
      expect(restored.terminalName, 'F11');

      // Wie der Versandzugang: die Identitaet des Geraets uebersteht ein
      // Zuruecksetzen der Auswahl.
      settings.resetToDefaults();
      expect(settings.terminalName, 'F11');
    });

    test('fragt den Abholort standardmaessig nicht', () {
      // Der Fahrer kann nicht wissen, wohin die Sendung im Werk gehoert.
      expect(TerminalSettings().askLocation, isFalse);
    });

    test('haelt den Versandzugang fuer unvollstaendig, solange etwas fehlt', () {
      expect(const SmtpConfig().isComplete, isFalse);
      expect(const SmtpConfig(host: 'smtp.frigemo.ch').isComplete, isFalse);
      expect(
        const SmtpConfig(
          host: 'smtp.frigemo.ch',
          fromAddress: 'empfang@frigemo.ch',
        ).isComplete,
        isTrue,
      );
    });

    test('bewahrt den Versandzugang beim Zuruecksetzen', () {
      final settings = TerminalSettings();
      settings.updateSmtp((s) => s.copyWith(
            host: 'smtp.frigemo.ch',
            fromAddress: 'empfang@frigemo.ch',
          ));
      settings.setAskLocation(true);

      settings.resetToDefaults();

      // Auswahl zurueck, Zugang bleibt -- sonst stuende das Terminal stumm.
      expect(settings.askLocation, isFalse);
      expect(settings.smtp.host, 'smtp.frigemo.ch');
      expect(settings.smtp.isComplete, isTrue);
    });

    test('uebersteht Speichern und Laden des Versandzugangs', () {
      final settings = TerminalSettings();
      settings.updateSmtp((s) => s.copyWith(
            host: 'smtp.frigemo.ch',
            port: 465,
            ssl: true,
            user: 'empfang',
            password: 'geheim',
            fromAddress: 'empfang@frigemo.ch',
          ));

      final restored = TerminalSettings.fromJson(settings.toJson());
      expect(restored.smtp.host, 'smtp.frigemo.ch');
      expect(restored.smtp.port, 465);
      expect(restored.smtp.ssl, isTrue);
      expect(restored.smtp.password, 'geheim');
    });

    test('faellt bei beschaedigten Daten auf die Standardwerte zurueck', () {
      final restored = TerminalSettings.fromJson({'kinds': 'kaputt'});
      expect(restored.kinds.length, kDefaultKinds.length);
      expect(restored.hasSharedMailbox, isFalse);
    });
  });

  group('Listen-Update per E-Mail', () {
    test('beachtet nur Betreffe mit dem Geheimcode', () {
      expect(subjectMatchesCode('LISTE geheim123', 'geheim123'), isTrue);
      expect(subjectMatchesCode('liste GEHEIM123 neu', 'geheim123'), isTrue);
      expect(subjectMatchesCode('Personalliste', 'geheim123'), isFalse);
      expect(subjectMatchesCode(null, 'geheim123'), isFalse);
      // Ein leerer Code darf nie alles freischalten.
      expect(subjectMatchesCode('irgendwas', ''), isFalse);
      expect(subjectMatchesCode('irgendwas', '   '), isFalse);
    });

    test('nimmt den ersten brauchbaren CSV-Kandidaten', () {
      expect(firstValidCsv(['kaputt', _csv]), _csv);
      expect(firstValidCsv([null, '', 'nur text ohne spalten']), isNull);
      expect(firstValidCsv(const []), isNull);
    });

    test('findet die Update-Mail am Betreff und im Text', () {
      final message = MessageBuilder.buildSimpleTextMessage(
        const MailAddress('Verwaltung', 'admin@example.com'),
        [const MailAddress('Terminal', 'update@example.com')],
        _csv,
        subject: 'LISTE geheim123',
        date: DateTime.now(),
      );
      final update = pickStaffUpdate([message], code: 'geheim123');
      expect(update, isNotNull);
      expect(update!.count, 3);
      expect(update.sender, 'admin@example.com');

      // Ohne Code im Betreff bleibt die Mail unbeachtet.
      expect(pickStaffUpdate([message], code: 'anderer-code'), isNull);
    });

    test('ueberspringt bereits uebernommene Mails', () {
      final message = MessageBuilder.buildSimpleTextMessage(
        const MailAddress('Verwaltung', 'admin@example.com'),
        [const MailAddress('Terminal', 'update@example.com')],
        _csv,
        subject: 'LISTE geheim123',
        date: DateTime.now(),
      );
      final future = DateTime.now().add(const Duration(hours: 1));
      expect(
        pickStaffUpdate([message], code: 'geheim123', since: future),
        isNull,
      );
    });

    test('loescht nur ueberholte Listen-Mails, nie die neuste', () {
      MimeMessage mail(int id, String subject, DateTime date, String body) {
        final message = MessageBuilder.buildSimpleTextMessage(
          const MailAddress('Verwaltung', 'admin@example.com'),
          [const MailAddress('Terminal', 'update@example.com')],
          body,
          subject: subject,
          date: date,
        );
        message.sequenceId = id;
        return message;
      }

      final now = DateTime.now();
      final messages = [
        // Alte Liste: darf weg.
        mail(1, 'LISTE geheim123', now.subtract(const Duration(days: 9)), _csv),
        // Fremde Mail ohne Code: bleibt unangetastet.
        mail(2, 'Newsletter', now.subtract(const Duration(days: 5)), 'Hallo'),
        // Neuste gueltige Liste: bleibt liegen.
        mail(3, 'LISTE geheim123', now, _csv),
      ];

      expect(supersededUpdateMailIds(messages, code: 'geheim123'), [1]);
      // Ohne einzige gueltige Liste wird gar nichts geloescht.
      expect(supersededUpdateMailIds(messages, code: 'anderer'), isEmpty);
    });

    test('Postfach-Zugang: Standardwerte und Speichern', () {
      const imap = ImapConfig();
      expect(imap.port, 993);
      expect(imap.ssl, isTrue);
      expect(imap.autoClean, isTrue);
      expect(imap.isComplete, isFalse);

      final settings = TerminalSettings();
      settings.updateImap((s) => s.copyWith(
            host: 'imap.example.com',
            user: 'update@example.com',
            password: 'geheim',
            secret: 'geheim123',
          ));
      expect(settings.imap.isComplete, isTrue);

      settings.updateImap((s) => s.copyWith(autoClean: false));

      final restored = TerminalSettings.fromJson(settings.toJson());
      expect(restored.imap.host, 'imap.example.com');
      expect(restored.imap.secret, 'geheim123');
      expect(restored.imap.autoClean, isFalse);

      // Wie der Versandzugang uebersteht er das Zuruecksetzen.
      settings.resetToDefaults();
      expect(settings.imap.isComplete, isTrue);
    });

    test('merkt sich den Stand der letzten Update-Mail', () {
      final settings = TerminalSettings();
      expect(settings.staffMailDate, isNull);

      final when = DateTime.fromMillisecondsSinceEpoch(1735686000000);
      settings.setStaffMailDate(when);
      final restored = TerminalSettings.fromJson(settings.toJson());
      expect(restored.staffMailDate, when);
    });
  });

  group('Sicherung der Einstellungen', () {
    TerminalSettings eingerichtet() {
      final settings = TerminalSettings();
      settings.setTerminalName('F11');
      settings.setSharedMailbox('paket@frigemo.ch');
      settings.updateSmtp((s) => s.copyWith(
            host: 'mx.example.com',
            port: 465,
            ssl: true,
            user: 'info@example.com',
            password: 'smtp-geheim',
            fromAddress: 'info@example.com',
            fromName: 'Empfang',
          ));
      settings.updateImap((s) => s.copyWith(
            host: 'mx.example.com',
            user: 'update@example.com',
            password: 'imap-geheim',
            secret: 'LISTE-21974',
          ));
      settings.setStaffCsv(_csv);
      return settings;
    }

    test('nimmt die Zugaenge mit, die Personalliste aber nicht', () {
      final backup = eingerichtet().toBackupJson();
      expect(backup['format'], TerminalSettings.backupFormat);

      final data = backup['settings'] as Map<String, dynamic>;
      expect(data['terminalName'], 'F11');
      expect((data['smtp'] as Map)['password'], 'smtp-geheim');
      expect((data['imap'] as Map)['secret'], 'LISTE-21974');
      // Personendaten wandern nicht in eine Datei, die kopiert wird.
      expect(data.containsKey('staffCsv'), isFalse);
      expect(data.containsKey('staffMailDate'), isFalse);
    });

    test('spielt die Zugaenge auf einem leeren Terminal zurueck', () {
      final backup = eingerichtet().toBackupJson();

      final frisch = TerminalSettings();
      expect(frisch.smtp.isComplete, isFalse);
      expect(frisch.restoreFromBackup(backup), isTrue);

      expect(frisch.terminalName, 'F11');
      expect(frisch.sharedMailbox, 'paket@frigemo.ch');
      expect(frisch.smtp.host, 'mx.example.com');
      expect(frisch.smtp.password, 'smtp-geheim');
      expect(frisch.smtp.port, 465);
      expect(frisch.smtp.ssl, isTrue);
      expect(frisch.imap.secret, 'LISTE-21974');
      expect(frisch.imap.password, 'imap-geheim');
    });

    test('laesst die vorhandene Personalliste in Ruhe', () {
      final ziel = TerminalSettings();
      ziel.setStaffCsv(_csv);

      ziel.restoreFromBackup(eingerichtet().toBackupJson());
      expect(ziel.hasOwnStaffList, isTrue);
      expect(employeesFromCsv(ziel.staffCsv!).length, 3);
    });

    test('weist eine fremde Datei ab, ohne etwas zu aendern', () {
      final settings = TerminalSettings();
      settings.setTerminalName('F11');

      expect(settings.restoreFromBackup({'irgendwas': 1}), isFalse);
      expect(settings.restoreFromBackup({'format': 'fremd'}), isFalse);
      // Kennzeichen stimmt, Inhalt fehlt -- auch das darf nichts anrichten.
      expect(
        settings.restoreFromBackup({'format': TerminalSettings.backupFormat}),
        isFalse,
      );
      expect(settings.terminalName, 'F11');
    });
  });

  group('L10n', () {
    test('liefert die Texte in allen Sprachen', () {
      expect(fr.t('send'), 'Envoyer la notification');
      expect(de.t('send'), 'Benachrichtigung senden');
      expect(en.t('send'), 'Send notification');
      expect(fr.code, 'fr');
      expect(de.code, 'de');
      expect(en.code, 'en');
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
    test('kennt jeden Schluessel in allen Sprachen', () {
      const keys = [
        'app.title',
        'app.subtitle',
        'lang.switch',
        'step.carrier',
        'step.recipient',
        'step.details',
        'carrier.other',
        'carrier.other.name',
        'search.hint',
        'search.where',
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
        'scan.button',
        'scan.title',
        'scan.hint',
        'scan.error',
        'scan.permission',
        'scan.wrongcode',
        'tracking.label',
        'send',
        'sending',
        'success.title',
        'success.body',
        'success.next',
        'error.title',
        'error.list',
        'error.notconfigured',
        'error.mailauth',
        'error.mail',
        'retry',
        'close',
        'admin.title',
        'admin.pin.title',
        'admin.pin.wrong',
        'admin.pin.set',
        'admin.pin.short',
        'admin.pin.change',
        'admin.kinds',
        'admin.locations',
        'admin.mailbox',
        'admin.mailbox.hint',
        'admin.add',
        'admin.name',
        'admin.name.hint',
        'admin.urgent',
        'admin.delete',
        'admin.reset',
        'admin.builtin.hint',
        'admin.staff',
        'admin.staff.hint',
        'admin.staff.builtin',
        'admin.staff.own',
        'admin.staff.import',
        'admin.staff.reset',
        'admin.staff.ok',
        'admin.staff.empty',
        'admin.backup',
        'admin.backup.hint',
        'admin.backup.save',
        'admin.backup.load',
        'admin.backup.saved',
        'admin.backup.restored',
        'admin.backup.invalid',
        'admin.mailupdate',
        'admin.mailupdate.hint',
        'admin.mailupdate.user',
        'admin.mailupdate.ssl',
        'admin.mailupdate.secret',
        'admin.mailupdate.clean',
        'admin.mailupdate.clean.hint',
        'admin.mailupdate.check',
        'admin.mailupdate.ok',
        'admin.mailupdate.none',
        'admin.mailupdate.fail',
        'mailupdate.confirm.subject',
        'mailupdate.confirm.body',
        'admin.smtp',
        'admin.smtp.hint',
        'admin.smtp.host',
        'admin.smtp.port',
        'admin.smtp.user',
        'admin.smtp.password',
        'admin.smtp.ssl',
        'admin.smtp.from',
        'admin.smtp.fromname',
        'admin.smtp.show',
        'admin.smtp.test',
        'admin.smtp.test.ok',
        'admin.smtp.test.target',
        'admin.terminal',
        'admin.terminal.hint',
        'admin.location.ask',
        'admin.location.hint',
        'admin.save',
        'admin.empty',
        'phone.title',
        'phone.button',
        'recipient.free',
        'recipient.free.hint',
        'recipient.unknown',
        'recipient.unknown.hint',
        'success.body.unknown',
        'mail.subject',
        'mail.subject.unknown',
        'mail.subject.name',
        'mail.intro.name',
        'mail.urgent.prefix',
        'mail.intro',
        'mail.intro.unknown',
        'mail.terminal',
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
        expect(en.t(key), isNot(key), reason: 'EN fehlt zu: $key');
      }
    });
  });

  group('Barcode vom Etikett auswählen', () {
    // Die Werte stammen von zwei echten Etiketten aus Cressier.
    Barcode strich(String value) =>
        Barcode(rawValue: value, format: BarcodeFormat.code128);
    Barcode flaeche(String value) =>
        Barcode(rawValue: value, format: BarcodeFormat.dataMatrix);

    test('nimmt die Sendungsnummer, nicht den kleinen Leitcode', () {
      // Genau der Fehler vom Empfang: gemeldet wurde '2307'.
      expect(
        pickTrackingCode([
          strich('2307'),
          strich('996013148238551546'),
        ]),
        '996013148238551546',
      );
    });

    test('die Reihenfolge der Kamera spielt keine Rolle', () {
      expect(
        pickTrackingCode([
          strich('996002680700338482'),
          strich('0509'),
        ]),
        '996002680700338482',
      );
    });

    test('ein DataMatrix des Absenders gewinnt nie', () {
      // Auf dem Digitec-Etikett steht ein DataMatrix neben der Adresse.
      expect(
        pickTrackingCode([
          flaeche('AT199851133-4501443337-Returns-Dintikon'),
          strich('996013148238551546'),
        ]),
        '996013148238551546',
      );
    });

    test('nur Leitcode im Bild: lieber nichts als das Falsche', () {
      expect(pickTrackingCode([strich('2307')]), isNull);
      expect(pickTrackingCode([]), isNull);
    });

    test('leerer und fehlender Inhalt fallen durch', () {
      expect(pickTrackingCode([strich('   '), const Barcode()]), isNull);
    });

    test('Leerraum wird abgeschnitten', () {
      expect(pickTrackingCode([strich('  996013148238551546  ')]),
          '996013148238551546');
    });

    test('kurze Nummern anderer Transporteure gehen durch', () {
      // GLS 11 Stellen, DHL ab 10 -- die Grenze darf sie nicht wegwerfen.
      expect(pickTrackingCode([strich('12345678901')]), '12345678901');
    });
  });
}
