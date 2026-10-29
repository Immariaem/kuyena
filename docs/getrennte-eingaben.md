# Getrennte Eingaben: Periode und Wohlbefinden

Stand: 29.10.2026. Gewählter Ablauf: **Periode starten / beenden**.

## So funktioniert es

Auf Home steht direkt unter dem Kreis eine eigene Periodenaktion. Sie gilt für das Datum im Datumsrad. „Periode starten“ öffnet nur ein Datum mit „Speichern“ und „Abbrechen“. Der Beginn zählt als Tag 1. Die Periode bleibt als aktiv markiert, bis ein Ende angegeben wird.

Bei einer laufenden Periode heißt die Aktion „Periode beenden“. Gefragt wird ausdrücklich nach dem **letzten Blutungstag**. Das ausgewählte Datum gehört noch zur Periode; ab dem Folgetag ist sie beendet. Ein Ende lässt sich rückwirkend angeben. Für einen älteren Beginn mit unbekanntem Ende heißt die Aktion „Ende ergänzen“. Bereits abgeschlossene Perioden führen über den Verlauf zur bisherigen Datumskorrektur.

+ / Log öffnet weiterhin die Tagesauswahl, danach ausschließlich Symptome, Stimmung, Energie und Notiz. Der Tageseintrag braucht keine Periode. Im Kalender sind Periodeneingabe und Wohlbefinden ebenfalls zwei eigene Aktionen. Der kleine Tagespunkt markiert Wohlbefinden; die rote Fläche markiert Periodentage.

„Periodenverlauf öffnen“ führt aus der Schnellaktion direkt zur Monatsansicht des Kalenders. Der auf Home ausgewählte Monat bleibt dabei erhalten. Wird die Aktion bereits aus dem Kalender geöffnet, kehrt sie zur Monatsansicht dieses Monats zurück. Die ausführliche Verwaltung bleibt unter Cycle → Edit cycle data und über „Manage period dates“ im Kalender erreichbar.

Speichern der Schnellaktion aktualisiert Kreis, Phase und Verlauf. Symptome werden auf Home unter „Logged symptoms“ für den ausgewählten Tag angezeigt. Die Periodeneingabe erfindet keine Blutungsstärke und erzeugt keinen zusätzlichen Symptome-Eintrag.

## Bestehende Einträge behalten

Es gibt keine automatische Datenmigration beim Öffnen. Vorhandene manuelle Perioden und frühere Flow-Angaben werden wie bisher gelesen.

Beim Speichern des Wohlbefindens wird eine eventuell vorhandene Blutungsangabe aus dem aktuellen Speicher übernommen. Beim Löschen des Wohlbefindens werden nur Symptome, Stimmung, Energie und Notiz entfernt. Eine Blutungsangabe bleibt erhalten. Ohne weitere Angaben verschwindet der leere Tageseintrag.

Bisherige Blutungsangaben sind im Periodenverlauf über „Blutungsangaben prüfen“ einzeln erreichbar, auch ausdrücklich gespeicherte Tage ohne Blutung. Dort werden sie getrennt vom Wohlbefinden geändert. „Keine Angabe“ entfernt diese einzelne Blutungsangabe; „Keine Blutung“ entspricht weiterhin dem früheren None und beendet den Abschnitt mit dem Vortag als letztem Tag. Diese historische Bedeutung wird nicht still geändert.

Endet eine noch aus alten Blutungsangaben berechnete Periode über die Schnellaktion, wird ihr bestehender Beginn mit dem bestätigten Ende einmal als Periodeneintrag übernommen. Die alten Beobachtungen bleiben erhalten; die gemeinsame Übersicht zählt daraus keine doppelte Periode. Es werden keine zwei Speicherdokumente gleichzeitig verändert.

## Grenzen und Prüfung

Künftige Beobachtungstage, ein Ende vor dem Beginn, ein zweiter laufender Abschnitt und widersprüchliche Angaben werden nicht still gespeichert. Für die schnelle Eingabe muss ein neuer Beginn nach den bereits dokumentierten Zeiträumen liegen; weitergehende Korrekturen bleiben im Periodenverlauf möglich. Eine nach dem gewählten Ende gespeicherte Blutung muss zuerst geprüft werden. Bei Lesefehlern wird keine neue Periode auf Grundlage vermeintlich leerer Daten angelegt. Schreibfehler behalten die Eingabe für einen erneuten Versuch.

`PeriodQuickActions` koordiniert Start und Ende; `PeriodDiary` speichert Perioden. `DayJournal.saveWellbeing` und `removeWellbeing` verändern ausschließlich das Wohlbefinden. `setFlow` ist der getrennte Weg zur Korrektur früherer Blutungsangaben. Die Datenformate und Speicherschlüssel bleiben erhalten.

Tests prüfen Start und inklusives Ende, erneutes Laden, Übernahme bestehender Log-Perioden ohne Doppelung, unabhängige Änderungen und Löschungen, Fehlversuche, veraltete Eingaben und die Navigation zwischen Home, Kalender und Cycle.
