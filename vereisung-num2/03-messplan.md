# Messplan

Grundsatz: **erst messen, dann investieren.** Förderer und Luftschleier sind
sinnvolle Massnahmen, aber teuer. Wenn die Ursache eine undichte Durchführung
oder ein Regelungsfehler ist, bringt ein Luftschleier für viel Geld wenig.

## Stufe 1 — sofort, ohne Externe

| Nr. | Messung / Prüfung | Zweck | Prüft | Verantwortlich | Status |
|---|---|---|---|---|---|
| 1.1 | Reglerauslesung Gruppe 2: Sollwerte, Abtauzyklen, Laufzeiten, Abtauendtemperaturen | Ist-Parameter gegen Sollzustand vor der Reinigung | H1, H2 | Kani | offen |
| 1.2 | Alarm- und Störungshistorie seit 25.07. | Ventilator-, Abtau- oder Fühlerstörung im Zeitfenster finden | H2 | Kani | offen |
| 1.3 | Sichtkontrolle aller Verdampferventilatoren der Zone | Ausgefallenen oder nicht wieder angelaufenen Ventilator finden | H2 | Kani / Betrieb | offen |
| 1.4 | Sichtprüfung Paneelfugen, Silikon, Kabel- und Rohrdurchführungen, Leiterbefestigungen — mit Fotodokumentation | Leckstellen und Schäden aus der Reinigung finden | H3, H5 | Kani mit Hervé | offen |
| 1.5 | Sichtprüfung Druckausgleichsventil | Blockierung oder Vereisung feststellen | H4 | Kani | offen |
| 1.6 | Datenlogger 7 Tage: Raumtemperatur, relative Feuchte, Türöffnungen Tor 8 **und** Tor 9 | Feuchteeintrag quantifizieren und Louis' Hypothese überprüfbar machen | H6, H1 | Kani | offen |
| 1.7 | Wetterdaten Cressier 01.–31.08., Taupunktverlauf | Witterung als Auslöser ausschliessen oder bestätigen | H7 | Kani | offen |

**Wichtig zu 1.6:** Die Messwoche muss im **Normalbetrieb** laufen. Wenn der
Betrieb während der Messung besonders vorsichtig fährt, messen wir einen
Sonderzustand und lernen nichts. Das ist Hervé und den Teams vorher zu sagen.

## Stufe 2 — gemeinsame Begehung mit SSP und Wettstein

Beide am **selben Termin**, damit sich Anlage und Gebäudehülle nicht
gegenseitig den Ball zuspielen.

| Nr. | Messung | Zweck | Prüft | Wer | Status |
|---|---|---|---|---|---|
| 2.1 | Thermografie Wand und Decke, innen und aussen | Kältebrücken und Leckstellen sichtbar machen | H3, H5 | Wettstein | offen |
| 2.2 | Leckage-/Rauchtest bei laufender Anlage | Lufteintritt an Fugen und Durchführungen nachweisen | H3, H8 | Wettstein | offen |
| 2.3 | Differenzdruckmessung Zelle gegen Nachbarzone | Unterdruck nachweisen | H4, H8 | Wettstein | offen |
| 2.4 | Prüfung Verdampfer, Abtauung, Ablauf und Ablaufheizung | Fehlfunktion oder Fehlregelung nachweisen | H1, H2 | SSP | offen |
| 2.5 | Prüfung Fühlerlage und Regelstrategie | Fehlregelung durch Fühlerposition ausschliessen | H1 | SSP | offen |
| 2.6 | Luftführung und Luftmengen der Zone | Toter Bereich im Leiterbereich nachweisen | H2, H8 | SSP | offen |

## Stufe 3 — Massnahmen mit Wirkungskontrolle

Erst wenn die Ursache belegt ist:

1. Abdichten bzw. Regelung anpassen
2. **Danach** erneut reinigen — nicht vorher
3. Kontrolle nach 2 Wochen und nach 6 Wochen, mit Foto vom selben Standort
4. Ergebnis in `05-massnahmen.md` eintragen

Wird vor der Ursachenklärung erneut gereinigt, zahlen wir denselben Betrag ein
drittes Mal.
