/// Einstellungen, die der Empfang selbst aendern koennen soll: welche
/// Sendungsarten und Abholorte erscheinen und wie sie im Werk wirklich
/// heissen. Alles liegt auf dem Geraet -- eine Aenderung braucht kein
/// neues APK.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';

/// Platzhalter fuer "nicht mitgegeben" in copyWith -- null bedeutet dort
/// "Bezeichnung loeschen" und muss unterscheidbar bleiben.
class _Unset {
  const _Unset();
}

const _Unset _unset = _Unset();

class OptionEntry {
  final String id;

  /// Firmeninterne Bezeichnung. Ist sie gesetzt, gilt sie in beiden
  /// Sprachen -- interne Namen wie "Rampe Nord" werden nicht uebersetzt.
  final String? customLabel;

  final bool visible;

  /// Loest die Eilmeldung aus (Kuehlware). Auch fuer eigene Eintraege
  /// waehlbar, damit ein interner Kuehlbereich genauso dringend meldet.
  final bool urgent;

  const OptionEntry({
    required this.id,
    this.customLabel,
    this.visible = true,
    this.urgent = false,
  });

  /// Eingebaute Eintraege haben eine Uebersetzung und lassen sich nicht
  /// loeschen, nur ausblenden oder umbenennen.
  bool get isBuiltIn => !id.startsWith('custom.');

  OptionEntry copyWith({
    Object? customLabel = _unset,
    bool? visible,
    bool? urgent,
  }) =>
      OptionEntry(
        id: id,
        customLabel: identical(customLabel, _unset)
            ? this.customLabel
            : customLabel as String?,
        visible: visible ?? this.visible,
        urgent: urgent ?? this.urgent,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        if (customLabel != null) 'label': customLabel,
        'visible': visible,
        'urgent': urgent,
      };

  static OptionEntry fromJson(Map<String, dynamic> json) => OptionEntry(
        id: (json['id'] ?? '').toString(),
        customLabel: json['label']?.toString(),
        visible: json['visible'] != false,
        urgent: json['urgent'] == true,
      );

}

/// Was ohne Zutun eingestellt ist. Der eingeschriebene Brief ist
/// ausgeblendet statt geloescht: er laesst sich in den Einstellungen
/// zurueckholen, ohne dass jemand ein neues APK bauen muss.
const List<OptionEntry> kDefaultKinds = [
  OptionEntry(id: 'parcel'),
  OptionEntry(id: 'pallet'),
  OptionEntry(id: 'letter', visible: false),
  OptionEntry(id: 'chilled', urgent: true),
];

const List<OptionEntry> kDefaultLocations = [
  OptionEntry(id: 'reception'),
  OptionEntry(id: 'dock'),
  OptionEntry(id: 'coldroom'),
];

/// Kein fester Startcode: 1234 stand im Quelltext und damit im
/// oeffentlichen Repository. Ist nichts gesetzt, verlangt die Verwaltung
/// beim ersten Zugriff, einen Code zu vergeben.
const int kMinPinLength = 4;

/// Zugang zum Postfach, aus dem die Meldungen verschickt werden. Liegt im
/// geschuetzten Speicher der App auf dem Geraet, nicht im APK -- ein
/// heruntergeladenes APK enthaelt kein Passwort.
class SmtpConfig {
  final String host;
  final int port;
  final String user;
  final String password;

  /// true = SMTPS (meist Port 465), false = STARTTLS (meist 587).
  final bool ssl;

  final String fromAddress;
  final String fromName;

  const SmtpConfig({
    this.host = '',
    this.port = 587,
    this.user = '',
    this.password = '',
    this.ssl = false,
    this.fromAddress = '',
    this.fromName = '',
  });

  /// Ohne Server und Absender kann nichts rausgehen. Das Passwort ist
  /// bewusst nicht Bedingung: interne Relais verlangen oft keines.
  bool get isComplete => host.trim().isNotEmpty && fromAddress.trim().isNotEmpty;

  SmtpConfig copyWith({
    String? host,
    int? port,
    String? user,
    String? password,
    bool? ssl,
    String? fromAddress,
    String? fromName,
  }) =>
      SmtpConfig(
        host: host ?? this.host,
        port: port ?? this.port,
        user: user ?? this.user,
        password: password ?? this.password,
        ssl: ssl ?? this.ssl,
        fromAddress: fromAddress ?? this.fromAddress,
        fromName: fromName ?? this.fromName,
      );

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'user': user,
        'password': password,
        'ssl': ssl,
        'fromAddress': fromAddress,
        'fromName': fromName,
      };

  static SmtpConfig fromJson(Map<String, dynamic> json) => SmtpConfig(
        host: (json['host'] ?? '').toString(),
        port: int.tryParse('${json['port']}') ?? 587,
        user: (json['user'] ?? '').toString(),
        password: (json['password'] ?? '').toString(),
        ssl: json['ssl'] == true,
        fromAddress: (json['fromAddress'] ?? '').toString(),
        fromName: (json['fromName'] ?? '').toString(),
      );
}

/// Zugang zum Update-Postfach: das Terminal ruft es selbst ab und uebernimmt
/// die Personalliste aus E-Mails, deren Betreff den Geheimcode enthaelt.
/// So laesst sich die Liste aus der Ferne pflegen, ohne die IT des Kunden.
class ImapConfig {
  final String host;
  final int port;
  final String user;
  final String password;

  /// true = IMAPS (Port 993). Ein Update-Postfach liegt im Internet,
  /// deshalb ist verschluesselt der Standard.
  final bool ssl;

  /// Nur E-Mails, deren Betreff diesen Code enthaelt, werden beachtet.
  /// Der Absender ist faelschbar -- der Code nicht erratbar.
  final String secret;

  /// Ueberholte Listen-Mails beim Abruf loeschen: im Postfach bleibt nur
  /// die neuste liegen. Alte Listen sind gespeicherte Personendaten, die
  /// niemand mehr braucht.
  final bool autoClean;

  const ImapConfig({
    this.host = '',
    this.port = 993,
    this.user = '',
    this.password = '',
    this.ssl = true,
    this.secret = '',
    this.autoClean = true,
  });

  /// Ohne Server, Benutzer und Geheimcode wird nichts abgerufen.
  bool get isComplete =>
      host.trim().isNotEmpty &&
      user.trim().isNotEmpty &&
      secret.trim().isNotEmpty;

  ImapConfig copyWith({
    String? host,
    int? port,
    String? user,
    String? password,
    bool? ssl,
    String? secret,
    bool? autoClean,
  }) =>
      ImapConfig(
        host: host ?? this.host,
        port: port ?? this.port,
        user: user ?? this.user,
        password: password ?? this.password,
        ssl: ssl ?? this.ssl,
        secret: secret ?? this.secret,
        autoClean: autoClean ?? this.autoClean,
      );

  Map<String, dynamic> toJson() => {
        'host': host,
        'port': port,
        'user': user,
        'password': password,
        'ssl': ssl,
        'secret': secret,
        'autoClean': autoClean,
      };

  static ImapConfig fromJson(Map<String, dynamic> json) => ImapConfig(
        host: (json['host'] ?? '').toString(),
        port: int.tryParse('${json['port']}') ?? 993,
        user: (json['user'] ?? '').toString(),
        password: (json['password'] ?? '').toString(),
        ssl: json['ssl'] != false,
        secret: (json['secret'] ?? '').toString(),
        autoClean: json['autoClean'] != false,
      );
}

class TerminalSettings extends ChangeNotifier {
  TerminalSettings({
    List<OptionEntry>? kinds,
    List<OptionEntry>? locations,
    String? pin,
    String? sharedMailbox,
    SmtpConfig? smtp,
    bool askLocation = false,
    String? staffCsv,
    String? terminalName,
    ImapConfig? imap,
    int? staffMailDate,
    SharedPreferences? store,
  })  : _kinds = List.of(kinds ?? kDefaultKinds),
        _locations = List.of(locations ?? kDefaultLocations),
        _pin = pin ?? '',
        _sharedMailbox = sharedMailbox ?? '',
        _smtp = smtp ?? const SmtpConfig(),
        _askLocation = askLocation,
        _staffCsv = staffCsv,
        _terminalName = terminalName ?? '',
        _imap = imap ?? const ImapConfig(),
        _staffMailDate = staffMailDate,
        _store = store;

  List<OptionEntry> _kinds;
  List<OptionEntry> _locations;
  String _pin;
  String _sharedMailbox;
  SmtpConfig _smtp;
  bool _askLocation;
  String? _staffCsv;
  String _terminalName;
  ImapConfig _imap;

  /// Zeitstempel (Millisekunden) der zuletzt uebernommenen Update-Mail.
  /// Jede Tablette merkt sich das selbst -- die Mail bleibt im Postfach
  /// liegen, damit weitere Terminals sie ebenfalls uebernehmen koennen.
  int? _staffMailDate;
  final SharedPreferences? _store;

  static const String _key = 'terminal.settings.v1';

  List<OptionEntry> get kinds => List.unmodifiable(_kinds);
  List<OptionEntry> get locations => List.unmodifiable(_locations);
  String get pin => _pin;

  /// Solange keiner vergeben ist, kann die Verwaltung nicht geschuetzt
  /// werden -- dann verlangt sie zuerst einen Code.
  bool get hasPin => _pin.trim().length >= kMinPinLength;

  /// Gemeinsames Postfach. Leer heisst: keins -- dann geht keine Meldung an
  /// eine tote Adresse, und "Empfaenger unbekannt" bleibt ausgeblendet.
  String get sharedMailbox => _sharedMailbox.trim();
  bool get hasSharedMailbox => sharedMailbox.isNotEmpty;

  SmtpConfig get smtp => _smtp;

  /// Eigene Personalliste, am Geraet eingelesen. Null heisst: es gilt die
  /// im APK mitgelieferte Datei. Damit braucht ein weiterer Standort kein
  /// eigenes APK -- er liest seine Liste selbst ein.
  String? get staffCsv => _staffCsv;
  bool get hasOwnStaffList => (_staffCsv ?? '').trim().isNotEmpty;

  /// Der Fahrer weiss nicht, wo die Sendung im Werk hingehoert -- deshalb
  /// wird der Abholort standardmaessig nicht gefragt. Wer ihn doch braucht,
  /// schaltet ihn in der Verwaltung ein.
  bool get askLocation => _askLocation;

  /// Name dieses Terminals, z. B. "F11" oder "Réception". Steht in jeder
  /// Meldung -- so bleibt bei mehreren Terminals in einem Werk erkennbar,
  /// wo die Sendung abgegeben wurde. Leer heisst: keine Zeile.
  String get terminalName => _terminalName.trim();
  bool get hasTerminalName => terminalName.isNotEmpty;

  ImapConfig get imap => _imap;

  DateTime? get staffMailDate {
    final millis = _staffMailDate;
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  List<OptionEntry> get visibleKinds =>
      _kinds.where((e) => e.visible).toList(growable: false);
  List<OptionEntry> get visibleLocations =>
      _locations.where((e) => e.visible).toList(growable: false);

  /// Firmeninterner Name geht vor Uebersetzung. Eigene Eintraege ohne Namen
  /// zeigen ihre Kennung, damit nie eine leere Kachel entsteht.
  String labelOf(OptionEntry entry, L10n l, String prefix) {
    final custom = entry.customLabel?.trim() ?? '';
    if (custom.isNotEmpty) return custom;
    final key = '$prefix.${entry.id}';
    final translated = l.t(key);
    return translated == key ? entry.id : translated;
  }

  OptionEntry? kindById(String id) {
    for (final entry in _kinds) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  // --- Aendern -------------------------------------------------------------

  void updateKind(String id, OptionEntry Function(OptionEntry) change) {
    _apply(_kinds, id, change);
  }

  void updateLocation(String id, OptionEntry Function(OptionEntry) change) {
    _apply(_locations, id, change);
  }

  void _apply(
    List<OptionEntry> list,
    String id,
    OptionEntry Function(OptionEntry) change,
  ) {
    final index = list.indexWhere((e) => e.id == id);
    if (index < 0) return;
    list[index] = change(list[index]);
    _persist();
  }

  String addKind(String label, {bool urgent = false}) =>
      _add(_kinds, label, urgent: urgent);

  String addLocation(String label) => _add(_locations, label);

  String _add(List<OptionEntry> list, String label, {bool urgent = false}) {
    final id = 'custom.${DateTime.now().microsecondsSinceEpoch}';
    list.add(OptionEntry(
      id: id,
      customLabel: label.trim(),
      urgent: urgent,
    ));
    _persist();
    return id;
  }

  /// Nur eigene Eintraege verschwinden ganz. Eingebaute werden ausgeblendet,
  /// sonst waeren sie ohne Neuinstallation nicht zurueckzuholen.
  void remove(String id) {
    _kinds.removeWhere((e) => e.id == id && !e.isBuiltIn);
    _locations.removeWhere((e) => e.id == id && !e.isBuiltIn);
    _persist();
  }

  void setPin(String value) {
    _pin = value.trim();
    _persist();
  }

  void setSharedMailbox(String value) {
    _sharedMailbox = value.trim();
    _persist();
  }

  void updateSmtp(SmtpConfig Function(SmtpConfig) change) {
    _smtp = change(_smtp);
    _persist();
  }

  void setAskLocation(bool value) {
    _askLocation = value;
    _persist();
  }

  void setTerminalName(String value) {
    _terminalName = value.trim();
    _persist();
  }

  void updateImap(ImapConfig Function(ImapConfig) change) {
    _imap = change(_imap);
    _persist();
  }

  void setStaffMailDate(DateTime? value) {
    _staffMailDate = value?.millisecondsSinceEpoch;
    _persist();
  }

  /// Null setzt auf die mitgelieferte Liste zurueck.
  void setStaffCsv(String? csv) {
    final trimmed = csv?.trim() ?? '';
    _staffCsv = trimmed.isEmpty ? null : trimmed;
    _persist();
  }

  /// Setzt die Auswahl zurueck. Der Versandzugang und der Terminal-Name
  /// bleiben erhalten -- sonst stuende das Terminal nach einem Fehlgriff
  /// stumm oder namenlos, bis jemand beides erneut heraussucht.
  void resetToDefaults() {
    _kinds = List.of(kDefaultKinds);
    _locations = List.of(kDefaultLocations);
    _pin = '';
    _askLocation = false;
    _persist();
  }

  // --- Speichern -----------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'kinds': _kinds.map((e) => e.toJson()).toList(),
        'locations': _locations.map((e) => e.toJson()).toList(),
        'pin': _pin,
        'sharedMailbox': _sharedMailbox,
        'smtp': _smtp.toJson(),
        'askLocation': _askLocation,
        'terminalName': _terminalName,
        'imap': _imap.toJson(),
        if (_staffMailDate != null) 'staffMailDate': _staffMailDate,
        if (_staffCsv != null) 'staffCsv': _staffCsv,
      };

  static TerminalSettings fromJson(
    Map<String, dynamic> json, {
    SharedPreferences? store,
  }) {
    List<OptionEntry> read(String key, List<OptionEntry> fallback) {
      final raw = json[key];
      if (raw is! List || raw.isEmpty) return List.of(fallback);
      final parsed = raw
          .whereType<Map>()
          .map((m) => OptionEntry.fromJson(Map<String, dynamic>.from(m)))
          .where((e) => e.id.isNotEmpty)
          .toList();
      return parsed.isEmpty ? List.of(fallback) : parsed;
    }

    return TerminalSettings(
      kinds: read('kinds', kDefaultKinds),
      locations: read('locations', kDefaultLocations),
      pin: (json['pin'] ?? '').toString(),
      sharedMailbox: (json['sharedMailbox'] ?? '').toString(),
      smtp: json['smtp'] is Map
          ? SmtpConfig.fromJson(Map<String, dynamic>.from(json['smtp'] as Map))
          : const SmtpConfig(),
      askLocation: json['askLocation'] == true,
      staffCsv: json['staffCsv']?.toString(),
      terminalName: (json['terminalName'] ?? '').toString(),
      imap: json['imap'] is Map
          ? ImapConfig.fromJson(Map<String, dynamic>.from(json['imap'] as Map))
          : const ImapConfig(),
      staffMailDate: int.tryParse('${json['staffMailDate']}'),
      store: store,
    );
  }

  /// Laedt die Einstellungen. Ist nichts gespeichert oder der Eintrag
  /// beschaedigt, gelten die Standardwerte -- das Terminal startet immer.
  static Future<TerminalSettings> load({
    String? defaultMailbox,
    String? defaultPin,
  }) async {
    try {
      final store = await SharedPreferences.getInstance();
      final raw = store.getString(_key);
      if (raw == null) {
        return TerminalSettings(
          sharedMailbox: defaultMailbox,
          pin: defaultPin,
          store: store,
        );
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return TerminalSettings(
          sharedMailbox: defaultMailbox,
          pin: defaultPin,
          store: store,
        );
      }
      return fromJson(Map<String, dynamic>.from(decoded), store: store);
    } catch (_) {
      return TerminalSettings(sharedMailbox: defaultMailbox, pin: defaultPin);
    }
  }

  void _persist() {
    notifyListeners();
    _store?.setString(_key, jsonEncode(toJson()));
  }
}
