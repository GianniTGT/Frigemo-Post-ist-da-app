/// Kein Server: die Personalliste liegt als CSV im App-Bundle, und die
/// Meldung geht direkt per SMTP raus. Der Fahrer sieht dabei keine fremde
/// App -- er bleibt im Terminal, und das Terminal weiss, ob es geklappt hat.
/// Dateiname und Klassennamen stammen noch aus der Server-Zeit.
library;

import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import 'config.dart';
import 'l10n.dart';
import 'settings.dart';

class Employee {
  final String id;
  final String name;
  final String email;
  final String department;

  /// Sprache der E-Mail an diese Person – unabhaengig von der Terminalsprache.
  final AppLang lang;

  const Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.department,
    required this.lang,
  });
}

class DeliveryDraft {
  final String carrierLabel;

  /// Null, wenn die Person nicht in der Liste steht oder auf der Sendung
  /// gar kein Name steht. Dann geht die Meldung an das gemeinsame Postfach.
  final Employee? recipient;

  /// Auf der Sendung steht ein Name, der nicht in der Liste vorkommt --
  /// neue Mitarbeitende, Temporaere, Externe, oder schlicht ein Tippfehler
  /// auf dem Etikett. Der Name ist trotzdem das Nuetzlichste an der Meldung
  /// und darf nicht verlorengehen.
  final String? recipientName;

  final int quantity;

  /// Angezeigte Bezeichnungen -- firmenintern benannt, deshalb steht hier
  /// der fertige Text und keine Kennung.
  final String kindLabel;

  /// Null, wenn der Abholort nicht gefragt wird -- dann steht er auch nicht
  /// in der Meldung.
  final String? locationLabel;

  /// Kuehlware und alles, was die Verwaltung ebenso markiert hat.
  final bool urgent;

  final String note;

  /// Gescannte Sendungsnummer vom Etikett. Leer, wenn nicht gescannt wurde --
  /// der Scan ist freiwillig, eine Meldung ohne Nummer bleibt gueltig.
  final String trackingCode;

  /// Name des Terminals, an dem gemeldet wurde (z. B. "F11"). Leer, wenn in
  /// der Verwaltung keiner gesetzt ist -- dann fehlt auch die Zeile.
  final String terminalName;

  /// Sprache, in der gemeldet wird, wenn es keinen Empfaenger gibt.
  final AppLang terminalLang;

  const DeliveryDraft({
    required this.carrierLabel,
    required this.recipient,
    this.recipientName,
    required this.quantity,
    required this.kindLabel,
    required this.locationLabel,
    required this.urgent,
    required this.note,
    this.trackingCode = '',
    this.terminalName = '',
    required this.terminalLang,
  });
}

/// Vier Dinge koennen schiefgehen: die Liste fehlt, das Terminal ist noch
/// nicht eingerichtet, die Anmeldung am Postfach scheitert, oder der Versand
/// geht aus einem anderen Grund nicht durch.
enum ApiErrorKind { listUnavailable, notConfigured, mailAuth, mailFailed }

class ApiException implements Exception {
  final ApiErrorKind kind;
  final String? detail;

  const ApiException(this.kind, [this.detail]);

  /// Übersetzungsschlüssel für die Anzeige.
  String get messageKey => switch (kind) {
        ApiErrorKind.listUnavailable => 'error.list',
        ApiErrorKind.notConfigured => 'error.notconfigured',
        ApiErrorKind.mailAuth => 'error.mailauth',
        ApiErrorKind.mailFailed => 'error.mail',
      };

  @override
  String toString() => 'ApiException($kind, $detail)';
}

// --- Personalliste ---------------------------------------------------------

/// Diakritika vereinheitlichen, damit "muller" auch "Müller" findet.
const Map<String, String> _foldings = {
  'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
  'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
  'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
  'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
  'ç': 'c', 'ñ': 'n', 'ß': 'ss',
};

String foldForSearch(String value) {
  final buffer = StringBuffer();
  for (final char in value.toLowerCase().split('')) {
    buffer.write(_foldings[char] ?? char);
  }
  return buffer.toString();
}

/// CSV mit Unterstuetzung fuer "Felder, mit Komma" – die Datei wird von Hand
/// gepflegt, deshalb muss ein Komma im Namen nicht die Liste zerlegen.
List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;

  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (quoted) {
      if (char == '"' && i + 1 < text.length && text[i + 1] == '"') {
        field.write('"');
        i++;
      } else if (char == '"') {
        quoted = false;
      } else {
        field.write(char);
      }
    } else if (char == '"') {
      quoted = true;
    } else if (char == ',' || char == ';') {
      row.add(field.toString());
      field.clear();
    } else if (char == '\n') {
      row.add(field.toString());
      rows.add(row);
      row = <String>[];
      field.clear();
    } else if (char != '\r') {
      field.write(char);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows
      .where((r) => r.any((cell) => cell.trim().isNotEmpty))
      .toList(growable: false);
}

/// Liest die gepflegte CSV. Unvollstaendige Zeilen werden uebersprungen,
/// damit ein Tippfehler nicht die ganze Liste unbrauchbar macht.
List<Employee> employeesFromCsv(String text) {
  final rows = parseCsv(text);
  if (rows.isEmpty) return const [];

  final header = rows.first.map((h) => h.trim().toLowerCase()).toList();
  int col(String name) => header.indexOf(name);

  final staff = <Employee>[];
  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    String cell(String name) {
      final index = col(name);
      return index >= 0 && index < row.length ? row[index].trim() : '';
    }

    final name = cell('name');
    final email = cell('email');
    if (name.isEmpty || email.isEmpty) continue;

    staff.add(Employee(
      id: '$i',
      name: name,
      email: email,
      department: cell('department'),
      lang: LocaleController.fromCode(cell('lang')),
    ));
  }
  return staff;
}

/// Sucht wie frueher der Server: alle Begriffe muessen vorkommen, Treffer am
/// Namensanfang zuerst.
List<Employee> searchIn(List<Employee> staff, String query, {int limit = 8}) {
  final terms = foldForSearch(query)
      .split(RegExp(r'\s+'))
      .where((term) => term.isNotEmpty)
      .toList(growable: false);
  if (terms.isEmpty) return const [];

  final hits = staff.where((e) {
    final haystack = foldForSearch('${e.name} ${e.department}');
    return terms.every((term) => haystack.contains(term));
  }).toList();

  hits.sort((a, b) {
    final aStarts = foldForSearch(a.name).startsWith(terms.first) ? 0 : 1;
    final bStarts = foldForSearch(b.name).startsWith(terms.first) ? 0 : 1;
    return aStarts != bStarts ? aStarts - bStarts : a.name.compareTo(b.name);
  });
  return hits.take(limit).toList(growable: false);
}

// --- E-Mail ----------------------------------------------------------------

String _two(int value) => value.toString().padLeft(2, '0');

String formatStamp(DateTime when) =>
    '${_two(when.day)}.${_two(when.month)}.${when.year} '
    '${_two(when.hour)}:${_two(when.minute)}';

/// Der fertige Text einer Meldung -- getrennt vom Versand, damit er sich
/// ohne Netzverbindung pruefen laesst.
class MailContent {
  final List<String> to;
  final List<String> cc;
  final String subject;
  final String body;

  const MailContent({
    required this.to,
    required this.cc,
    required this.subject,
    required this.body,
  });
}

/// Mit Empfaenger geht die Meldung an die Person, das gemeinsame Postfach
/// steht in Kopie; ohne Empfaenger geht sie nur an das gemeinsame Postfach.
MailContent composeDelivery(
  DeliveryDraft draft, {
  String? sharedMailbox,
  DateTime? now,
}) {
  final recipient = draft.recipient;
  final l = L10n(recipient?.lang ?? draft.terminalLang);
  final urgent = draft.urgent;
  final shared = (sharedMailbox ?? '').trim();

  final to = <String>[];
  final cc = <String>[];
  if (recipient != null) {
    to.add(recipient.email);
    if (shared.isNotEmpty) cc.add(shared);
  } else if (shared.isNotEmpty) {
    to.add(shared);
  }
  if (to.isEmpty) {
    throw const ApiException(ApiErrorKind.notConfigured, 'no recipient address');
  }

  final named = draft.recipientName?.trim() ?? '';

  final String subject;
  if (recipient != null) {
    subject = (urgent ? l.t('mail.urgent.prefix') : '') +
        l.t('mail.subject', args: {'carrier': draft.carrierLabel});
  } else if (named.isNotEmpty) {
    subject = (urgent ? l.t('mail.urgent.prefix') : '') +
        l.t('mail.subject.name',
            args: {'carrier': draft.carrierLabel, 'name': named});
  } else {
    subject = (urgent ? l.t('mail.urgent.prefix') : '') +
        l.t('mail.subject.unknown', args: {'carrier': draft.carrierLabel});
  }

  final location = draft.locationLabel;
  final lines = <String>[
    if (recipient != null)
      l.t('mail.intro', args: {'name': recipient.name.split(' ').first})
    else if (named.isNotEmpty)
      l.t('mail.intro.name', args: {'name': named})
    else
      l.t('mail.intro.unknown'),
    '',
    if (draft.terminalName.isNotEmpty)
      '${l.t('mail.terminal')}: ${draft.terminalName}',
    '${l.t('mail.carrier')}: ${draft.carrierLabel}',
    '${l.t('quantity')}: ${draft.quantity}',
    '${l.t('kind.label')}: ${draft.kindLabel}',
    if (location != null && location.isNotEmpty)
      '${l.t('location.label')}: $location',
    if (recipient == null)
      '${l.t('mail.recipient')}: '
          '${named.isNotEmpty ? named : l.t('recipient.unknown')}',
    if (draft.trackingCode.isNotEmpty)
      '${l.t('tracking.label')}: ${draft.trackingCode}',
    if (draft.note.isNotEmpty) '${l.t('mail.note')}: ${draft.note}',
    '${l.t('mail.time')}: ${formatStamp(now ?? DateTime.now())}',
    if (urgent) ...['', l.t('mail.urgentNote')],
    '',
    l.t('mail.footer'),
  ];

  return MailContent(
    to: to,
    cc: cc,
    subject: subject,
    body: lines.join('\n'),
  );
}

/// SMTP meldet eine gescheiterte Anmeldung als 535 oder 5.7.8.
bool isAuthFailure(String message) {
  final lower = message.toLowerCase();
  return lower.contains('535') ||
      lower.contains('5.7.8') ||
      lower.contains('authentication failed') ||
      lower.contains('authentication failure');
}

// --- Dienst ----------------------------------------------------------------

class ApiService {
  List<Employee>? _staff;
  String? _ownCsv;

  /// Eigene Liste vom Geraet. Null heisst: die mitgelieferte Datei gilt.
  /// Ein Wechsel verwirft den Zwischenspeicher, sonst suchte das Terminal
  /// weiter in der alten Liste.
  set staffCsv(String? csv) {
    final next = (csv ?? '').trim().isEmpty ? null : csv;
    if (next == _ownCsv) return;
    _ownCsv = next;
    _staff = null;
  }

  Future<List<Employee>> staff() async {
    final cached = _staff;
    if (cached != null) return cached;
    try {
      final raw =
          _ownCsv ?? await rootBundle.loadString('assets/employees.csv');
      final parsed = employeesFromCsv(raw);
      _staff = parsed;
      return parsed;
    } catch (e) {
      // Fehlt oder zerbricht die Liste, muss der Empfang das sehen -- sonst
      // sieht es aus, als gaebe es die gesuchte Person nicht.
      throw ApiException(ApiErrorKind.listUnavailable, e.toString());
    }
  }

  Future<List<Employee>> searchEmployees(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < AppConfig.minSearchChars) return const [];
    return searchIn(await staff(), trimmed, limit: AppConfig.maxSearchResults);
  }

  /// Verschickt die Meldung selbst. Der Fahrer sieht keine fremde App, und
  /// die Erfolgsmeldung stimmt: sie erscheint erst, wenn der Mailserver die
  /// Sendung angenommen hat.
  Future<void> submitDelivery(
    DeliveryDraft draft, {
    required SmtpConfig smtp,
    String? sharedMailbox,
  }) async {
    final content = composeDelivery(draft, sharedMailbox: sharedMailbox);
    await sendMail(content, smtp);
  }

  /// Auch fuer die Testmeldung aus der Verwaltung.
  Future<void> sendMail(MailContent content, SmtpConfig smtp) async {
    if (!smtp.isComplete) {
      throw const ApiException(ApiErrorKind.notConfigured);
    }

    if (AppConfig.demoMode) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      return;
    }

    final server = SmtpServer(
      smtp.host.trim(),
      port: smtp.port,
      ssl: smtp.ssl,
      username: smtp.user.trim().isEmpty ? null : smtp.user.trim(),
      password: smtp.password.isEmpty ? null : smtp.password,
      // Ohne Zugangsdaten ist es ein internes Relais, das keine Anmeldung
      // verlangt -- sonst bricht der Versand schon vor dem Verbinden ab.
      allowInsecure: smtp.user.trim().isEmpty,
    );

    final message = Message()
      ..from = Address(
        smtp.fromAddress.trim(),
        smtp.fromName.trim().isEmpty ? null : smtp.fromName.trim(),
      )
      ..recipients.addAll(content.to)
      ..ccRecipients.addAll(content.cc)
      ..subject = content.subject
      ..text = content.body;

    try {
      await send(message, server);
    } on MailerException catch (e) {
      // "Benutzer oder Passwort falsch" ist der haeufigste Fall beim
      // Einrichten und verdient eine Meldung, mit der man etwas anfangen
      // kann -- statt eines allgemeinen "ging nicht".
      throw ApiException(
        isAuthFailure(e.message) ? ApiErrorKind.mailAuth : ApiErrorKind.mailFailed,
        e.message,
      );
    } catch (e) {
      final text = e.toString();
      throw ApiException(
        isAuthFailure(text) ? ApiErrorKind.mailAuth : ApiErrorKind.mailFailed,
        text,
      );
    }
  }

  void dispose() {}
}
