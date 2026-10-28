# Die sieben Figma-Entwürfe

Stand: 28.10.2026. Die bestehenden Periodenangaben werden weiterverwendet.

| Figma-Knoten | Ansicht in Flutter | Bedienung |
| --- | --- | --- |
| 207:1758 | Kalender-Ansichtsmenü | Day, Month und Year auswählen; außerhalb klicken oder Escape zum Schließen |
| 24:3174 | Calendar | Monate in beide Richtungen scrollen, Tag für Details wählen; Jahresansicht öffnet einen Monat |
| 24:3486 | Recommendations | Zwei horizontale Kartenreihen; Karten öffnen die allgemeine Idee |
| 24:3415 | Cycle & App | Echte Mittelwerte, Periodenverlauf, Einstellungen, Export, Löschen und Informationen |
| 60:940 | Log your day | Blutungsstärke, mehrere Symptome, Stimmung, Energie und Notiz erfassen und bearbeiten |
| 207:1773 | Startbildschirm | Originalgrafiken und sechs Logo-Vektoren; öffnet nach 1,4 Sekunden Home, Tippen überspringt ihn |
| 60:571 | Choose a date | Datum auswählen, Monate wechseln, mit Continue zum Tageseintrag; zukünftige Beobachtungen sind gesperrt |

Schrift, Farben und bereits vorhandene Home-Bausteine werden wiederverwendet. Originalbilder und SVGs sind lokal unter `assets/screens/` gebündelt. Zur Laufzeit werden keine Figma-URLs aufgerufen. Bis 899 Pixel bleibt die schmale Anordnung erhalten; ab 900 Pixel gibt es eine seitliche Navigation und mehr Inhaltsbreite. Lange Inhalte bleiben scrollbar. Die englischen Texte stammen aus den Entwürfen; die bestehende deutsche Periodenerfassung bleibt erreichbar.

## Vom Entwurf zur Funktion – einfach erklärt

Die Navigation verbindet die Seiten miteinander. Mit dem Plus wählst du zuerst ein Datum und füllst dann den Tageseintrag aus. Speichern legt die Angaben auf diesem Gerät ab. Beim erneuten Öffnen desselben Datums kommen diese Angaben wieder ins Formular. Erst ein erneutes Speichern übernimmt Änderungen. Beim Verlassen eines geänderten Entwurfs fragt die App nach, ob er verworfen werden soll.

Das Formular entspricht den Auswahlmöglichkeiten im Figma-Entwurf: Flow = None/Light/Medium/Heavy; Symptome = Cramps/Headache/Fatigue/Breast tenderness; Stimmung = Good/Okay/Low. Der Energieregler wird als Ganzzahl von 0 bis 100 gespeichert, ohne medizinische Bewertung. Alle Angaben sind optional. Ein neuer Tag enthält zunächst keine vorausgewählten Beobachtungen; der unberührte Regler zählt ebenfalls nicht als gemessene Energie. Mindestens eine tatsächliche Angabe oder Notiz ist zum Speichern nötig.

Ein Datum hat in diesem umgesetzten Formular genau einen bearbeitbaren Tageseintrag. Ein Symptom kann darin einmal ausgewählt werden; mehrere verschiedene Symptome sind möglich. Tageseinträge brauchen keine zugeordnete Periode. Das Löschen eines Tageseintrags entfernt seine Symptome, Stimmung, Energie und Notiz gemeinsam. Andere Tage und Periodenangaben bleiben bestehen.

## Zwei getrennte Arten von Einträgen

- **Perioden:** Beginn, optionales Ende und ausdrücklich „läuft noch“. Die bisherige Speicherung einschließlich älterer Formate bleibt erhalten. Unter Cycle → Edit cycle data lassen sich diese Angaben verwalten. Auch der Kreis auf Home führt weiterhin zu diesen Periodenangaben.
- **Tageseinträge:** Beobachtungen für ein konkretes Datum. Eine einzelne Blutungsstärke setzt nicht automatisch Beginn oder Ende einer Periode. Der Kreis verwendet weiterhin die ausdrücklich dokumentierten Periodendaten.

Im Kalender bedeutet die rote Fläche: dokumentierter Periodentag. Ein unbekanntes Ende färbt nur den dokumentierten Beginn; eine ausdrücklich laufende Periode reicht bis heute. Der umrandete Tag ist heute. Ein kleiner Punkt markiert einen vorhandenen Tageseintrag. Tagesdetails zeigen die tatsächlich gespeicherten Angaben; Beispieldaten aus Figma werden nicht als persönliche Beobachtung gespeichert.

Cycle & App zeigt den arithmetischen Mittelwert der dokumentierten Start-zu-Start-Abstände. Abstände nach einer noch laufend markierten oder mit dem nächsten Beginn überlappenden Periode werden ausgelassen. Die durchschnittliche Periodendauer verwendet nur Einträge mit bekanntem Ende und zählt beide Randtage. Der bestehende Home-Countdown verwendet dagegen den Median der jüngsten Abstände; das ist eine andere Kennzahl und wird in den Details erklärt.

## Speicher und Datenschutz

`DayEntry` beschreibt die Angaben; `DayJournal` koordiniert Laden, Speichern und Löschen. `LocalJournalRepository` verwaltet ein eigenes versioniertes Dokument über den bestehenden Speicherzugang. Dadurch bleiben UI und Speicher getrennt und mit Testdaten prüfbar.

Die Schlüssel sind `kuyena.period_starts.v1` für die bestehenden Perioden und `kuyena.day_journal.v1` für Tageseinträge und die Erinnerungseinstellung. Das neue Dokument hat Version 1. Beschädigte oder unbekannte Dokumente werden nicht als leere Daten interpretiert und nicht durch einen neuen Eintrag überschrieben. Schreib- und Löschvorgänge werden durch Rücklesen bestätigt. Gleichzeitige Änderungen werden innerhalb derselben Journal-Instanz nacheinander ausgeführt; mehrere Browser-Tabs werden nicht gegenseitig gesperrt.

Ein Export liest beide Quellen erneut, zeigt JSON an und kopiert es auf ausdrücklichen Knopfdruck in die Zwischenablage. Es wird noch keine Datei automatisch heruntergeladen oder geteilt. Falls Kopieren nicht verfügbar ist, kann der Text manuell markiert werden. Ein Export enthält die Angaben im Klartext. „Delete all local data“ löscht nach Bestätigung beide Dokumente einschließlich Erinnerungseinstellung. Da sie getrennt liegen, wird ein unvollständiger Löschvorgang ausdrücklich gemeldet und der aktuelle Stand neu geladen.

Im Browser bleibt die bestehende Einschränkung des experimentellen Secure-Storage-Web-Plugins bestehen: Browserprofil und Website-Adresse einschließlich Port bestimmen den Speicher; das Löschen von Website-Daten kann Einträge entfernen. Für den Prototyp Testdaten verwenden. Es gibt keine Konten, Cloud-Synchronisierung oder externe Übertragung von Gesundheitsangaben.

## Bewusst begrenzte Funktionen

- **Reminders:** Die Einstellung wird gespeichert. Wenn für heute noch kein Tageseintrag vorliegt, erscheint auf Home eine Erinnerung innerhalb der geöffneten App. Es werden keine Push- oder Betriebssystem-Benachrichtigungen geplant. Der Hinweis wird beim Öffnen von Home, nach einer Rückkehr und beim Wiederaufnehmen der App neu geprüft; er ist kein Hintergrunddienst.
- **Recommendations:** Originalbilder und allgemeine Ideen aus Figma. Es wird keine Zyklusphase aus Symptomen abgeleitet und keine individuelle medizinische Ernährung oder Bewegung verordnet. Die Karten weisen auf ihren allgemeinen Charakter hin.
- **Home:** Die bisherigen Karten zu Phase, möglichen Beschwerden und Bewegung sind weiterhin gekennzeichnete Designbeispiele. Dieser Auftrag erweitert die sieben verlinkten Entwürfe und ersetzt diese ältere Home-Auswertung nicht.
- Android und iOS sind weiterhin Flutter-Ziele; echte Geräte und native Benachrichtigungen sind mit dieser Änderung nicht getestet.

## Prüfung

Automatische Tests decken die bisherigen Periodenfunktionen, die neue lokale Speicherung, beschädigte Daten, fehlgeschlagene Schreibvorgänge, Bearbeitung desselben Tages, Navigation, Abbrechen, Löschen, Export und Fensterbreiten von 320 bis 1440 Pixel ab. Zusätzlich werden die Entwürfe im Browser mit den Figma-Abbildungen verglichen. Statische Analyse und Web-Build gehören zur Prüfung.
