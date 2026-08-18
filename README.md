# Frigemo – Post ist da / Le courrier est arrivé

Terminal de réception pour le site de Cressier : la réception annonce une livraison
en trois gestes, le destinataire reçoit un e-mail dans sa langue.

Langue par défaut du terminal : **français**, commutable en allemand par le bouton
en haut à droite. La langue de l'e-mail suit celle du destinataire (colonne `lang`
de la liste du personnel), pas celle du terminal.

```
Frigemo-Post-ist-da-app/
├── app/                    Terminal Flutter (écran tactile réception)
│   ├── lib/config.dart         paramètres --dart-define, transporteurs, contacts
│   ├── lib/l10n.dart           textes FR/DE
│   ├── lib/api_service.dart    HTTP, timeouts, erreurs typées
│   └── lib/screens/…           écran principal
└── server/                 API Node.js + envoi d'e-mails
    ├── src/index.js            routes REST
    ├── src/employees.js        liste du personnel (CSV, rechargée à chaud)
    ├── src/db.js               journal SQLite des livraisons
    └── src/mailer.js           modèles FR/DE, SMTP
```

## Serveur

```bash
cd server
cp .env.example .env          # adapter SMTP + clés
cp data/employees.example.csv data/employees.csv
npm install
npm start
```

`MAIL_DRY_RUN=true` affiche les e-mails dans la console au lieu de les envoyer —
à utiliser pour tous les tests avant de brancher le SMTP de frigemo.

### Routes

| Méthode | Route | Auth | Rôle |
|---|---|---|---|
| GET | `/api/health` | – | état du serveur, nombre d'employés chargés |
| GET | `/api/employees?q=…` | `x-api-key` terminal | recherche, min. 2 lettres, max. 25 résultats |
| POST | `/api/deliveries` | `x-api-key` terminal | enregistre puis notifie |
| GET | `/api/deliveries?limit=…` | `x-api-key` admin | journal d'audit |

La recherche est **serveur uniquement** : le terminal ne reçoit jamais la liste
complète et les adresses e-mail ne quittent pas le serveur. La livraison est
d'abord écrite en base, puis l'e-mail part ; si le SMTP échoue, la réponse
contient `mailStatus: "failed"` et le terminal demande d'avertir par téléphone.

### Liste du personnel

`server/data/employees.csv` — colonnes `id,name,email,department,lang,active`.
Le fichier est relu automatiquement à chaque modification, sans redémarrage.
Étape suivante conseillée : remplacer ce CSV par un export nocturne de l'AD ou
de SAP HR, le reste du code ne change pas (`employees.js` seul).

## Terminal

```bash
cd app
flutter pub get
flutter run -d linux \
  --dart-define=API_BASE_URL=http://10.20.30.40:3000/api \
  --dart-define=API_KEY=… \
  --dart-define=TERMINAL_ID=cressier-reception-1 \
  --dart-define=DEFAULT_LANGUAGE=fr
```

Aucune adresse n'est codée en dur : une nouvelle IP serveur ne demande qu'un
nouveau build, pas une modification du code.

### Comportement en exploitation

- **Serveur injoignable** : bandeau orange permanent en haut, avec renvoi vers
  les contacts téléphoniques. Vérifié toutes les 30 s.
- **Inactivité 90 s** : le formulaire se vide, personne n'envoie une annonce au
  nom de la personne précédente.
- **Destinataire** : la sélection est annulée dès qu'on retape dans le champ.
- **Marchandise réfrigérée** : lieu de retrait forcé sur chambre froide, e-mail
  prioritaire, sujet préfixé `[URGENT]`, copie possible à la logistique
  (`MAIL_URGENT_CC`).
- **Échec d'envoi** : dialogue explicite avec bouton « Réessayer ».

## Points ouverts

- Numéros de téléphone dans `app/lib/config.dart` : ce sont des exemples.
- Le SMTP de frigemo doit autoriser l'IP du serveur en relais interne, ou
  utiliser un compte Microsoft 365 dédié (dans ce cas `SMTP_SECURE=true`, port 587).
- Prévoir un service systemd et une sauvegarde de `server/data/deliveries.db`.
- Effacement du journal : définir une durée de conservation (protection des
  données), p. ex. suppression automatique après 12 mois.
