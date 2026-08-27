# label_scanner

Barcode-Etiketten scannen und **den richtigen Code** auswählen — nicht
irgendeinen, der zufällig zuerst erkannt wird.

```dart
final nummer = await LabelScannerScreen.open(context);                    // Paket
final vin    = await LabelScannerScreen.open(context, rule: LabelCodeRule.vin);
```

Hängt nur an `flutter` und `mobile_scanner`. Sprache, Farben und die Regel,
was als gültiger Code zählt, kommen von aussen.

Erprobt an Paketetiketten (Post CH, DPD, FedEx) und an Fahrzeug-Etiketten
mit VIN.

---

## Das Problem

Auf einem Etikett steht selten nur ein Code.

**Paketetikett Post CH** trägt drei:

| Code | Inhalt | Beispiel |
|---|---|---|
| grosser Strichcode | Sendungsnummer | `99.60.131482.38551546` |
| kleiner Strichcode neben «PRI» | Leitcode, vier Stellen | `2307` |
| DataMatrix (manche Absender) | Retourendaten | — |

**Fahrzeug-Etikett** trägt QR-Code, Strichcode und Klartext nebeneinander.

Die naheliegende Lösung — den ersten Treffer der Kamera nehmen — ist
Glückssache. Im Betrieb kam so `2307` statt der achtzehnstelligen Nummer in
der Meldung an. **Und niemand merkte es**, weil `2307` wie eine Nummer
aussieht.

Der teure Fehler ist nicht der Absturz. Es ist das plausible falsche
Ergebnis.

---

## Die Lösung

```dart
String? pickBestCode(List<Barcode> barcodes, {LabelCodeRule rule})
```

Eine reine Funktion, die **auswählt statt greift**. Und die `null`
zurückgibt, wenn nichts passt — dann wird weitergesucht, statt das
Nächstbeste zu melden.

Eine `LabelCodeRule` beschreibt, was gemeint ist:

| | `LabelCodeRule.parcel` | `LabelCodeRule.vin` |
|---|---|---|
| Mindestlänge | 8 | 17 |
| Prüfung | keine | Prüfziffer nach ISO 3779 |
| Flächencodes (QR, DataMatrix …) | ausgeschlossen | zugelassen |

Der Kniff steckt in der letzten Zeile: **eine Regel mit Prüfung kann es sich
leisten, überall zu suchen**, weil ein falscher Fund ohnehin durchfällt. Eine
Regel ohne Prüfung muss vorsichtig sein und sich auf Strichcodes
beschränken — sonst gewinnt ein Herstellerdatensatz aus dem QR-Code, bloss
weil er länger ist.

### Paket

Acht Zeichen lassen DHL (ab 10 Stellen), GLS (11), DPD (14), UPS und
Post CH (18) durch; der vierstellige Leitcode fällt an der Grenze durch.
Eine echte Prüfung gibt es nicht — jeder Transporteur nummeriert anders.

### VIN

Anders als eine Sendungsnummer **kann sich eine VIN selbst beweisen**:

- 17 Zeichen,
- festes Alphabet ohne `I`, `O` und `Q` (verwechselbar mit 1 und 0),
- Prüfziffer an Stelle 9 (ISO 3779).

Ein einzelnes verlesenes Zeichen fällt damit auf:

```dart
isValidVin('KL4CJESB8KB924970')   // true  – vom Etikett
isValidVin('KL4CJE5B8KB924970')   // false – S als 5 gelesen
isValidVin('KL4CJESB8KB924870')   // false – 9 als 8 gelesen
```

⚠️ **Fahrzeuge aus Europa und Asien führen die Prüfziffer nicht immer
korrekt**, in Nordamerika ist sie Pflicht. Fallen eure Etiketten durch,
obwohl die Nummer stimmt, nehmt eine eigene Regel mit der schwächeren
Prüfung:

```dart
const meineRegel = LabelCodeRule(
  minLength: 17,
  accept: isVinShaped,   // nur Länge und Alphabet, keine Prüfziffer
  areaFormats: true,
);
```

### Eigene Regel

`accept` muss eine benannte Funktion sein, wenn die Regel `const` sein soll —
ein Lambda ist keine Konstante:

```dart
final _artikel = RegExp(r'^ART-\d+$');
bool isArtikelnummer(String v) => _artikel.hasMatch(v);

const artikelnummer = LabelCodeRule(minLength: 6, accept: isArtikelnummer);
```

Mit einem Lambda geht es auch, dann aber ohne `const`:

```dart
final artikelnummer = LabelCodeRule(
  minLength: 6,
  accept: (v) => v.startsWith('ART-'),
);
```

---

## Einbauen

### 1. Abhängigkeit

```yaml
dependencies:
  label_scanner:
    git:
      url: https://github.com/GianniTGT/Frigemo-Post-ist-da-app.git
      path: packages/label_scanner
```

Das Paket liegt als Unterordner in einem groesseren Repository, deshalb das
`path:`. Zieht es spaeter in ein eigenes Repository um, faellt die Zeile weg.

`minSdkVersion` muss mindestens **21** sein.

### 2. Kamera-Berechtigung

Android: `mobile_scanner` bringt `android.permission.CAMERA` selbst mit, es
ist nichts einzutragen. iOS/macOS brauchen `NSCameraUsageDescription` in der
`Info.plist`.

### 3. ⚠️ R8 — sonst stürzt der Scanner im Release ab

**Das ist der Punkt, der einen halben Tag kostet, wenn man ihn nicht kennt.**

Im Debug-Build läuft alles. Im **Release**-Build scheitert der Kamerastart:

```
Attempt to invoke virtual method 'java.lang.Class java.lang.Object.getClass()'
on a null object reference
```

Das ist die Handschrift von R8. Die Barcode-Erkennung (MLKit) lädt ihre
Bausteine per Namens-Nachschlag zur Laufzeit; R8 sieht keine direkte
Verwendung und entfernt sie. Beim Start ist dann intern etwas `null`.

`mobile_scanner` liefert zwar eigene ProGuard-Regeln mit
(`consumerProguardFiles`), aber die erste Zeile lautet:

```
-keep class com.google.mlkit.* { *; }
```

Ein einzelnes `*` deckt **nur eine Paketebene** ab —
`com.google.mlkit.vision.barcode.internal.…` fällt durch das Raster. Deshalb
reichen die mitgelieferten Regeln nicht.

**Der Weg, der nachweislich auf dem Gerät läuft:** Schrumpfung im
Release-Build ausschalten.

```kotlin
// android/app/build.gradle.kts
buildTypes {
    release {
        isMinifyEnabled = false
        isShrinkResources = false
    }
}
```

```groovy
// android/app/build.gradle  (Groovy-Variante)
buildTypes {
    release {
        minifyEnabled false
        shrinkResources false
    }
}
```

Für ein Kiosk- oder Werkzeug-Programm ist die eingesparte APK-Grösse ohne
Wert; Verlässlichkeit schlägt Schrumpfung.

**Wenn dir die Grösse wichtig ist**, wäre die engere Variante eine breitere
Keep-Regel in `android/app/proguard-rules.pro`:

```
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.internal.mlkit_vision_barcode.** { *; }
```

Ehrlich dazu: **diese Variante ist nicht auf einem Gerät verifiziert.** Sie
folgt logisch aus der Ursache (`*` statt `**`), mehr nicht. Wenn du sie
nimmst, prüf den Scanner in einem echten Release-Build — im Debug läuft auch
die kaputte Variante.

### 4. Wenn `android/` bei dir generiert wird

Liegt `android/` nicht im Repository, sondern entsteht bei jedem Build neu
durch `flutter create`, muss die Änderung aus Schritt 3 bei jedem Lauf neu
hinein. Dafür eignet sich ein Patch-Skript, das

- **idempotent** ist (zweimal laufen ändert nichts),
- **abbricht**, wenn es sein Suchmuster nicht findet — sonst merkt niemand,
  dass eine neue Flutter-Fassung die Vorlage geändert hat und der Patch ins
  Leere läuft,
- im Prüflauf **zweimal** aufgerufen wird, damit genau das getestet ist.

---

## Fehlerbildschirm

Der eingebaute Fehlerbildschirm von `mobile_scanner` zeigt im Release
grundsätzlich nur «An unexpected error occurred» — den wirklichen Grund
druckt er ausschliesslich unter `kDebugMode`. Damit lässt sich vor Ort nichts
beheben.

Dieser Baustein bringt einen eigenen mit: Grund im Klartext (bei fehlender
Berechtigung mit dem Weg in die Android-Einstellungen), darunter klein der
technische Pfad:

```
genericError · error · Attempt to invoke virtual method …
```

Diese kleine Zeile hat den R8-Fehler oben überhaupt erst gefunden.
`genericError` allein sagt nichts — dahinter stecken mehrere Pfade, die sich
nur an der Detail-Meldung der Plattform unterscheiden. **Lass die Zeile
drin.**

---

## Tests

```
flutter test
```

Geprüft werden `pickBestCode`, `isValidVin` und `isVinShaped` mit Werten von
echten Etiketten — ohne Kamera, ohne Gerät, ohne Widget.

Das ist der Grund, warum die Auswahl aus dem Bildschirm herausgelöst ist: der
Teil, der schiefgehen kann, ist eine reine Funktion und lässt sich in
Millisekunden prüfen. Der Rest ist Darstellung.

---

## Was der Baustein bewusst *nicht* tut

- **Er formatiert nichts.** Post CH druckt `99.60.131482.38551546`, der
  Barcode enthält `996013148238551546`. Punkte einzusetzen hiesse, das Format
  eines Transporteurs fest zu verdrahten. Mach das in deiner Anzeigeschicht.
- **Er schlägt nichts nach.** Aus einer VIN liesse sich Marke, Modell und
  Baujahr auflösen — das ist ein Dienst im Netz, nicht Sache eines Scanners.
- **Er hält nichts auf.** Der Scan ist freiwillig; ein Abbruch gibt `null`
  zurück und lässt alles beim Alten.
