import 'package:flutter/foundation.dart';

enum AppLang { fr, de, en }

/// Sprache des Terminals. Umschalten wirkt sofort auf das ganze UI.
class LocaleController extends ValueNotifier<AppLang> {
  LocaleController(super.value);

  /// Schaltet der Reihe nach durch alle Sprachen: fr -> de -> en -> fr.
  void toggle() =>
      value = AppLang.values[(value.index + 1) % AppLang.values.length];

  static AppLang fromCode(String code) {
    final lower = code.toLowerCase();
    if (lower.startsWith('de')) return AppLang.de;
    if (lower.startsWith('en')) return AppLang.en;
    return AppLang.fr;
  }
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
      AppLang.en: 'Reception – Frigemo Cressier',
    },
    'app.subtitle': {
      AppLang.fr: 'Annoncer une livraison',
      AppLang.de: 'Lieferung anmelden',
      AppLang.en: 'Announce a delivery',
    },
    // Beschriftet den Sprachknopf mit der jeweils naechsten Sprache.
    'lang.switch': {
      AppLang.fr: 'Deutsch',
      AppLang.de: 'English',
      AppLang.en: 'Français',
    },
    'step.carrier': {
      AppLang.fr: 'Transporteur',
      AppLang.de: 'Transporteur',
      AppLang.en: 'Carrier',
    },
    'step.recipient': {
      AppLang.fr: 'Destinataire',
      AppLang.de: 'Empfänger',
      AppLang.en: 'Recipient',
    },
    'step.details': {
      AppLang.fr: 'Détails de l’envoi',
      AppLang.de: 'Angaben zur Sendung',
      AppLang.en: 'Shipment details',
    },
    'carrier.other': {
      AppLang.fr: 'Autre',
      AppLang.de: 'Andere',
      AppLang.en: 'Other',
    },
    'carrier.other.name': {
      AppLang.fr: 'Nom du transporteur',
      AppLang.de: 'Name des Transporteurs',
      AppLang.en: 'Carrier name',
    },
    'search.hint': {
      AppLang.fr: 'Nom, prénom ou service',
      AppLang.de: 'Name, Vorname oder Abteilung',
      AppLang.en: 'Last name, first name or department',
    },
    'search.where': {
      AppLang.fr: 'Sur le bon de livraison, le nom figure sous « Votre référence » ou « Ihr Zeichen ».',
      AppLang.de: 'Auf dem Lieferschein steht der Name unter „Ihr Zeichen" oder „Votre référence".',
      AppLang.en: 'On the delivery note, the name appears under "Votre référence" or "Ihr Zeichen" (your reference).',
    },
    'search.min': {
      AppLang.fr: 'Saisir au moins 2 lettres',
      AppLang.de: 'Mindestens 2 Zeichen eingeben',
      AppLang.en: 'Enter at least 2 letters',
    },
    'search.none': {
      AppLang.fr: 'Aucun destinataire trouvé',
      AppLang.de: 'Keine Empfänger gefunden',
      AppLang.en: 'No recipient found',
    },
    'search.change': {
      AppLang.fr: 'Changer',
      AppLang.de: 'Ändern',
      AppLang.en: 'Change',
    },
    'quantity': {
      AppLang.fr: 'Nombre',
      AppLang.de: 'Anzahl',
      AppLang.en: 'Quantity',
    },
    'kind.parcel': {
      AppLang.fr: 'Colis',
      AppLang.de: 'Paket',
      AppLang.en: 'Parcel',
    },
    'kind.pallet': {
      AppLang.fr: 'Palette',
      AppLang.de: 'Palette',
      AppLang.en: 'Pallet',
    },
    'kind.letter': {
      AppLang.fr: 'Courrier recommandé',
      AppLang.de: 'Eingeschriebener Brief',
      AppLang.en: 'Registered letter',
    },
    'kind.chilled': {
      AppLang.fr: 'Marchandise réfrigérée',
      AppLang.de: 'Kühlware',
      AppLang.en: 'Chilled goods',
    },
    'kind.label': {
      AppLang.fr: 'Type',
      AppLang.de: 'Art',
      AppLang.en: 'Type',
    },
    'location.label': {
      AppLang.fr: 'À retirer à',
      AppLang.de: 'Abholort',
      AppLang.en: 'Pick up at',
    },
    'location.reception': {
      AppLang.fr: 'Réception',
      AppLang.de: 'Empfang',
      AppLang.en: 'Reception',
    },
    'location.dock': {
      AppLang.fr: 'Quai de chargement',
      AppLang.de: 'Laderampe',
      AppLang.en: 'Loading dock',
    },
    'location.coldroom': {
      AppLang.fr: 'Chambre froide',
      AppLang.de: 'Kühlraum',
      AppLang.en: 'Cold room',
    },
    'note.label': {
      AppLang.fr: 'Remarque (facultatif)',
      AppLang.de: 'Bemerkung (optional)',
      AppLang.en: 'Remark (optional)',
    },
    'chilled.warning': {
      AppLang.fr: 'Marchandise réfrigérée : le destinataire reçoit une alerte urgente.',
      AppLang.de: 'Kühlware: Der Empfänger erhält eine dringende Meldung.',
      AppLang.en: 'Chilled goods: the recipient receives an urgent alert.',
    },
    'scan.button': {
      AppLang.fr: 'Scanner le code-barres',
      AppLang.de: 'Barcode scannen',
      AppLang.en: 'Scan barcode',
    },
    'scan.title': {
      AppLang.fr: 'Code-barres du colis',
      AppLang.de: 'Barcode des Pakets',
      AppLang.en: 'Parcel barcode',
    },
    'scan.hint': {
      AppLang.fr: 'Tenir le code-barres devant la caméra.',
      AppLang.de: 'Barcode vor die Kamera halten.',
      AppLang.en: 'Hold the barcode in front of the camera.',
    },
    'scan.error': {
      AppLang.fr: 'Caméra indisponible – continuer sans scanner.',
      AppLang.de: 'Kamera nicht verfügbar – ohne Scan weiterfahren.',
      AppLang.en: 'Camera unavailable – continue without scanning.',
    },
    'tracking.label': {
      AppLang.fr: 'Numéro d’envoi',
      AppLang.de: 'Sendungsnummer',
      AppLang.en: 'Tracking number',
    },
    'send': {
      AppLang.fr: 'Envoyer la notification',
      AppLang.de: 'Benachrichtigung senden',
      AppLang.en: 'Send notification',
    },
    'sending': {
      AppLang.fr: 'Envoi en cours…',
      AppLang.de: 'Wird gesendet…',
      AppLang.en: 'Sending…',
    },
    'success.title': {
      AppLang.fr: 'Notification envoyée',
      AppLang.de: 'Benachrichtigung gesendet',
      AppLang.en: 'Notification sent',
    },
    'success.body': {
      AppLang.fr: '{name} vient d’être informé.',
      AppLang.de: '{name} wurde informiert.',
      AppLang.en: '{name} has just been informed.',
    },
    'success.next': {
      AppLang.fr: 'Nouvel envoi',
      AppLang.de: 'Neue Sendung',
      AppLang.en: 'New delivery',
    },
    'error.title': {
      AppLang.fr: 'Envoi impossible',
      AppLang.de: 'Senden nicht möglich',
      AppLang.en: 'Sending failed',
    },
    'error.list': {
      AppLang.fr: 'La liste du personnel n’a pas pu être lue. Prévenir l’informatique.',
      AppLang.de: 'Die Personalliste liess sich nicht lesen. IT informieren.',
      AppLang.en: 'The staff list could not be read. Please inform IT.',
    },
    'error.notconfigured': {
      AppLang.fr: 'Le terminal n’est pas encore configuré pour l’envoi. Prévenir l’informatique.',
      AppLang.de: 'Das Terminal ist noch nicht für den Versand eingerichtet. IT informieren.',
      AppLang.en: 'The terminal is not yet set up for sending. Please inform IT.',
    },
    'error.mailauth': {
      AppLang.fr: 'Le serveur de messagerie refuse l’utilisateur ou le mot de passe.',
      AppLang.de: 'Der Mailserver weist Benutzer oder Passwort zurück.',
      AppLang.en: 'The mail server rejects the user name or password.',
    },
    'error.mail': {
      AppLang.fr: 'La notification n’a pas pu être envoyée. Prévenir le destinataire par téléphone.',
      AppLang.de: 'Die Benachrichtigung konnte nicht gesendet werden. Empfänger telefonisch informieren.',
      AppLang.en: 'The notification could not be sent. Please inform the recipient by phone.',
    },
    'retry': {
      AppLang.fr: 'Réessayer',
      AppLang.de: 'Nochmals versuchen',
      AppLang.en: 'Try again',
    },
    'close': {
      AppLang.fr: 'Fermer',
      AppLang.de: 'Schliessen',
      AppLang.en: 'Close',
    },
    'admin.title': {
      AppLang.fr: 'Réglages',
      AppLang.de: 'Einstellungen',
      AppLang.en: 'Settings',
    },
    'admin.pin.title': {
      AppLang.fr: 'Code administrateur',
      AppLang.de: 'Administrator-Code',
      AppLang.en: 'Administrator code',
    },
    'admin.pin.wrong': {
      AppLang.fr: 'Code incorrect',
      AppLang.de: 'Falscher Code',
      AppLang.en: 'Wrong code',
    },
    'admin.pin.set': {
      AppLang.fr: 'Définir le code administrateur',
      AppLang.de: 'Administrator-Code festlegen',
      AppLang.en: 'Set the administrator code',
    },
    'admin.pin.short': {
      AppLang.fr: 'Au moins 4 chiffres',
      AppLang.de: 'Mindestens 4 Ziffern',
      AppLang.en: 'At least 4 digits',
    },
    'admin.pin.change': {
      AppLang.fr: 'Modifier le code',
      AppLang.de: 'Code ändern',
      AppLang.en: 'Change the code',
    },
    'admin.kinds': {
      AppLang.fr: 'Types d’envoi',
      AppLang.de: 'Sendungsarten',
      AppLang.en: 'Shipment types',
    },
    'admin.locations': {
      AppLang.fr: 'Lieux de retrait',
      AppLang.de: 'Abholorte',
      AppLang.en: 'Pick-up locations',
    },
    'admin.mailbox': {
      AppLang.fr: 'Boîte commune',
      AppLang.de: 'Gemeinsames Postfach',
      AppLang.en: 'Shared mailbox',
    },
    'admin.mailbox.hint': {
      AppLang.fr: 'Vide : aucune copie, et « destinataire inconnu » reste masqué.',
      AppLang.de: 'Leer: keine Kopie, und „Empfänger unbekannt" bleibt ausgeblendet.',
      AppLang.en: 'Empty: no copy, and "recipient unknown" stays hidden.',
    },
    'admin.add': {
      AppLang.fr: 'Ajouter',
      AppLang.de: 'Hinzufügen',
      AppLang.en: 'Add',
    },
    'admin.name': {
      AppLang.fr: 'Désignation interne',
      AppLang.de: 'Interne Bezeichnung',
      AppLang.en: 'Internal name',
    },
    'admin.name.hint': {
      AppLang.fr: 'Vide : désignation standard',
      AppLang.de: 'Leer: Standardbezeichnung',
      AppLang.en: 'Empty: standard name',
    },
    'admin.urgent': {
      AppLang.fr: 'Annonce urgente',
      AppLang.de: 'Eilmeldung',
      AppLang.en: 'Urgent alert',
    },
    'admin.delete': {
      AppLang.fr: 'Supprimer',
      AppLang.de: 'Löschen',
      AppLang.en: 'Delete',
    },
    'admin.reset': {
      AppLang.fr: 'Tout réinitialiser',
      AppLang.de: 'Alles zurücksetzen',
      AppLang.en: 'Reset everything',
    },
    'admin.builtin.hint': {
      AppLang.fr: 'Les entrées standard se masquent, elles ne se suppriment pas.',
      AppLang.de: 'Standardeinträge lassen sich ausblenden, nicht löschen.',
      AppLang.en: 'Standard entries can be hidden, not deleted.',
    },
    'admin.staff': {
      AppLang.fr: 'Liste du personnel',
      AppLang.de: 'Personalliste',
      AppLang.en: 'Staff list',
    },
    'admin.staff.hint': {
      AppLang.fr: 'Colonnes : name,email,department,lang — lang vaut fr, de ou en.',
      AppLang.de: 'Spalten: name,email,department,lang – lang ist fr, de oder en.',
      AppLang.en: 'Columns: name,email,department,lang — lang is fr, de or en.',
    },
    'admin.staff.builtin': {
      AppLang.fr: 'Liste livrée avec l’application : {count} personnes',
      AppLang.de: 'Mitgelieferte Liste: {count} Personen',
      AppLang.en: 'List shipped with the app: {count} people',
    },
    'admin.staff.own': {
      AppLang.fr: 'Liste propre à ce terminal : {count} personnes',
      AppLang.de: 'Eigene Liste dieses Terminals: {count} Personen',
      AppLang.en: 'This terminal’s own list: {count} people',
    },
    'admin.staff.import': {
      AppLang.fr: 'Charger un fichier CSV',
      AppLang.de: 'CSV-Datei einlesen',
      AppLang.en: 'Load a CSV file',
    },
    'admin.staff.reset': {
      AppLang.fr: 'Revenir à la liste livrée',
      AppLang.de: 'Mitgelieferte Liste verwenden',
      AppLang.en: 'Use the shipped list',
    },
    'admin.staff.ok': {
      AppLang.fr: '{count} personnes lues.',
      AppLang.de: '{count} Personen eingelesen.',
      AppLang.en: '{count} people imported.',
    },
    'admin.staff.empty': {
      AppLang.fr: 'Aucune ligne exploitable — la liste précédente reste en place.',
      AppLang.de: 'Keine brauchbare Zeile – die bisherige Liste bleibt bestehen.',
      AppLang.en: 'No usable row — the previous list stays in place.',
    },
    'admin.mailupdate': {
      AppLang.fr: 'Mise à jour de la liste par e-mail',
      AppLang.de: 'Listen-Update per E-Mail',
      AppLang.en: 'List update by e-mail',
    },
    'admin.mailupdate.hint': {
      AppLang.fr: 'Le terminal relève cette boîte et reprend la liste des e-mails dont l’objet contient le code — CSV en pièce jointe ou dans le texte.',
      AppLang.de: 'Das Terminal ruft dieses Postfach ab und übernimmt die Liste aus E-Mails, deren Betreff den Code enthält – CSV als Anhang oder im Text.',
      AppLang.en: 'The terminal checks this mailbox and takes the list from e-mails whose subject contains the code – CSV as attachment or in the text.',
    },
    'admin.mailupdate.user': {
      AppLang.fr: 'Utilisateur',
      AppLang.de: 'Benutzer',
      AppLang.en: 'User',
    },
    'admin.mailupdate.ssl': {
      AppLang.fr: 'SSL (port 993)',
      AppLang.de: 'SSL (Port 993)',
      AppLang.en: 'SSL (port 993)',
    },
    'admin.mailupdate.secret': {
      AppLang.fr: 'Code secret (objet de l’e-mail)',
      AppLang.de: 'Geheimcode (im Betreff)',
      AppLang.en: 'Secret code (in the subject)',
    },
    'admin.mailupdate.clean': {
      AppLang.fr: 'Supprimer les anciens e-mails de liste',
      AppLang.de: 'Alte Listen-Mails automatisch löschen',
      AppLang.en: 'Delete old list e-mails automatically',
    },
    'admin.mailupdate.clean.hint': {
      AppLang.fr: 'Seul le dernier e-mail de liste reste dans la boîte — les listes dépassées sont des données personnelles dont personne n’a plus besoin.',
      AppLang.de: 'Nur die neuste Listen-Mail bleibt im Postfach – überholte Listen sind Personendaten, die niemand mehr braucht.',
      AppLang.en: 'Only the latest list e-mail stays in the mailbox – outdated lists are personal data nobody needs any more.',
    },
    'admin.mailupdate.check': {
      AppLang.fr: 'Vérifier maintenant',
      AppLang.de: 'Jetzt prüfen',
      AppLang.en: 'Check now',
    },
    'admin.mailupdate.ok': {
      AppLang.fr: '{count} personnes reprises de l’e-mail.',
      AppLang.de: '{count} Personen aus der E-Mail übernommen.',
      AppLang.en: '{count} people taken from the e-mail.',
    },
    'admin.mailupdate.none': {
      AppLang.fr: 'Aucun nouvel e-mail avec le code.',
      AppLang.de: 'Keine neue E-Mail mit dem Code.',
      AppLang.en: 'No new e-mail with the code.',
    },
    'admin.mailupdate.fail': {
      AppLang.fr: 'Relève impossible : {error}',
      AppLang.de: 'Abruf fehlgeschlagen: {error}',
      AppLang.en: 'Check failed: {error}',
    },
    'mailupdate.confirm.subject': {
      AppLang.fr: 'Liste du personnel mise à jour – {count} personnes – {terminal}',
      AppLang.de: 'Personalliste aktualisiert – {count} Personen – {terminal}',
      AppLang.en: 'Staff list updated – {count} people – {terminal}',
    },
    'mailupdate.confirm.body': {
      AppLang.fr: 'Le terminal {terminal} a repris {count} personnes de votre e-mail.',
      AppLang.de: 'Das Terminal {terminal} hat {count} Personen aus Ihrer E-Mail übernommen.',
      AppLang.en: 'Terminal {terminal} has taken over {count} people from your e-mail.',
    },
    'admin.smtp': {
      AppLang.fr: 'Envoi des e-mails',
      AppLang.de: 'E-Mail-Versand',
      AppLang.en: 'E-mail sending',
    },
    'admin.smtp.hint': {
      AppLang.fr: 'Le terminal envoie lui-même : le chauffeur ne voit aucune application e-mail.',
      AppLang.de: 'Das Terminal versendet selbst – der Fahrer sieht keine E-Mail-App.',
      AppLang.en: 'The terminal sends by itself – the driver never sees an e-mail app.',
    },
    'admin.smtp.host': {
      AppLang.fr: 'Serveur',
      AppLang.de: 'Server',
      AppLang.en: 'Server',
    },
    'admin.smtp.port': {
      AppLang.fr: 'Port',
      AppLang.de: 'Port',
      AppLang.en: 'Port',
    },
    'admin.smtp.user': {
      AppLang.fr: 'Utilisateur (vide = relais interne)',
      AppLang.de: 'Benutzer (leer = internes Relais)',
      AppLang.en: 'User (empty = internal relay)',
    },
    'admin.smtp.password': {
      AppLang.fr: 'Mot de passe',
      AppLang.de: 'Passwort',
      AppLang.en: 'Password',
    },
    'admin.smtp.ssl': {
      AppLang.fr: 'SSL direct (port 465)',
      AppLang.de: 'Direktes SSL (Port 465)',
      AppLang.en: 'Direct SSL (port 465)',
    },
    'admin.smtp.from': {
      AppLang.fr: 'Adresse d’expédition',
      AppLang.de: 'Absenderadresse',
      AppLang.en: 'Sender address',
    },
    'admin.smtp.fromname': {
      AppLang.fr: 'Nom affiché',
      AppLang.de: 'Angezeigter Name',
      AppLang.en: 'Display name',
    },
    'admin.smtp.show': {
      AppLang.fr: 'Afficher le mot de passe',
      AppLang.de: 'Passwort anzeigen',
      AppLang.en: 'Show the password',
    },
    'admin.smtp.test': {
      AppLang.fr: 'Envoyer un test',
      AppLang.de: 'Testmeldung senden',
      AppLang.en: 'Send a test',
    },
    'admin.smtp.test.ok': {
      AppLang.fr: 'Test envoyé. Vérifier la boîte de réception.',
      AppLang.de: 'Test verschickt. Posteingang prüfen.',
      AppLang.en: 'Test sent. Check the inbox.',
    },
    'admin.smtp.test.target': {
      AppLang.fr: 'Le test part à l’adresse d’expédition.',
      AppLang.de: 'Der Test geht an die Absenderadresse.',
      AppLang.en: 'The test goes to the sender address.',
    },
    'admin.terminal': {
      AppLang.fr: 'Nom de ce terminal',
      AppLang.de: 'Name dieses Terminals',
      AppLang.en: 'Name of this terminal',
    },
    'admin.terminal.hint': {
      AppLang.fr: 'P. ex. F11 ou Réception — figure dans chaque annonce. Ainsi plusieurs terminaux restent distinguables.',
      AppLang.de: 'Z. B. F11 oder Empfang – steht in jeder Meldung. So bleiben mehrere Terminals unterscheidbar.',
      AppLang.en: 'E.g. F11 or Reception – appears in every notice, so several terminals stay distinguishable.',
    },
    'admin.location.ask': {
      AppLang.fr: 'Demander le lieu de retrait',
      AppLang.de: 'Abholort abfragen',
      AppLang.en: 'Ask for the pick-up location',
    },
    'admin.location.hint': {
      AppLang.fr: 'Désactivé : le chauffeur ne choisit pas où va le colis, il ne peut pas le savoir.',
      AppLang.de: 'Aus: Der Fahrer wählt nicht, wohin die Sendung gehört – er kann es nicht wissen.',
      AppLang.en: 'Off: the driver does not choose where the parcel goes – they cannot know.',
    },
    'admin.save': {
      AppLang.fr: 'Enregistrer',
      AppLang.de: 'Speichern',
      AppLang.en: 'Save',
    },
    'admin.empty': {
      AppLang.fr: 'Au moins une entrée doit rester visible.',
      AppLang.de: 'Mindestens ein Eintrag muss sichtbar bleiben.',
      AppLang.en: 'At least one entry must remain visible.',
    },
    'phone.title': {
      AppLang.fr: 'Contacts téléphoniques',
      AppLang.de: 'Telefonkontakte',
      AppLang.en: 'Phone contacts',
    },
    'phone.button': {
      AppLang.fr: 'Téléphone',
      AppLang.de: 'Telefon',
      AppLang.en: 'Phone',
    },
    'recipient.free': {
      AppLang.fr: 'Utiliser « {name} » quand même',
      AppLang.de: '„{name}" trotzdem verwenden',
      AppLang.en: 'Use "{name}" anyway',
    },
    'recipient.free.hint': {
      AppLang.fr: 'L’annonce part à la boîte commune, avec ce nom.',
      AppLang.de: 'Die Meldung geht mit diesem Namen an das gemeinsame Postfach.',
      AppLang.en: 'The notice goes to the shared mailbox, with this name.',
    },
    'recipient.unknown': {
      AppLang.fr: 'Destinataire inconnu',
      AppLang.de: 'Empfänger unbekannt',
      AppLang.en: 'Recipient unknown',
    },
    'recipient.unknown.hint': {
      AppLang.fr: 'L’annonce part uniquement à la boîte commune.',
      AppLang.de: 'Die Meldung geht nur an das gemeinsame Postfach.',
      AppLang.en: 'The notice goes only to the shared mailbox.',
    },
    'success.body.unknown': {
      AppLang.fr: 'L’annonce est prête dans l’application e-mail.',
      AppLang.de: 'Die Meldung liegt in der E-Mail-App bereit.',
      AppLang.en: 'The notice is ready in the e-mail app.',
    },
    'mail.subject': {
      AppLang.fr: 'Livraison pour vous – {carrier}',
      AppLang.de: 'Lieferung für Sie – {carrier}',
      AppLang.en: 'Delivery for you – {carrier}',
    },
    'mail.subject.unknown': {
      AppLang.fr: 'Livraison sans destinataire – {carrier}',
      AppLang.de: 'Lieferung ohne Empfänger – {carrier}',
      AppLang.en: 'Delivery without recipient – {carrier}',
    },
    'mail.subject.name': {
      AppLang.fr: 'Livraison pour {name} – {carrier}',
      AppLang.de: 'Lieferung für {name} – {carrier}',
      AppLang.en: 'Delivery for {name} – {carrier}',
    },
    'mail.intro.name': {
      AppLang.fr: 'Une livraison au nom de {name} est arrivée à la réception de Cressier. Cette personne ne figure pas dans la liste du terminal – merci de transmettre.',
      AppLang.de: 'Am Empfang Cressier ist eine Lieferung auf den Namen {name} eingetroffen. Diese Person steht nicht in der Liste des Terminals – bitte weiterleiten.',
      AppLang.en: 'A delivery in the name of {name} has arrived at the Cressier reception. This person is not in the terminal’s list – please forward.',
    },
    'mail.urgent.prefix': {
      AppLang.fr: '[URGENT] ',
      AppLang.de: '[DRINGEND] ',
      AppLang.en: '[URGENT] ',
    },
    'mail.intro': {
      AppLang.fr: 'Bonjour {name}, une livraison est arrivée à votre nom à la réception de Cressier.',
      AppLang.de: 'Guten Tag {name}, am Empfang Cressier ist eine Lieferung auf Ihren Namen eingetroffen.',
      AppLang.en: 'Hello {name}, a delivery in your name has arrived at the Cressier reception.',
    },
    'mail.intro.unknown': {
      AppLang.fr: 'Une livraison est arrivée à la réception de Cressier sans nom de destinataire.',
      AppLang.de: 'Am Empfang Cressier ist eine Lieferung ohne Empfängernamen eingetroffen.',
      AppLang.en: 'A delivery without a recipient name has arrived at the Cressier reception.',
    },
    'mail.terminal': {
      AppLang.fr: 'Terminal',
      AppLang.de: 'Terminal',
      AppLang.en: 'Terminal',
    },
    'mail.carrier': {
      AppLang.fr: 'Transporteur',
      AppLang.de: 'Transporteur',
      AppLang.en: 'Carrier',
    },
    'mail.recipient': {
      AppLang.fr: 'Destinataire',
      AppLang.de: 'Empfänger',
      AppLang.en: 'Recipient',
    },
    'mail.note': {
      AppLang.fr: 'Remarque',
      AppLang.de: 'Bemerkung',
      AppLang.en: 'Remark',
    },
    'mail.time': {
      AppLang.fr: 'Annoncé le',
      AppLang.de: 'Gemeldet am',
      AppLang.en: 'Announced on',
    },
    'mail.urgentNote': {
      AppLang.fr: 'Marchandise réfrigérée : merci de venir la chercher immédiatement, la chaîne du froid ne peut pas être garantie à la réception.',
      AppLang.de: 'Kühlware: Bitte sofort abholen – am Empfang kann die Kühlkette nicht eingehalten werden.',
      AppLang.en: 'Chilled goods: please collect immediately – the cold chain cannot be maintained at the reception.',
    },
    'mail.footer': {
      AppLang.fr: 'Message automatique du terminal de réception de Cressier.',
      AppLang.de: 'Automatische Meldung des Empfangsterminals Cressier.',
      AppLang.en: 'Automatic message from the Cressier reception terminal.',
    },
    'phone.failed': {
      AppLang.fr: 'Composer le numéro manuellement.',
      AppLang.de: 'Nummer manuell wählen.',
      AppLang.en: 'Dial the number manually.',
    },
  };
}
