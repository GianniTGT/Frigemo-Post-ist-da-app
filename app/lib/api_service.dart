/// Kein Server mehr: die Personalliste liegt als CSV im App-Bundle, und der
/// Versand laeuft ueber die E-Mail-App des Geraets (mailto:). Dateiname und
/// Klassennamen stammen noch aus der Server-Zeit -- das Verhalten dahinter
/// ist vollstaendig lokal.
library;

import 'dart:async';

import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'l10n.dart';

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

  /// Null, wenn auf der Sendung kein Name steht. Dann geht die Meldung nur
  /// an das gemeinsame Postfach.
  final Employee? recipient;

  final int quantity;
  final String kind;
  final String location;
  final String note;

  /// Sprache, in der gemeldet wird, wenn es keinen Empfaenger gibt.
  final AppLang terminalLang;

  const DeliveryDraft({
    required this.carrierLabel,
    required this.recipient,
    required this.quantity,
    required this.kind,
    required this.location,
    required this.note,
    required this.terminalLang,
  });
}

enum ApiErrorKind { network, timeout, unauthorized, server, mailFailed }

class ApiException implements Exception {
  final ApiErrorKind kind;
  final String? detail;

  const ApiException(this.kind, [this.detail]);

  /// Übersetzungsschlüssel für die Anzeige.
  String get messageKey => switch (kind) {
        ApiErrorKind.network => 'error.network',
        ApiErrorKind.timeout => 'error.timeout',
        ApiErrorKind.unauthorized => 'error.auth',
        ApiErrorKind.mailFailed => 'error.mail',
        ApiErrorKind.server => 'error.server',
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

/// Baut die mailto-Adresse, die das Terminal an die E-Mail-App uebergibt.
/// Mit Empfaenger geht die Meldung an die Person, das gemeinsame Postfach
/// steht in Kopie; ohne Empfaenger geht sie nur an das gemeinsame Postfach.
Uri composeMail(DeliveryDraft draft, {DateTime? now}) {
  final recipient = draft.recipient;
  final l = L10n(recipient?.lang ?? draft.terminalLang);
  final urgent = draft.kind == 'chilled';
  final shared = AppConfig.mailFallback.trim();

  final to = <String>[];
  final cc = <String>[];
  if (recipient != null) {
    to.add(recipient.email);
    if (shared.isNotEmpty) cc.add(shared);
  } else if (shared.isNotEmpty) {
    to.add(shared);
  }
  if (to.isEmpty) {
    throw const ApiException(ApiErrorKind.mailFailed, 'no recipient address');
  }

  final subject = (urgent ? l.t('mail.urgent.prefix') : '') +
      l.t(recipient != null ? 'mail.subject' : 'mail.subject.unknown',
          args: {'carrier': draft.carrierLabel});

  final lines = <String>[
    recipient != null
        ? l.t('mail.intro', args: {'name': recipient.name.split(' ').first})
        : l.t('mail.intro.unknown'),
    '',
    '${l.t('mail.carrier')}: ${draft.carrierLabel}',
    '${l.t('quantity')}: ${draft.quantity}',
    '${l.t('kind.label')}: ${l.t('kind.${draft.kind}')}',
    '${l.t('location.label')}: ${l.t('location.${draft.location}')}',
    if (recipient == null) '${l.t('mail.recipient')}: ${l.t('recipient.unknown')}',
    if (draft.note.isNotEmpty) '${l.t('mail.note')}: ${draft.note}',
    '${l.t('mail.time')}: ${formatStamp(now ?? DateTime.now())}',
    if (urgent) ...['', l.t('mail.urgentNote')],
    '',
    l.t('mail.footer'),
  ];

  // Adressen bleiben unkodiert – E-Mail-Adressen brauchen das nicht, und
  // manche Mail-Apps stolpern ueber kodierte Kommas.
  final query = <String>[
    if (cc.isNotEmpty) 'cc=${cc.join(',')}',
    'subject=${Uri.encodeComponent(subject)}',
    'body=${Uri.encodeComponent(lines.join('\n'))}',
  ];
  return Uri.parse('mailto:${to.join(',')}?${query.join('&')}');
}

// --- Dienst ----------------------------------------------------------------

class ApiService {
  List<Employee>? _staff;

  /// Ohne Server gibt es nichts, was ausfallen koennte.
  Future<bool> health() async => true;

  Future<List<Employee>> staff() async {
    final cached = _staff;
    if (cached != null) return cached;
    try {
      final raw = await rootBundle.loadString('assets/employees.csv');
      final parsed = employeesFromCsv(raw);
      _staff = parsed;
      return parsed;
    } catch (e) {
      // Fehlt oder zerbricht die Liste, muss der Empfang das sehen -- sonst
      // sieht es aus, als gaebe es die gesuchte Person nicht.
      throw ApiException(ApiErrorKind.server, e.toString());
    }
  }

  Future<List<Employee>> searchEmployees(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < AppConfig.minSearchChars) return const [];
    return searchIn(await staff(), trimmed, limit: AppConfig.maxSearchResults);
  }

  /// Uebergibt die fertige Meldung an die E-Mail-App. Abgeschickt wird sie
  /// dort von Hand – das Terminal sieht nicht, ob das passiert ist.
  Future<void> submitDelivery(DeliveryDraft draft) async {
    final uri = composeMail(draft);

    if (AppConfig.demoMode) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication)
        .catchError((_) => false);
    if (!opened) throw const ApiException(ApiErrorKind.mailFailed);
  }

  void dispose() {}
}
