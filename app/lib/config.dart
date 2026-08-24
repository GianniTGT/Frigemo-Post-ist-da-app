/// Zentrale Konfiguration des Terminals.
/// Alle Werte werden beim Build via --dart-define gesetzt, damit für eine
/// neue Server-IP kein Code-Change nötig ist:
///
///   flutter build linux \
///     --dart-define=API_BASE_URL=http://10.20.30.40:3000/api \
///     --dart-define=API_KEY=... \
///     --dart-define=TERMINAL_ID=cressier-reception-1
library;

class AppConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:3000/api',
  );

  static const String apiKey = String.fromEnvironment('API_KEY');

  static const String terminalId = String.fromEnvironment(
    'TERMINAL_ID',
    defaultValue: 'terminal-dev',
  );

  /// 'fr' oder 'de' – Standardsprache des Terminals.
  static const String defaultLanguage = String.fromEnvironment(
    'DEFAULT_LANGUAGE',
    defaultValue: 'fr',
  );

  /// Demomodus zum Ausprobieren ohne Server: Personalsuche und Versand
  /// werden im Gerät simuliert. Wird nur über --dart-define=DEMO_MODE=true
  /// gesetzt; ein Terminal im Betrieb laeuft nie damit.
  static const bool demoMode = bool.fromEnvironment('DEMO_MODE');

  /// Gemeinsames Postfach, das jede Meldung mitbekommt – bei einer Sendung
  /// ohne Namen ist es der einzige Empfaenger. Ueber --dart-define
  /// aenderbar, ohne den Code anzufassen.
  static const String mailFallback = String.fromEnvironment(
    'MAIL_FALLBACK',
    defaultValue: 'paketistda@frigemo.ch',
  );

  /// Mehr als zehn Sendungen auf einmal meldet der Empfang nicht.
  static const int maxQuantity = 10;

  static const Duration requestTimeout = Duration(seconds: 10);

  /// Formular zurücksetzen, wenn niemand mehr am Terminal steht.
  static const Duration idleTimeout = Duration(seconds: 90);

  /// Wie lange die Erfolgsmeldung stehen bleibt.
  static const Duration successDuration = Duration(seconds: 6);

  /// Wartezeit nach dem letzten Tastendruck, bevor gesucht wird.
  static const Duration searchDebounce = Duration(milliseconds: 300);

  /// Erst ab so vielen Zeichen fragt das Terminal den Server – die
  /// Mitarbeiterliste wird nie komplett aufs Gerät geladen.
  static const int minSearchChars = 2;

  static const int maxSearchResults = 8;

  static const Duration healthInterval = Duration(seconds: 30);
}

/// Kurierdienste. Farben sind die Markenfarben, damit der Empfang die
/// Kachel ohne Lesen trifft.
class CarrierOption {
  final String id;
  final String label;
  final int background;
  final int foreground;

  const CarrierOption(this.id, this.label, this.background, this.foreground);
}

const List<CarrierOption> kCarriers = [
  CarrierOption('dhl', 'DHL', 0xFFFFCC00, 0xFFD40511),
  CarrierOption('dpd', 'DPD', 0xFFDC0032, 0xFFFFFFFF),
  CarrierOption('post', 'Post CH', 0xFFFFCC00, 0xFF000000),
  CarrierOption('ups', 'UPS', 0xFF351C15, 0xFFFFB500),
  CarrierOption('fedex', 'FedEx', 0xFF4D148C, 0xFFFF6600),
  CarrierOption('planzer', 'Planzer', 0xFF004A99, 0xFFFFFFFF),
  CarrierOption('galliker', 'Galliker', 0xFF00833E, 0xFFFFFFFF),
  CarrierOption('other', '', 0xFF495057, 0xFFFFFFFF), // Label aus l10n
];

/// Sendungsarten – 'chilled' löst beim Server die Eilmeldung aus.
const List<String> kShipmentKinds = ['parcel', 'pallet', 'letter', 'chilled'];

/// Abholorte im Werk Cressier.
const List<String> kPickupLocations = ['reception', 'dock', 'coldroom'];

/// Telefonnummern für den Notfall-Dialog.
class PhoneContact {
  final String labelFr;
  final String labelDe;
  final String number;

  const PhoneContact(this.labelFr, this.labelDe, this.number);
}

const List<PhoneContact> kPhoneContacts = [
  PhoneContact('Réception / Logistique', 'Empfang / Logistik', '+41 31 000 00 00'),
  PhoneContact('Frigemo siège', 'Frigemo Hauptsitz', '+41 31 111 22 33'),
  PhoneContact('Sécurité / Portier', 'Sicherheit / Portier', '+41 31 999 88 77'),
];
