# Kuyena-Startseite aus Figma

Stand: 26.10.2026.
Vorlage: [Home, Frame 18:2](https://www.figma.com/design/v4DO4nPi6aG16MkUwAcgoT/Kuyena?node-id=18-2).

## Was umgesetzt wird

Die Startseite wird als Flutter-Oberfläche umgesetzt. Sie verwendet die
Original-SVGs für Kopfbereich, Zyklusring, Symbole und Plusknopf aus Figma.
Die Schrift Nunito Sans liegt mit OFL-Lizenz lokal im Projekt. Die Seite
benötigt zum Anzeigen dieser Gestaltung keine externen Asset- oder
Schriftanfragen. Das Design ist 412 × 917; auf schmalen Geräten wird das
Layout angepasst und bei geringer Höhe scrollbar. Ab 900 Pixeln Breite
erscheint eine Webansicht mit seitlicher Navigation und zwei Spalten für
Datumsrad/Zyklusring und Informationen. Eine schmale Browseransicht verwendet
weiter das mobile Layout.

Die Datumsleiste verwendet echte Kalendertage. Die kleine Kennzeichnung
„Demo“ erklärt, dass Zyklusphase, Beschwerden und Bewegungsideen Beispieldaten
sind. Der Kreis verwendet jetzt die tatsächlich gespeicherten Perioden und
zeigt den Tageswert für das ausgewählte Datum. Die übrigen Beispielwerte
werden weder aus Gesundheitsdaten berechnet noch als Einträge gespeichert.
Der Countdown ist jetzt eine persönliche Median-Schätzung aus mindestens
drei Periodenbeginnen. Individuelle Bewegungsempfehlungen sind weiterhin offen.

## Bedienung

- Beim Öffnen steht das heutige Datum mittig am höchsten Punkt des Bogens
  und ist rosa hinterlegt. Links und rechts stehen jeweils die zwei
  benachbarten Kalendertage.
- Wischen, Ziehen mit der Maus oder Scrollen über dem Datumsrad verschiebt
  die Auswahl. Sie rastet wieder mittig ein. Ein Nachbartag kann auch direkt
  angetippt werden. Der Bogen wird während der Bewegung laufend angepasst.
- Monat und Jahr der Auswahl werden angezeigt. „Heute“ setzt die Auswahl
  auf den aktuellen Kalendertag zurück. Home hat dieselbe Rücksetzfunktion.
- Die Webansicht bietet zusätzlich Pfeile für vorherigen/nächsten Tag.
  Ein fokussiertes Datumsrad ist auch über linke/rechte Pfeiltaste bedienbar.
- Eine geänderte Tagesauswahl berechnet den Tageswert im Kreis neu. Sie
  verändert keine gespeicherten Einträge. Ein vorhandener Countdown wird
  für den ausgewählten Tag neu berechnet.
- Calendar und Cycle öffnen vorerst den vorhandenen Periodenverlauf.
- Der zentrale Plusknopf öffnet nach erfolgreichem Laden des Verlaufs die
  Eingabemaske für Beginn und optionales Ende. Abbrechen speichert nichts. Bei einem
  Ladefehler beginnt keine neue Erfassung.
- For you und die Bewegungskarte zeigen den Hinweis, dass noch keine
  persönlichen Empfehlungen vorliegen.
- Demo und die beiden kleinen Infokarten erklären die Beispieldaten.
- Der Kreis erklärt beim Antippen die dokumentierten Angaben und deren
  Berechnung. Ohne Eintrag öffnet er die Erfassung; bei Lesefehler lädt er neu.

Die originale iOS-Statusleiste und der Homeindikator dienen im Browser als
Darstellungsrahmen. Auf einem echten Handy liefert das Betriebssystem
seine Statusanzeige und Navigation.

## Die Dateien einfach erklärt

- `lib/home/presentation/kuyena_home_page.dart` setzt die sichtbaren
  Bausteine zusammen und verbindet die Navigation mit bestehenden Abläufen.
- `lib/home/presentation/home_design.dart` bündelt Farben und Schriftstil.
- `lib/home/presentation/curved_date_slider.dart` stellt das bewegliche
  Datumsrad dar. Ein `PageController` steuert, welcher Tag mittig steht.
  Fünf Tagesfelder teilen die sichtbare Breite; der Abstand zur Mitte
  bestimmt, wie tief das jeweilige Feld auf dem Bogen liegt.
- `lib/home/presentation/home_desktop_layout.dart` ordnet dieselben
  Funktionen für breite Browserfenster an.
- `lib/home/presentation/period_status_ring.dart` zeigt Tagesnummer,
  dokumentiertes Ende und einen daraus berechneten Ringanteil.
- `lib/main.dart` öffnet die neue Startseite beim App-Start.
- `assets/home/` enthält die Originalgrafiken aus Figma.
- `assets/fonts/` enthält die Schrift und ihre Lizenz.
- Der bestehende Periodenverlauf erhält eine optionale Funktion, beim
  Öffnen direkt die Periodenerfassung zu starten. Seine Speicher- und
  Fachlogik bleibt an den bisherigen Stellen.

Ein ungefährer nächster Beginn wird aus persönlichen Startabständen
berechnet und als Schätzung gekennzeichnet.
Die am 26.10.2026 angeschlossene Enddatum-Eingabe ist im
[Periodenmodell](periodenmodell.md) erklärt; die Verwendung im Kreis unter
[Periodentag](periodentag.md).

Die Datumsrechnung verwendet Jahr, Monat und Tag. Für die Reihenfolge der
Tagesfelder werden diese Werte intern auf UTC-Kalendertage abgebildet, damit
Sommer-/Winterzeit keine Tage überspringt. Dabei wird kein beobachtetes Datum
aus einer lokalen Uhrzeit nach UTC verschoben. Monats-, Jahreswechsel und
Schalttage folgen den gültigen Kalenderdaten.

## Prüfung der Erweiterung

Bei der Umsetzung am 22.10.2026 bestanden 39 automatisierte Tests, einschließlich Tagespositionen,
Wischen, Antippen, Mausrad, Pfeiltasten, Zeitumstellung, Monats- und
Jahreswechsel sowie Erhalt der Auswahl beim Wechsel der Fensterbreite.
Die Codeprüfung meldet keine Probleme. Die Browserfassung wurde gebaut
und die schmale Ansicht sowie die Webansicht bei 1440 × 1000 visuell geprüft.
Ein Ziehen des Datumsrads und die Rückkehr über „Heute“ wurden auch im
Browser ausprobiert. Ein Test auf einem echten Handy steht weiter aus.

## KI-Nutzung

Codex hat das Figma-Design über den Figma-Connector ausgelesen und anhand
des Screenshots und der detaillierten Designinformationen in Flutter/Dart
übertragen. Dafür wurde der Skill `figma-design-to-code` verwendet.
Die Umsetzung umfasst Navigation, lokale Originalgrafiken und Schrift,
sowie Prüfungen für Vorschau und bestehenden Erfassungsablauf.

Ergänzung am 22.10.2026: Codex hat nach der Erläuterung der nutzenden Person
das statische Datumsbeispiel durch ein bewegliches Datumsrad ersetzt und
eine breite Webansicht ergänzt. Regeln für Positionierung, Wischbewegung,
Mausrad, Tastatur, Datumssprünge und bestehende Speicherung werden geprüft.

Ergänzung am 26.10.2026: Der Plusknopf öffnet jetzt die Eingabemaske für
vollständige Perioden mit optionalem Ende. Die aktuelle Prüfung umfasst
57 Tests für Darstellung, Fachlogik und Speicherung.

Weitere Ergänzung am 26.10.2026: Codex hat den Kreis an die gespeicherten
Perioden angeschlossen. Tageswerte und dokumentierter Fortschritt ersetzen
das feste Beispiel „3 Days“. Die übrigen Designkarten bleiben Beispiele.

Weitere Anpassung: Der Bogen baut sich oben beginnend im Uhrzeigersinn auf.
Er ist bei bestätigter Periode rot, sonst hellrosa. Außerhalb einer
bestätigten Periode erscheint bei ausreichenden Einträgen „Noch ca. N Tage“
bis zum geschätzten nächsten Beginn. Ohne genug Beginne gibt es keine
erfundene Standardlänge. „Periode läuft noch“ kann ausdrücklich erfasst
werden; alte unbekannte Enden bleiben unbekannt. Details stehen unter
[Periodentag und Countdown](periodentag.md).
