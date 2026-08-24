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
    'error.list': {
      AppLang.fr: 'La liste du personnel n\u2019a pas pu être lue. Prévenir l\u2019informatique.',
      AppLang.de: 'Die Personalliste liess sich nicht lesen. IT informieren.',
    },
    'error.mail': {
      AppLang.fr: 'Impossible d\u2019ouvrir l\u2019application e-mail. Prévenir le destinataire par téléphone.',
      AppLang.de: 'Die E-Mail-App liess sich nicht öffnen. Empfänger telefonisch informieren.',
    },
    'retry': {AppLang.fr: 'Réessayer', AppLang.de: 'Nochmals versuchen'},
    'close': {AppLang.fr: 'Fermer', AppLang.de: 'Schliessen'},
    'phone.title': {
      AppLang.fr: 'Contacts téléphoniques',
      AppLang.de: 'Telefonkontakte',
    },
    'phone.button': {AppLang.fr: 'Téléphone', AppLang.de: 'Telefon'},
    'recipient.unknown': {
      AppLang.fr: 'Destinataire inconnu',
      AppLang.de: 'Empfänger unbekannt',
    },
    'recipient.unknown.hint': {
      AppLang.fr: 'L\u2019annonce part uniquement à la boîte commune.',
      AppLang.de: 'Die Meldung geht nur an das gemeinsame Postfach.',
    },
    'success.body.unknown': {
      AppLang.fr: 'L\u2019annonce est prête dans l\u2019application e-mail.',
      AppLang.de: 'Die Meldung liegt in der E-Mail-App bereit.',
    },
    'mail.subject': {
      AppLang.fr: 'Livraison pour vous – {carrier}',
      AppLang.de: 'Lieferung für Sie – {carrier}',
    },
    'mail.subject.unknown': {
      AppLang.fr: 'Livraison sans destinataire – {carrier}',
      AppLang.de: 'Lieferung ohne Empfänger – {carrier}',
    },
    'mail.urgent.prefix': {
      AppLang.fr: '[URGENT] ',
      AppLang.de: '[DRINGEND] ',
    },
    'mail.intro': {
      AppLang.fr: 'Bonjour {name}, une livraison est arrivée à votre nom à la réception de Cressier.',
      AppLang.de: 'Guten Tag {name}, am Empfang Cressier ist eine Lieferung auf Ihren Namen eingetroffen.',
    },
    'mail.intro.unknown': {
      AppLang.fr: 'Une livraison est arrivée à la réception de Cressier sans nom de destinataire.',
      AppLang.de: 'Am Empfang Cressier ist eine Lieferung ohne Empfängernamen eingetroffen.',
    },
    'mail.carrier': {AppLang.fr: 'Transporteur', AppLang.de: 'Transporteur'},
    'mail.recipient': {AppLang.fr: 'Destinataire', AppLang.de: 'Empfänger'},
    'mail.note': {AppLang.fr: 'Remarque', AppLang.de: 'Bemerkung'},
    'mail.time': {AppLang.fr: 'Annoncé le', AppLang.de: 'Gemeldet am'},
    'mail.urgentNote': {
      AppLang.fr: 'Marchandise réfrigérée : merci de venir la chercher immédiatement, la chaîne du froid ne peut pas être garantie à la réception.',
      AppLang.de: 'Kühlware: Bitte sofort abholen – am Empfang kann die Kühlkette nicht eingehalten werden.',
    },
    'mail.footer': {
      AppLang.fr: 'Message automatique du terminal de réception de Cressier.',
      AppLang.de: 'Automatische Meldung des Empfangsterminals Cressier.',
    },
    'phone.failed': {
      AppLang.fr: 'Composer le numéro manuellement.',
      AppLang.de: 'Nummer manuell wählen.',
    },
  };
}
