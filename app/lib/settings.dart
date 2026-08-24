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

const String kDefaultPin = '1234';

class TerminalSettings extends ChangeNotifier {
  TerminalSettings({
    List<OptionEntry>? kinds,
    List<OptionEntry>? locations,
    String? pin,
    String? sharedMailbox,
    SharedPreferences? store,
  })  : _kinds = List.of(kinds ?? kDefaultKinds),
        _locations = List.of(locations ?? kDefaultLocations),
        _pin = pin ?? kDefaultPin,
        _sharedMailbox = sharedMailbox ?? '',
        _store = store;

  List<OptionEntry> _kinds;
  List<OptionEntry> _locations;
  String _pin;
  String _sharedMailbox;
  final SharedPreferences? _store;

  static const String _key = 'terminal.settings.v1';

  List<OptionEntry> get kinds => List.unmodifiable(_kinds);
  List<OptionEntry> get locations => List.unmodifiable(_locations);
  String get pin => _pin;

  /// Gemeinsames Postfach. Leer heisst: keins -- dann geht keine Meldung an
  /// eine tote Adresse, und "Empfaenger unbekannt" bleibt ausgeblendet.
  String get sharedMailbox => _sharedMailbox.trim();
  bool get hasSharedMailbox => sharedMailbox.isNotEmpty;

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

  void resetToDefaults() {
    _kinds = List.of(kDefaultKinds);
    _locations = List.of(kDefaultLocations);
    _pin = kDefaultPin;
    _persist();
  }

  // --- Speichern -----------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'kinds': _kinds.map((e) => e.toJson()).toList(),
        'locations': _locations.map((e) => e.toJson()).toList(),
        'pin': _pin,
        'sharedMailbox': _sharedMailbox,
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
      pin: (json['pin'] ?? kDefaultPin).toString(),
      sharedMailbox: (json['sharedMailbox'] ?? '').toString(),
      store: store,
    );
  }

  /// Laedt die Einstellungen. Ist nichts gespeichert oder der Eintrag
  /// beschaedigt, gelten die Standardwerte -- das Terminal startet immer.
  static Future<TerminalSettings> load({String? defaultMailbox}) async {
    try {
      final store = await SharedPreferences.getInstance();
      final raw = store.getString(_key);
      if (raw == null) {
        return TerminalSettings(sharedMailbox: defaultMailbox, store: store);
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return TerminalSettings(sharedMailbox: defaultMailbox, store: store);
      }
      return fromJson(Map<String, dynamic>.from(decoded), store: store);
    } catch (_) {
      return TerminalSettings(sharedMailbox: defaultMailbox);
    }
  }

  void _persist() {
    notifyListeners();
    _store?.setString(_key, jsonEncode(toJson()));
  }
}
