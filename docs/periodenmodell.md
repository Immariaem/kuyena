# Vom Datenmodell zum Code: die Periode

Aktueller Speicherstand vom 29.10.2026: [Gemeinsame lokale Datenbasis, Sicherung und Wiederherstellung](lokale-datenbasis.md). Die folgenden Abschnitte dokumentieren den jeweiligen früheren Meilenstein.

Stand: 26.10.2026. Die Klasse „Periode“ aus unserem logischen Datenmodell
ist in Dart umgesetzt und mit Eingabemaske und lokaler Speicherung verbunden.

## Was ist jetzt vorhanden?

Die neue Klasse liegt in `lib/periods/domain/period.dart`. Im Code heißt sie
`Period`, passend zu den bereits englischen Namen `CalendarDate` und
`PeriodDiary`. Die Begriffe entsprechen sich so:

| Datenmodell | Dart-Code | Bedeutung |
| --- | --- | --- |
| Periode | `Period` | Vorlage für eine dokumentierte Periode. |
| Kennung | `String id` | Text, an dem derselbe Eintrag wiedererkannt wird. |
| Beginn | `CalendarDate start` | Erster dokumentierter Tag. |
| Ende | `CalendarDate? end` | Letzter dokumentierter Tag, falls bekannt. |
| Läuft noch | `bool isOngoing` | Ausdrücklich bestätigte laufende Periode; ein unbekanntes Ende allein genügt nicht. |

Eine Kennung darf nicht leer sein. Der Anwendungsservice vergibt für neue
Einträge zufällige Kennungen und verhindert, dass eine bereits vorhandene
Kennung überschrieben wird. Dafür werden 16 zufällige Bytes verwendet;
es ist kein zusätzliches Paket nötig. Die Beispielkennung `periode-1`
wird nicht automatisch für neue Einträge verwendet. Ihre Vergabe ist ein
technisches Detail, das die Klasse selbst nicht festlegt.

## Den Code Schritt für Schritt lesen

1. `import 'calendar_date.dart';` macht den vorhandenen Datumsbaustein
   verfügbar. Er prüft bereits, ob ein Kalendertag tatsächlich existiert,
   beispielsweise ob der Februar in diesem Jahr einen 29. Tag hat.
2. `final class Period` eröffnet die Vorlage für eine Periode.
   Eine Klasse ist wie eine leere Karteikartenvorlage. Eine mit konkreten
   Daten ausgefüllte Karte ist ein Objekt dieser Klasse. `final class`
   verhindert hier zusätzlich, dass andere Bibliotheken Varianten durch
   Vererbung oder Implementierung dieser Klasse erstellen.
3. `Period({required this.id, required this.start, this.end})` ist der
   Konstruktor: der Eingang zum Erstellen einer solchen Karte. Kennung
   und Beginn sind Pflichtangaben; das Ende kann fehlen. Die geschweiften
   Klammern bedeuten, dass die Angaben beim Aufruf benannt werden.
4. `id.trim().isEmpty` erkennt auch eine Kennung, die nur Leerzeichen
   enthält. `throw ArgumentError(...)` lehnt die Erstellung mit einer
   verständlichen Fehlermeldung ab.
5. `final endDate = end;` gibt dem optionalen Ende für die folgende Prüfung
   einen lokalen Namen.
6. `endDate != null` fragt, ob ein Ende angegeben wurde. `null` heißt
   „kein Wert vorhanden“. Das bedeutet hier „Ende unbekannt“ und sagt
   nicht aus, dass eine Blutung noch andauert.
7. `endDate.compareTo(start) < 0` erkennt ein Ende vor dem Beginn. Auch
   dann wird die Erstellung abgelehnt. Derselbe Tag ist erlaubt.
8. Die drei `final`-Felder halten die Angaben. Nach dem Erstellen kann
   niemand ein einzelnes Feld direkt überschreiben und dabei die Prüfung
   umgehen. Zusammen mit dem unveränderlichen `CalendarDate` bleiben
   die Angaben dieses Objekts unveränderlich.
9. `correctDates(...)` erstellt für eine Korrektur ein neu geprüftes
   Objekt mit derselben Kennung. Das bisherige Objekt bleibt erhalten.
   `=>` ist die Kurzschreibweise für „gib dieses Ergebnis zurück“.
   Beginn und Ende müssen dabei ausdrücklich übergeben werden. Für ein
   unbekanntes Ende wird `end: null` angegeben.

Die Regel zum Enddatum gehört zur Periode selbst, weil sie ausschließlich
deren eigene Angaben betrifft. Dadurch wird sie bei jedem Erstellen und
Korrigieren geprüft. Das entspricht der Schichtenarchitektur aus Workshop 2.
Die Klasse benötigt weder Flutter noch einen Speicherzugriff.

## Beispiel mit erfundenen Angaben

```dart
final periode = Period(
  id: 'periode-1',
  start: CalendarDate(2026, 10, 3),
);

final mitEnde = periode.correctDates(
  start: periode.start,
  end: CalendarDate(2026, 10, 7),
);
```

Die erste Karte enthält einen Beginn und ein unbekanntes Ende. Die zweite
enthält zusätzlich den 07.10.2026 als Ende. Beide tragen dieselbe Kennung.
Ein Ende am 02.10.2026 wäre für diesen Beginn ungültig und würde abgelehnt.
Dieses Beispiel erzeugt nur Objekte im Arbeitsspeicher; es speichert nichts.

## Anschluss an die App

So lässt sich ein Ende jetzt angeben:

1. Auf Home den Plusknopf drücken oder im Verlauf „Periode eintragen“ wählen.
2. Den Beginn auswählen. Das heutige Datum ist zunächst vorausgewählt.
3. Unter „Ende (optional)“ den letzten Periodentag auswählen oder das Feld
   offenlassen. Das Ende kann zwischen Beginn und heute liegen.
4. Mit „Speichern“ bestätigen. Erst dann wird der Entwurf übernommen.

Zusätzlich kann „Periode läuft noch“ aktiviert werden. Diese Markierung
setzt das Ende im Entwurf auf unbekannt. Die Wahl eines Enddatums beendet
die Markierung. Beides gleichzeitig lehnt auch die Fachklasse ab.
Bestehende Einträge bekommen die Markierung nicht automatisch.

Das aktuelle Speicherformat Version 3 ergänzt dafür `ongoing` als booleschen
Wert. Version 1 und 2 bleiben ohne Schreibzugriff lesbar und erhalten
zunächst `false`. Erst bestätigtes Speichern übernimmt in Version 3.
Die folgenden Erläuterungen zu Version 2 beschreiben den vorherigen
Meilenstein. Die aktuelle [Animation und Schätzung](periodentag.md)
verwenden diese Angaben.

Bei bestehenden Perioden öffnet „Korrigieren“ dieselbe Maske mit den
gespeicherten Angaben. Ein Ende kann später ergänzt, geändert oder über
„Ende entfernen“ wieder als unbekannt angegeben werden. „Abbrechen“
verwirft den Entwurf. Fehler werden in der geöffneten Maske erklärt;
die Eingaben bleiben zum Korrigieren erhalten.

Die beteiligten Bausteine haben jeweils eine Aufgabe:

| Baustein | Aufgabe |
| --- | --- |
| `PeriodEntryDialog` | Sammelt Beginn und optionales Ende als Entwurf. |
| `PeriodDiary` | Lädt den aktuellen Verlauf, prüft Zukunft und doppelte Beginne, vergibt Kennungen und steuert das Speichern. |
| `Period` | Prüft, ob Ende und Beginn zusammenpassen; Korrekturen behalten die Kennung. |
| `PeriodRepository` | Beschreibt den Speicherzugriff mit vollständigen Perioden. |
| `LocalPeriodRepository` | Übersetzt Perioden in das lokale Dokument und zurück. |

Die bisherige Regel zu beobachteten Starttagen wird auf das Ende übertragen:
Auch ein dokumentiertes Ende darf nicht nach heute liegen. Eine Vorhersage
eines zukünftigen Datums wäre ein anderer Vorgang.

## Bereits gespeicherte Einträge übernehmen

Das neue Dokumentformat (Version 2) enthält je Periode `id`, `start` und
`end`; ein unbekanntes Ende wird als `null` gespeichert. Das ursprüngliche
Format (Version 1) enthielt ausschließlich eine Liste von Startdaten.

Beim Lesen alter Daten bleiben alle Beginne erhalten. Sie bekommen im
Arbeitsspeicher stabile Kennungen `legacy-JJJJ-MM-TT` und ein unbekanntes
Ende. Ein bloßes Öffnen verändert das gespeicherte Dokument nicht. Erst
beim nächsten erfolgreichen Speichervorgang wird der gesamte aktuelle
Verlauf einschließlich dieser Einträge in Version 2 geschrieben. Eine
Datumskorrektur behält die Kennung auch dann, wenn der ursprüngliche Tag
noch Teil einer alten Kennung ist.

Der bisherige Speicherschlüssel bleibt absichtlich erhalten, damit die
vorhandenen Daten weiterhin gefunden werden. Nach einem Lesefehler werden
keine Änderungen gespeichert. Ungültige oder unbekannte Dokumente bleiben
erhalten und werden nicht automatisch durch eine leere Sammlung ersetzt.
Die ausdrücklich bestätigte Löschfunktion steht weiterhin zur Verfügung.

Die Regeln für Überschneidungen, Symptomauswahl und Vorhersagen sind damit
noch nicht festgelegt. Eine Prüfung gegen „heute“ gehört weiterhin zum
Anwendungsablauf, der die aktuelle Zeit kennt.

## Prüfungen

`test/periods/period_test.dart` prüft mit erfundenen Angaben: unbekanntes
Ende, gleicher Beginn und gleicher Endtag, Ende vor Beginn, leere Kennung,
Korrektur mit gleicher Kennung, Ergänzen und Entfernen des Endes sowie
eine abgelehnte Korrektur unter Erhalt der ursprünglichen Angaben.

Am 26.10.2026 in einer getrennten Projektkopie ausgeführt:

- `flutter test --no-pub --reporter expanded`: alle 57 Tests bestanden,
  einschließlich der sieben Tests für `Period`, Übernahme des alten
  Speicherformats, Enddatum nach Neuladen, Ergänzen/Entfernen eines Endes,
  Abbrechen, Korrektur und Erhalt der Eingaben bei Fehlern.
- `flutter analyze --no-pub`: keine Probleme gefunden.
- `flutter build web --no-pub --no-web-resources-cdn`: erfolgreich.
- Browseransicht auf getrenntem lokalen Testport geprüft: Beginn und Ende
  sind auswählbar, ein gespeicherter Eintrag mit Ende ist nach Neuladen
  weiterhin vorhanden. Doppelte Beginne werden in der geöffneten Maske
  erklärt, ohne die Eingaben zu verwerfen.

Die Tests verwenden ausschließlich erfundene Angaben und einen
Test-Speicher. Die Prüfung auf echten Android-/iOS-Geräten steht weiter aus.

## KI-Nutzung

26.10.2026: Codex hat anhand des gemeinsam erarbeiteten LDM und der
Workshop-2-Unterlagen die Klasse `Period`, die genannten Prüfbeispiele
und diese Erklärung erstellt. Anschließend hat Codex auf Wunsch der
nutzenden Person die optionale Enddatum-Eingabe, den Anwendungsablauf,
die Übernahme der alten Daten und die Speicherung vollständiger Perioden
ergänzt und die genannten Prüfungen ausgeführt.
