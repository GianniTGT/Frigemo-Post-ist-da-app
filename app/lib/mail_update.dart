/// Personalliste aus der Ferne pflegen, ohne die IT des Kunden: das Terminal
/// ruft ein Update-Postfach per IMAP ab. Eine E-Mail, deren Betreff den
/// Geheimcode enthaelt und die eine gueltige CSV traegt (als Anhang oder im
/// Text), ersetzt die Liste. Die Mail bleibt im Postfach liegen -- weitere
/// Terminals uebernehmen sie ebenfalls, jedes merkt sich selbst, was es
/// schon hat.
library;

import 'package:enough_mail/enough_mail.dart';

import 'api_service.dart';
import 'settings.dart';

/// Eine uebernommene Liste samt Herkunft -- fuer die Bestaetigungsmail an
/// die Person, die sie geschickt hat.
class StaffMailUpdate {
  final String csv;
  final int count;
  final DateTime date;
  final String? sender;

  const StaffMailUpdate({
    required this.csv,
    required this.count,
    required this.date,
    this.sender,
  });
}

/// Der Absender ist faelschbar, der Code nicht erratbar: nur E-Mails, deren
/// Betreff den Geheimcode enthaelt, werden ueberhaupt beachtet.
bool subjectMatchesCode(String? subject, String code) {
  final trimmed = code.trim().toLowerCase();
  if (trimmed.isEmpty) return false;
  return (subject ?? '').toLowerCase().contains(trimmed);
}

/// Erster Kandidat, der als Personalliste taugt. Eine leere oder kaputte
/// Datei faellt durch -- die bisherige Liste bleibt dann bestehen.
String? firstValidCsv(Iterable<String?> candidates) {
  for (final text in candidates) {
    if (text == null || text.trim().isEmpty) continue;
    if (employeesFromCsv(text).isNotEmpty) return text;
  }
  return null;
}

/// Sucht in den juengsten Nachrichten die neuste brauchbare Update-Mail
/// nach [since]. Null heisst: nichts Neues.
StaffMailUpdate? pickStaffUpdate(
  List<MimeMessage> messages, {
  required String code,
  DateTime? since,
}) {
  StaffMailUpdate? best;
  for (final message in messages) {
    if (!subjectMatchesCode(message.decodeSubject(), code)) continue;

    final date = message.decodeDate();
    if (date == null) continue;
    if (since != null && !date.isAfter(since)) continue;
    if (best != null && !date.isAfter(best.date)) continue;

    // CSV-Anhaenge zuerst, dann der Textkoerper -- so laesst sich die Liste
    // notfalls direkt in die Mail hineinkopieren.
    final csv = firstValidCsv([
      for (final part in message.allPartsFlat)
        if ((part.decodeFileName() ?? '').toLowerCase().endsWith('.csv'))
          part.decodeContentText(),
      message.decodeTextPlainPart(),
    ]);
    if (csv == null) continue;

    best = StaffMailUpdate(
      csv: csv,
      count: employeesFromCsv(csv).length,
      date: date,
      sender: message.fromEmail,
    );
  }
  return best;
}

/// Ruft das Postfach ab. Wirft bei Verbindungs- oder Anmeldefehlern -- die
/// Verwaltung zeigt das an, der Hintergrundabruf schluckt es still.
Future<StaffMailUpdate?> fetchStaffUpdate(
  ImapConfig imap, {
  DateTime? since,
}) async {
  final client = ImapClient(isLogEnabled: false);
  try {
    await client.connectToServer(
      imap.host.trim(),
      imap.port,
      isSecure: imap.ssl,
    );
    await client.login(imap.user.trim(), imap.password);
    await client.selectInbox();
    // BODY.PEEK laesst die Mails ungelesen -- ein Terminal darf sie den
    // anderen nicht wegschnappen.
    final fetched = await client.fetchRecentMessages(
      messageCount: 25,
      criteria: '(BODY.PEEK[])',
    );
    return pickStaffUpdate(
      fetched.messages,
      code: imap.secret,
      since: since,
    );
  } finally {
    try {
      await client.logout();
    } catch (_) {
      // Die Verbindung haengt oder ist schon weg -- fuer das Ergebnis egal.
    }
  }
}

/// Ruft ab, uebernimmt die Liste und merkt sich den Stand. Liefert die
/// Anzahl Personen oder null, wenn nichts Neues da war.
Future<int?> applyStaffUpdate(
  TerminalSettings settings,
  ApiService api, {
  required L10nLookup confirmTexts,
}) async {
  if (!settings.imap.isComplete) return null;

  final update = await fetchStaffUpdate(
    settings.imap,
    since: settings.staffMailDate,
  );
  if (update == null) return null;

  settings.setStaffCsv(update.csv);
  settings.setStaffMailDate(update.date);
  api.staffCsv = settings.staffCsv;

  // Bestaetigung an die Person, die die Liste geschickt hat -- sonst weiss
  // niemand, ob die Terminals sie wirklich uebernommen haben. Ein Fehler
  // hier macht das Update nicht rueckgaengig.
  final sender = update.sender;
  if (sender != null && sender.isNotEmpty && settings.smtp.isComplete) {
    try {
      await api.sendMail(
        MailContent(
          to: [sender],
          cc: const [],
          subject: confirmTexts.subject(update.count),
          body: confirmTexts.body(update.count),
        ),
        settings.smtp,
      );
    } catch (_) {
      // Die Liste ist uebernommen; nur die Bestaetigung ging nicht raus.
    }
  }
  return update.count;
}

/// Die Texte der Bestaetigungsmail kommen vom Aufrufer -- dieser Dienst
/// kennt weder Sprache noch Terminalnamen.
class L10nLookup {
  final String Function(int count) subject;
  final String Function(int count) body;

  const L10nLookup({required this.subject, required this.body});
}
