# Die sieben Figma-Entwürfe

Stand: 29.10.2026. Die bestehenden Periodenangaben werden weiterverwendet.

| Figma-Knoten | Ansicht in Flutter | Bedienung |
| --- | --- | --- |
| 207:1758 | Kalender-Ansichtsmenü | Day, Month und Year auswählen; außerhalb klicken oder Escape zum Schließen |
| 24:3174 | Calendar | Monate in beide Richtungen scrollen, Tag für Details wählen; Jahresansicht öffnet einen Monat |
| 24:3486 | Recommendations | Zwei horizontale Kartenreihen; Karten öffnen die allgemeine Idee |
| 24:3415 | Cycle & App | Echte Mittelwerte, Periodenverlauf, Einstellungen, Export, Löschen und Informationen |
| 60:940 | Log your day | Mehrere Symptome, Stimmung, Energie und Notiz unabhängig von einer Periode erfassen und bearbeiten |
| 207:1773 | Startbildschirm | Originalgrafiken und sechs Logo-Vektoren; öffnet nach 1,4 Sekunden Home, Tippen überspringt ihn |
| 60:571 | Choose a date | Datum auswählen, Monate wechseln, mit Continue zum Tageseintrag; zukünftige Beobachtungen sind gesperrt |

Schrift, Farben und bereits vorhandene Home-Bausteine werden wiederverwendet. Originalbilder und SVGs sind lokal unter `assets/screens/` gebündelt. Zur Laufzeit werden keine Figma-URLs aufgerufen. Bis 899 Pixel bleibt die schmale Anordnung erhalten; ab 900 Pixel gibt es eine seitliche Navigation und mehr Inhaltsbreite. Lange Inhalte bleiben scrollbar. Die englischen Texte stammen aus den Entwürfen; die bestehende deutsche Periodenerfassung bleibt erreichbar.

## Vom Entwurf zur Funktion – einfach erklärt

Die Navigation verbindet die Seiten miteinander. Mit dem Plus wählst du zuerst ein Datum und füllst dann den Tageseintrag aus. Speichern legt die Angaben auf diesem Gerät ab. Beim erneuten Öffnen desselben Datums kommen diese Angaben wieder ins Formular. Erst ein erneutes Speichern übernimmt Änderungen. Beim Verlassen eines geänderten Entwurfs fragt die App nach, ob er verworfen werden soll.

Das Formular wurde auf Wunsch in zwei Wege getrennt: Periodenbeginn und -ende über eine schnelle Aktion auf Home, Wohlbefinden über + / Log. Das Wohlbefinden-Formular verwendet weiterhin die Auswahlmöglichkeiten aus Figma: Symptome = Cramps/Headache/Fatigue/Breast tenderness; Stimmung = Good/Okay/Low. Der Energieregler wird als Ganzzahl von 0 bis 100 gespeichert, ohne medizinische Bewertung. Alle Angaben sind optional. Ein neuer Tag enthält zunächst keine vorausgewählten Beobachtungen; der unberührte Regler zählt ebenfalls nicht als gemessene Energie. Mindestens eine tatsächliche Angabe oder Notiz ist zum Speichern nötig.

Ein Datum hat in diesem umgesetzten Formular genau einen bearbeitbaren Tageseintrag. Ein Symptom kann darin einmal ausgewählt werden; mehrere verschiedene Symptome sind möglich. Tageseinträge brauchen keine zugeordnete Periode. Das Löschen eines Wohlbefinden-Eintrags entfernt nur seine Symptome, Stimmung, Energie und Notiz. Andere Tage, Periodendaten und bisherige Blutungsangaben bleiben bestehen.

## Zwei getrennte Arten von Einträgen

- **Perioden:** Beginn, optionales Ende und ausdrücklich „läuft noch“. Die bisherige Speicherung einschließlich älterer Formate bleibt erhalten. Unter Cycle → Edit cycle data lassen sich diese Angaben verwalten. Auch der Kreis auf Home führt weiterhin zu diesen Periodenangaben.
- **Tageseinträge:** Symptome, Stimmung, Energie und Notizen für ein konkretes Datum. Sie werden über + / Log erfasst und beeinflussen Beginn und Ende einer Periode nicht. Ältere Flow-Angaben bleiben lesbar und im Periodenverlauf getrennt bearbeitbar. Die bereits vereinbarte Regel für diese Angaben bleibt erhalten: Light/Medium/Heavy führen den Abschnitt fort; None beendet ihn mit dem Vortag als letztem Tag. Home, Kalender und Cycle verwenden dieselbe Übersicht. [Aktueller Ablauf](getrennte-eingaben.md).

Im Kalender bedeutet die rote Fläche: Periodentag aus manuellen Angaben und Log-Blutungsangaben. None markiert für diesen Tag ausdrücklich keine Blutung. Ein unbekanntes Ende färbt nur den dokumentierten Beginn; eine ausdrücklich laufende Periode reicht bis heute. Der umrandete Tag ist heute. Ein kleiner Punkt markiert einen vorhandenen Tageseintrag. Tagesdetails zeigen die tatsächlich gespeicherten Angaben; Beispieldaten aus Figma werden nicht als persönliche Beobachtung gespeichert.

Cycle & App zeigt den arithmetischen Mittelwert der Start-zu-Start-Abstände aus der gemeinsamen Übersicht. Abstände nach einer noch laufend markierten oder mit dem nächsten Beginn überlappenden Periode werden ausgelassen. Die durchschnittliche Periodendauer verwendet nur Einträge mit bekanntem Ende und zählt beide Randtage. Der Home-Countdown verwendet seit dem Onboarding ebenfalls den auf ganze Tage gerundeten arithmetischen Mittelwert der dokumentierten Startabstände. Ohne Startabstand kann die genau eingegebene übliche Zykluslänge als erster Richtwert dienen.

## Speicher und Datenschutz

`DayEntry` beschreibt die Angaben; `DayJournal` koordiniert Laden, Speichern und Löschen. `LocalJournalRepository` verwaltet ein eigenes versioniertes Dokument über den bestehenden Speicherzugang. Dadurch bleiben UI und Speicher getrennt und mit Testdaten prüfbar.

Die produktive App verwendet jetzt einen gemeinsamen versionierten Speicherwert unter `kuyena.local_data.v1`. Die alten Schlüssel werden erst nach geprüfter Übernahme entfernt. Perioden und Tagesjournal bleiben fachlich getrennt, werden aber bei Wiederherstellung gemeinsam geschrieben. Web Locks koordinieren aktualisierte Browser-Tabs derselben Origin; ältere offene App-Versionen müssen neu geladen werden.

Der bestehende JSON-Export bleibt zum ausdrücklichen Kopieren erhalten. Zusätzlich gibt es unter Cycle → Sicherung & Wiederherstellung passwortgeschützte Dateien und den Import früherer JSON-Exporte. Die Wiederherstellung zeigt zuerst die Zahl der enthaltenen Einträge und ersetzt nach Bestätigung den gesamten aktuellen Stand. Ein falsches Passwort, beschädigte Dateien oder veraltete Vorschauen werden abgewiesen. Details und Grenzen beschreibt [Lokale Datenbasis](lokale-datenbasis.md).

Im Browser bleibt die bestehende Einschränkung des experimentellen Secure-Storage-Web-Plugins bestehen: Browserprofil und Website-Adresse einschließlich Port bestimmen den Speicher; das Löschen von Website-Daten kann Einträge entfernen. Für den Prototyp Testdaten verwenden. Es gibt keine Konten, Cloud-Synchronisierung oder externe Übertragung von Gesundheitsangaben.

## Bewusst begrenzte Funktionen

- **Reminders:** Die Einstellung wird gespeichert. Wenn für heute noch kein Tageseintrag vorliegt, erscheint auf Home eine Erinnerung innerhalb der geöffneten App. Es werden keine Push- oder Betriebssystem-Benachrichtigungen geplant. Der Hinweis wird beim Öffnen von Home, nach einer Rückkehr und beim Wiederaufnehmen der App neu geprüft; er ist kein Hintergrunddienst.
- **Recommendations:** Originalbilder und allgemeine Ideen aus Figma. Es wird keine Zyklusphase aus Symptomen abgeleitet und keine individuelle medizinische Ernährung oder Bewegung verordnet. Die Karten weisen auf ihren allgemeinen Charakter hin.
- **Home:** Phase und Symptome folgen dem ausgewählten Datum. Dokumentierte Blutung zeigt Menstruation; weitere Phasen sind vorläufige Kalenderschätzungen. Eingetragene Symptome ersetzen das Beispiel. Ohne Symptome bleibt „Possible symptoms“ als gekennzeichnetes Beispiel. Einzelheiten: [Phase und Symptome auf Home](home-phase-symptome.md).
- Android und iOS sind weiterhin Flutter-Ziele; echte Geräte und native Benachrichtigungen sind mit dieser Änderung nicht getestet.

## Prüfung

Automatische Tests decken die bisherigen Periodenfunktionen, die neue lokale Speicherung, beschädigte Daten, fehlgeschlagene Schreibvorgänge, Bearbeitung desselben Tages, Navigation, Abbrechen, Löschen, Export und Fensterbreiten von 320 bis 1440 Pixel ab. Zusätzlich werden die Entwürfe im Browser mit den Figma-Abbildungen verglichen. Statische Analyse und Web-Build gehören zur Prüfung.


## Verbindung von Log und Home (28.10.2026)

`PeriodTimeline` berechnet aus beiden Quellen dieselbe Periodenübersicht für Home, Calendar, Cycle und die Periodenverwaltung. Der erste Blutungstag zählt als Tag 1. Ein vorhandener manueller Beginn wird als Beginn weiterverwendet; Blutungsangaben innerhalb einer bekannten Periode erzeugen keine zweite Periode. Eine spätere Blutung nach einem bekannten Ende startet einen neuen Abschnitt. Ein leerer Flow-Wert oder ein fehlender Tag beendet die Periode nicht.

Die vom Nutzer gewählte Regel lautet: **None beendet die laufende Periode. Der Vortag ist der letzte Periodentag.** Bei einer manuellen Periode, die erst am selben Tag begonnen wurde, kann kein Ende vor dem Beginn gesetzt werden: Der manuelle Tag bleibt erhalten; die Tagesanzeige zeigt wegen None keine aktive Blutung. Zukünftige Log-Daten werden nicht für die aktuelle Anzeige verwendet.

Die Übersicht wird ausschließlich beim Lesen berechnet. Beide Speicherdokumente bleiben erhalten. Änderungen und Löschungen von Log-Einträgen werden beim nächsten Laden neu berücksichtigt, ohne dass alte automatisch erzeugte Perioden zurückbleiben. Fehlgeschlagenes Laden einer der beiden Quellen zeigt einen Fehler statt einer falschen Nullanzeige.

Die Periodenverwaltung zeigt aus dem Log stammende Abschnitte unter „Aus deinem Log“. Dort führen „Im Log bearbeiten“ und „Für heute erfassen“ zu den entsprechenden Tagen. Manuelle Angaben lassen sich weiterhin über „Korrigieren“ bearbeiten. Wenn ein manueller Zeitraum durch Log-Angaben ergänzt wurde, wird das auf seiner Karte kenntlich gemacht. Das Löschen manueller Perioden löscht keine Log-Einträge; „Delete all local data“ unter Cycle löscht nach Bestätigung beide Quellen.

Der Kreis enthält zusätzlich eine kurze Zusammenfassung des ausgewählten Tageseintrags. Ein Tipp öffnet die Details. Der Countdown benötigt weiterhin genügend persönliche Startabstände; es wird keine feste 28-Tage-Länge erfunden.
