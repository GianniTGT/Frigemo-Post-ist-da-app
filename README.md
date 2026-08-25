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

## Comment l'envoi fonctionne

**C'est le chauffeur qui utilise le terminal**, pas la réception. Tout découle
de là : il ne doit voir aucune autre application, il ne doit rien décider qu'il
ne puisse savoir, et l'annonce doit partir sans qu'il ait à confirmer ailleurs.

Le terminal n'a **pas de serveur**. La liste du personnel est un fichier dans
l'application, et le terminal **envoie lui-même** par SMTP :

1. le chauffeur choisit le transporteur, le nombre et le destinataire ;
2. « Envoyer » expédie l'annonce directement ;
3. l'écran de confirmation n'apparaît qu'une fois le serveur de messagerie
   ayant accepté l'envoi.

Le chauffeur ne voit jamais de boîte de réception, et la confirmation dit la
vérité — contrairement à une ouverture d'application e-mail, où un envoi
abandonné passerait pour réussi.

Les identifiants sont saisis dans les réglages et restent dans la mémoire
privée de l'application sur la tablette ; **ils ne sont pas dans l'APK**.

Aucune intervention de l'informatique de frigemo n'est nécessaire : envoyer
*vers* frigemo.ch ne demande rien. Une boîte externe dédiée (Gmail, Outlook.com
ou un domaine propre) suffit, et son dossier « Envoyés » tient lieu d'archive.
Seul le filtre anti-spam du destinataire peut poser problème ; cela se voit dès
le premier essai.

Trois cas pour le destinataire :

- **trouvé dans la liste** — l'annonce part à cette personne, la boîte commune
  en copie ;
- **un nom sur le colis, absent de la liste** (nouvel employé, temporaire,
  externe, faute de frappe sur l'étiquette) — le chauffeur reprend le nom tel
  qu'il l'a saisi ; l'annonce part à la boîte commune **avec ce nom**, à
  transmettre. Jeter ce nom serait perdre le plus utile de l'annonce ;
- **aucun nom** — « Destinataire inconnu », l'annonce part uniquement à la
  boîte commune.

Les deux derniers cas exigent une boîte commune ; sans elle, ils restent
masqués.

### Lieu de retrait

Désactivé par défaut : le chauffeur ne peut pas savoir où le colis doit aller
dans l'usine. Réactivable dans les réglages si le site en a l'usage.

### Liste du personnel

Deux sources possibles.

**La liste livrée** — `app/assets/employees.csv`, colonnes
`name,email,department,lang`. Modifiable directement sur github.com, sans
toucher au code ; il faut ensuite reconstruire l'APK.

**Une liste propre au terminal** — dans les réglages, « Charger un fichier
CSV » lit un fichier depuis la tablette. Elle remplace alors la liste livrée,
et se met à jour sans reconstruire l'APK. C'est la voie pour un deuxième site
ou un autre client : un seul APK, chacun sa liste.

Un fichier sans ligne exploitable est refusé — la liste précédente reste en
place plutôt que de laisser la réception devant une recherche vide.

**Les noms livrés sont des exemples et doivent être remplacés.**

La colonne `lang` (`fr` ou `de`) décide de la langue de l'e-mail pour cette
personne, indépendamment de la langue du terminal.

### Réglages sur la tablette

Un appui long sur le logo, puis le code administrateur, ouvre les réglages.

**Il n'y a pas de code par défaut** — un code fixe dans le code source serait
lisible dans ce dépôt public. Au premier accès, le terminal demande d'en
définir un (4 chiffres au moins). Pour livrer une tablette déjà protégée,
déposer le secret `ADMIN_PIN` : il sert alors de code de départ. Tout y est enregistré sur la tablette : aucun
nouvel APK n'est nécessaire pour ces changements.

- **Types d'envoi et lieux de retrait** : masquer, renommer avec la
  désignation interne du site, ou ajouter des entrées propres à Cressier.
  Les entrées standard se masquent seulement — elles restent récupérables.
  Le courrier recommandé est masqué par défaut.
- **Annonce urgente** : le drapeau qui déclenche `[URGENT]` et le renvoi vers
  la chambre froide. Réglable aussi sur une entrée propre, pour un secteur
  réfrigéré interne.
- **Boîte commune** : voir ci-dessous.

Une désignation interne remplace la traduction dans les deux langues : les
noms internes ne se traduisent pas.

### Boîte commune

Cette adresse reçoit chaque annonce en copie, et devient le seul destinataire
quand aucun nom ne figure sur le colis.

**Par défaut il n'y en a aucune**, parce que `paketistda@frigemo.ch` n'existe
pas encore : sans adresse, rien ne part vers une boîte morte, et l'option
« Destinataire inconnu » reste masquée.

Elle se saisit dans les réglages de la tablette. La variable `MAIL_FALLBACK`
(Settings → Secrets and variables → Actions) ne sert que de valeur de départ
au premier démarrage.

## Serveur (plus utilisé)

Le dossier `server/` vient de la première version, où la recherche et l'envoi
passaient par une API. Il n'est plus utilisé par le terminal et reste là au cas
où l'envoi automatique redeviendrait souhaitable.



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

## Publication de l'APK

Le workflow `.github/workflows/release-apk.yml` construit l'APK et l'attache à
une release. Il démarre sur un tag `v*` ou manuellement (« Run workflow »).

La release est créée **en brouillon** : le dépôt est public, alors que l'APK
contient `TERMINAL_API_KEY` — les valeurs `--dart-define` sont compilées dans
le binaire et s'en extraient. Un brouillon n'est visible et téléchargeable que
par les personnes ayant accès au dépôt, ce qui suffit pour installer sur la
tablette. Avant de publier une release au sens propre, il faut soit passer le
dépôt en privé, soit sortir la clé du build (saisie sur le terminal au premier
démarrage, par exemple).

Le build ne demande aucune configuration obligatoire. Deux variables
facultatives, sous **Settings → Secrets and variables → Actions** :

| Type | Nom | Contenu |
|---|---|---|
| Variable | `MAIL_FALLBACK` | boîte commune, p. ex. `paketistda@frigemo.ch` |
| Variable | `DEFAULT_LANGUAGE` | `fr` (défaut) ou `de` |

Les anciennes variables `API_BASE_URL`, `TERMINAL_ID` et le secret
`TERMINAL_API_KEY` ne servent plus depuis la suppression du serveur et peuvent
être effacées.

### Contrôle sur les pull requests

Une pull request qui touche `.github/**` ou `app/**` déclenche le même
workflow, mais il s'arrête après `flutter analyze`, les tests et le test du
script de signature : rien n'est construit, rien n'est publié. Une erreur dans
le workflow ou dans le code de l'application se voit donc sur la pull request,
et non au moment de poser le tag.

Si le gabarit Gradle de Flutter change sans qu'une pull request ne soit
ouverte, le problème n'apparaîtra qu'au build suivant — un déclencheur
hebdomadaire (`schedule`) comblerait cet écart si besoin.

### Installation et mises à jour

**Sans keystore propre, chaque build est signé avec une clé de debug
différente** — le runner en génère une neuve à chaque fois. Android refuse
alors d'installer par-dessus : il faut désinstaller l'ancienne version, ce qui
efface les réglages (accès SMTP compris).

Déposer les secrets de signature (voir ci-dessous) résout cela : toutes les
versions partagent la même signature, les mises à jour s'installent
par-dessus et les réglages survivent.

Le numéro de version est affiché en bas des réglages, pour vérifier d'un coup
d'œil quelle version tourne réellement sur la tablette.

### Signature

Le dossier `app/android/` n'est pas versionné : il est régénéré à chaque build.
Sans keystore, l'APK est signé avec la clé de debug — installable, mais un
passage ultérieur à une clé propre imposera une réinstallation sur la tablette.

Pour signer avec une clé de production, ajouter les secrets `KEYSTORE_BASE64`
(le fichier `.keystore` encodé en base64), `KEYSTORE_PASSWORD`, `KEY_ALIAS` et
`KEY_PASSWORD`. Le workflow injecte alors la configuration dans le Gradle
généré (`.github/scripts/inject_signing.py`) et vérifie ensuite que l'APK n'est
pas signé avec la clé de debug ; les mots de passe passent par des variables
d'environnement et ne sont écrits dans aucun fichier.

## Points ouverts

- Numéros de téléphone dans `app/lib/config.dart` : ce sont des exemples.
- Côté terminal, seuls `l10n.dart` et la bascule de langue sont testés
  (`app/test/widget_test.dart`) ; l'écran lui-même dépend du réseau et de
  minuteries, et demanderait un montage de test à part.
- Côté serveur, aucun test automatisé pour l'instant.
- Le SMTP de frigemo doit autoriser l'IP du serveur en relais interne, ou
  utiliser un compte Microsoft 365 dédié (dans ce cas `SMTP_SECURE=true`, port 587).
- Prévoir un service systemd et une sauvegarde de `server/data/deliveries.db`.
- Effacement du journal : définir une durée de conservation (protection des
  données), p. ex. suppression automatique après 12 mois.
