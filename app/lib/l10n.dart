import 'package:flutter/foundation.dart';

enum AppLang { fr, de }

/// Sprache des Terminals. Umschalten wirkt sofort auf das ganze UI.
class LocaleController extends ValueNotifier<AppLang> {
  LocaleController(super.value);

  void toggle() => value = value == AppLang.fr ? AppLang.de : AppLang.fr;

  static AppLang fromCode(String code) =>
      code.toLowerCase().startsWith('de') ? AppLang.de : AppLang.fr;
}

class L10n {
  final AppLang lang;
  const L10n(this.lang);

  String t(String key, {Map<String, String>? args}) {
    var out = _strings[key]?[lang] ?? key;
    args?.forEach((k, v) => out = out.replaceAll('{$k}', v));
    return out;
  }

  String get code => lang.name;

  static const Map<String, Map<AppLang, String>> _strings = {
    'app.title': {
      AppLang.fr: 'Réception – Frigemo Cressier',
      AppLang.de: 'Empfang – Frigemo Cressier',
    },
    'app.subtitle': {
      AppLang.fr: 'Annoncer une livraison',
      AppLang.de: 'Lieferung anmelden',
    },
    'lang.switch': {AppLang.fr: 'Deutsch', AppLang.de: 'Français'},
    'step.carrier': {
      AppLang.fr: 'Transporteur',
      AppLang.de: 'Transporteur',
    },
    'step.recipient': {
      AppLang.fr: 'Destinataire',
      AppLang.de: 'Empfänger',
    },
    'step.details': {
      AppLang.fr: 'Détails de l\u2019envoi',
      AppLang.de: 'Angaben zur Sendung',
    },
    'carrier.other': {AppLang.fr: 'Autre', AppLang.de: 'Andere'},
    'search.hint': {
      AppLang.fr: 'Nom, prénom ou service',
      AppLang.de: 'Name, Vorname oder Abteilung',
    },
    'search.min': {
      AppLang.fr: 'Saisir au moins 2 lettres',
      AppLang.de: 'Mindestens 2 Zeichen eingeben',
    },
    'search.none': {
      AppLang.fr: 'Aucun destinataire trouvé',
      AppLang.de: 'Keine Empfänger gefunden',
    },
    'search.change': {AppLang.fr: 'Changer', AppLang.de: 'Ändern'},
    'quantity': {AppLang.fr: 'Nombre', AppLang.de: 'Anzahl'},
    'kind.parcel': {AppLang.fr: 'Colis', AppLang.de: 'Paket'},
    'kind.pallet': {AppLang.fr: 'Palette', AppLang.de: 'Palette'},
    'kind.letter': {
      AppLang.fr: 'Courrier recommandé',
      AppLang.de: 'Eingeschriebener Brief',
    },
    'kind.chilled': {
      AppLang.fr: 'Marchandise réfrigérée',
      AppLang.de: 'Kühlware',
    },
    'kind.label': {AppLang.fr: 'Type', AppLang.de: 'Art'},
    'location.label': {AppLang.fr: 'À retirer à', AppLang.de: 'Abholort'},
    'location.reception': {AppLang.fr: 'Réception', AppLang.de: 'Empfang'},
    'location.dock': {
      AppLang.fr: 'Quai de chargement',
      AppLang.de: 'Laderampe',
    },
    'location.coldroom': {AppLang.fr: 'Chambre froide', AppLang.de: 'Kühlraum'},
    'note.label': {
      AppLang.fr: 'Remarque (facultatif)',
      AppLang.de: 'Bemerkung (optional)',
    },
    'chilled.warning': {
      AppLang.fr: 'Marchandise réfrigérée : le destinataire reçoit une alerte urgente.',
      AppLang.de: 'Kühlware: Der Empfänger erhält eine dringende Meldung.',
    },
    'send': {
      AppLang.fr: 'Envoyer la notification',
      AppLang.de: 'Benachrichtigung senden',
    },
    'sending': {AppLang.fr: 'Envoi en cours…', AppLang.de: 'Wird gesendet…'},
    'success.title': {
      AppLang.fr: 'Notification envoyée',
      AppLang.de: 'Benachrichtigung gesendet',
    },
    'success.body': {
      AppLang.fr: '{name} vient d\u2019être informé.',
      AppLang.de: '{name} wurde informiert.',
    },
    'success.next': {AppLang.fr: 'Nouvel envoi', AppLang.de: 'Neue Sendung'},
    'error.title': {
      AppLang.fr: 'Envoi impossible',
      AppLang.de: 'Senden nicht möglich',
    },
    'error.network': {
      AppLang.fr: 'Le terminal n\u2019atteint pas le serveur. Vérifier le câble réseau, puis réessayer.',
      AppLang.de: 'Das Terminal erreicht den Server nicht. Netzwerkkabel prüfen, dann nochmals versuchen.',
    },
    'error.timeout': {
      AppLang.fr: 'Le serveur ne répond pas. Réessayer dans un moment.',
      AppLang.de: 'Der Server antwortet nicht. In einem Moment nochmals versuchen.',
    },
    'error.server': {
      AppLang.fr: 'Le serveur a refusé l\u2019envoi. Prévenir l\u2019informatique.',
      AppLang.de: 'Der Server hat die Sendung abgelehnt. IT informieren.',
    },
    'error.auth': {
      AppLang.fr: 'Ce terminal n\u2019est pas autorisé. Prévenir l\u2019informatique.',
      AppLang.de: 'Dieses Terminal ist nicht autorisiert. IT informieren.',
    },
    'error.mail': {
      AppLang.fr: 'Livraison enregistrée, mais l\u2019e-mail n\u2019est pas parti. Prévenir le destinataire par téléphone.',
      AppLang.de: 'Lieferung erfasst, aber die E-Mail ging nicht raus. Empfänger telefonisch informieren.',
    },
    'retry': {AppLang.fr: 'Réessayer', AppLang.de: 'Nochmals versuchen'},
    'close': {AppLang.fr: 'Fermer', AppLang.de: 'Schliessen'},
    'offline': {
      AppLang.fr: 'Serveur injoignable – annoncer par téléphone',
      AppLang.de: 'Server nicht erreichbar – telefonisch melden',
    },
    'phone.title': {
      AppLang.fr: 'Contacts téléphoniques',
      AppLang.de: 'Telefonkontakte',
    },
    'phone.button': {AppLang.fr: 'Téléphone', AppLang.de: 'Telefon'},
    'phone.failed': {
      AppLang.fr: 'Composer le numéro manuellement.',
      AppLang.de: 'Nummer manuell wählen.',
    },
  };
}
