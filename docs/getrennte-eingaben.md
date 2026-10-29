# Getrennte Eingaben: Periode und Wohlbefinden

Stand: 29.10.2026. Gewählter Ablauf: **Periode starten / beenden**.

## So funktioniert es

Auf Home steht direkt unter dem Kreis eine eigene Periodenaktion. Sie gilt für das Datum im Datumsrad. „Periode starten“ öffnet ein Datum mit „Speichern“ und „Abbrechen“. Der Beginn zählt als Tag 1. Ohne Ende bleibt die Periode als aktiv markiert. Bei einem Datum in der Vergangenheit heißt die Eingabe „Periode nachtragen“ und bietet zusätzlich den letzten Blutungstag an.

Bei einer laufenden Periode heißt die Aktion „Periode beenden“. Gefragt wird ausdrücklich nach dem **letzten Blutungstag**. Das ausgewählte Datum gehört noch zur Periode; ab dem Folgetag ist sie beendet. Ein Ende lässt sich rückwirkend angeben. Für einen älteren Beginn mit unbekanntem Ende heißt die Aktion „Ende ergänzen“. Bereits abgeschlossene Perioden führen über den Verlauf zur bisherigen Datumskorrektur.

+ / Log öffnet weiterhin die Tagesauswahl, danach ausschließlich Symptome, Stimmung, Energie und Notiz. Der Tageseintrag braucht keine Periode. Im Kalender sind Periodeneingabe und Wohlbefinden ebenfalls zwei eigene Aktionen. Der kleine Tagespunkt markiert Wohlbefinden; die rote Fläche markiert Periodentage.

„Periodenverlauf öffnen“ führt aus der Schnellaktion direkt zur Monatsansicht des Kalenders. Der auf Home ausgewählte Monat bleibt dabei erhalten. Wird die Aktion bereits aus dem Kalender geöffnet, kehrt sie zur Monatsansicht dieses Monats zurück. Die ausführliche Verwaltung bleibt unter Cycle → Edit cycle data und über „Manage period dates“ im Kalender erreichbar.

Speichern der Schnellaktion aktualisiert Kreis, Phase und Verlauf. Symptome werden auf Home unter „Logged symptoms“ für den ausgewählten Tag angezeigt. Die Periodeneingabe erfindet keine Blutungsstärke und erzeugt keinen zusätzlichen Symptome-Eintrag.

## Bestehende Einträge behalten

Vorhandene manuelle Perioden und frühere Flow-Angaben werden vollständig übernommen. Der gemeinsame lokale Speicher kopiert beim ersten erfolgreichen Laden die beiden bisherigen Dokumente, prüft die Kopie durch Rücklesen und entfernt erst dann die alten Schlüssel. Die fachlichen Angaben werden dabei nicht umgedeutet. Siehe [Lokale Datenbasis](lokale-datenbasis.md).

Beim Speichern des Wohlbefindens wird eine eventuell vorhandene Blutungsangabe aus dem aktuellen Speicher übernommen. Beim Löschen des Wohlbefindens werden nur Symptome, Stimmung, Energie und Notiz entfernt. Eine Blutungsangabe bleibt erhalten. Ohne weitere Angaben verschwindet der leere Tageseintrag.

Bisherige Blutungsangaben sind im Periodenverlauf über „Blutungsangaben prüfen“ einzeln erreichbar, auch ausdrücklich gespeicherte Tage ohne Blutung. Dort werden sie getrennt vom Wohlbefinden geändert. „Keine Angabe“ entfernt diese einzelne Blutungsangabe; „Keine Blutung“ entspricht weiterhin dem früheren None und beendet den Abschnitt mit dem Vortag als letztem Tag. Diese historische Bedeutung wird nicht still geändert.

Endet eine noch aus alten Blutungsangaben berechnete Periode über die Schnellaktion, wird ihr bestehender Beginn mit dem bestätigten Ende einmal als Periodeneintrag übernommen. Die alten Beobachtungen bleiben erhalten; die gemeinsame Übersicht zählt daraus keine doppelte Periode. Die produktive App speichert beide Datenbereiche gemeinsam in einem bestätigten Speicherwert.

## Grenzen und Prüfung

Künftige Beobachtungstage, ein Ende vor dem Beginn, ein zweiter laufender Abschnitt und widersprüchliche Angaben werden nicht still gespeichert. Auch ältere Perioden lassen sich nachtragen. Gibt es danach bereits einen weiteren Periodenbeginn, ist ein Enddatum erforderlich; es muss vor dem nächsten gespeicherten Beginn liegen. Auch vor einer neueren laufenden Periode ist dadurch ein abgeschlossener Nachtrag möglich. Zeiträume dürfen sich nicht überschneiden. Bei einer früheren Periode mit unbekanntem Ende wird kein Ende erfunden. Weitergehende Korrekturen bleiben im Periodenverlauf möglich. Eine nach dem gewählten Ende gespeicherte Blutung muss zuerst geprüft werden. Bei Lesefehlern wird keine neue Periode auf Grundlage vermeintlich leerer Daten angelegt. Schreibfehler behalten die Eingabe für einen erneuten Versuch.

`PeriodQuickActions` koordiniert Start und Ende; `PeriodDiary` speichert Perioden. `DayJournal.saveWellbeing` und `removeWellbeing` verändern ausschließlich das Wohlbefinden. `setFlow` ist der getrennte Weg zur Korrektur früherer Blutungsangaben. Die bisherigen Periodenformate bleiben lesbar; die bisherigen Schlüssel werden über den geprüften Speicherumzug übernommen. Das Tagesjournal liest weiterhin Version 1 und speichert bestätigte Änderungen nun in Version 2 einschließlich Kalenderkorrekturen.

Tests prüfen Start und inklusives Ende, erneutes Laden, Übernahme bestehender Log-Perioden ohne Doppelung, unabhängige Änderungen und Löschungen, Fehlversuche, veraltete Eingaben und die Navigation zwischen Home, Kalender und Cycle.

## Vergessene Tage nachtragen

Im Kalender einen vergangenen Tag auswählen. Über „Periode eintragen / beenden“ lässt sich ein fehlender Zeitraum mit Beginn und letztem Blutungstag ergänzen. Über „Log this day“ werden unabhängig davon Symptome, Stimmung, Energie oder eine Notiz für genau diesen Tag erfasst.

Wenn der Beginn im Datumsfeld geändert wird, werden die Nachbardaten erneut geladen. Steht bereits eine spätere Periode im Verlauf, erscheint „Letzter Blutungstag (erforderlich)“ zusammen mit deren Beginn. Die Datumsauswahl erlaubt maximal den Vortag dieses nächsten Beginns. Es wird keine vermutete Dauer vorausgewählt. Ohne spätere Periode ist das Ende bei einem vergangenen Beginn optional.

Beim Speichern wird die zeitliche Einordnung erneut geprüft. Doppelte Beginne, sich berührende Blutungszeiträume und ausdrücklich gespeicherte Tage ohne Blutung innerhalb des neuen Zeitraums werden nicht still überschrieben. Bestehende Perioden behalten Kennungen und Datumsangaben. Abbrechen oder eine abgelehnte Eingabe legt keinen halben Nachtrag an.

Tests prüfen Nachträge vor abgeschlossenen und laufenden Perioden, Lücken zwischen vorhandenen Zeiträumen, notwendige Enddaten, inklusive Randtage, spätere Änderungen am Verlauf, unbekannte frühere Enden und das unabhängige Nachtragen vergangener Symptome.


## Periodentage im Kalender bearbeiten

Im Kalender **Periodentage bearbeiten** wählen. Ein vergangener Tag oder heute wird durch Antippen markiert; erneutes Antippen entfernt die Markierung. Monatswechsel lassen die Auswahl bestehen. Erst **Speichern** übernimmt alle Änderungen gemeinsam. **Abbrechen** fragt bei Änderungen nach, ob der Entwurf verworfen werden soll. Bei einem Speicherfehler bleibt die Auswahl für einen erneuten Versuch erhalten. Zukünftige Tage lassen sich nicht markieren.

Mehrere Tage lassen sich als Bereich auswählen: Mit Maus oder Stift auf einem Tag gedrückt ziehen. Auf einem Touchscreen zuerst kurz gedrückt halten und danach ziehen; schnelles vertikales Wischen scrollt weiterhin. Ein unmarkierter Starttag markiert den Bereich bis zum aktuellen Tag, ein bereits markierter Starttag entfernt ihn. Die Auswahl folgt der Kalenderreihenfolge, auch beim Rückwärtsziehen und über Wochenzeilen hinweg. Zukünftige Tage bleiben ausgeschlossen.

Beim Zurückziehen wird der aktuelle Bereich wieder kleiner; frühere Entwurfsänderungen bleiben erhalten. Wird die Geste vom System abgebrochen, wird nur diese Ziehauswahl zurückgesetzt. Nach dem Loslassen können weitere Bereiche oder andere Monate bearbeitet werden. Einzelnes Antippen und zugängliche Tagesaktionen bleiben verfügbar. Gespeichert wird weiterhin ausschließlich mit **Speichern**, unabhängig von der Zahl der überstrichenen Tage.

Aufeinanderfolgende Periodentage erscheinen als durchgehendes rotes Band mit runden Enden. Am Wochen- oder Monatswechsel beginnt eine neue sichtbare Zeile. Ein entfernter Tag erzeugt eine Lücke. Der kleine Punkt für Symptome und Wohlbefinden bleibt unabhängig davon.

Die Tagesauswahl korrigiert die gemeinsame Übersicht für Home, Phase, Kalender und Cycle. Eine Lücke innerhalb einer bestehenden Periode erzeugt keinen zusätzlichen Zyklusbeginn. Entfernte Randtage korrigieren Beginn bzw. Ende der sichtbaren Periode. Werden alle ihre Tage entfernt, verschwindet sie auch aus der Übersicht. Bei einer laufenden Periode bleiben die späteren, weiterhin markierten Tage erhalten; das Entfernen ihres letzten Abschnitts beendet sie am letzten verbleibenden Tag. Im Kalender neu erfasste einzelne Tage und zusammenhängende Gruppen gelten nur für diese ausgewählten Tage, nicht automatisch bis heute oder in die Zukunft.

Symptome, Stimmung, Energie, Notizen, alte Blutungsstärken und Erinnerungen werden dabei nicht gelöscht. Die bestätigten Tageskorrekturen liegen im selben versionierten Journal wie die übrigen Tagesdaten und werden mit einem Schreibvorgang gespeichert. Manuelle Beginn-/Enddatensätze bleiben erhalten; Kalenderkorrekturen haben bei der Anzeige Vorrang. Ein anderer geänderter Periodenverlauf während einer offenen Bearbeitung erfordert erneutes Laden. Neue Wohlbefindensangaben werden beim Speichern übernommen. Aktuelle Browser-Tabs derselben Origin koordinieren Änderungen über Web Locks. Alle Tabs müssen nach einem App-Update neu geladen werden.

Das Journal liest Version 1 und 2. Beim nächsten bestätigten Schreiben wird Version 2 mit `periodDays` verwendet; die fachlichen Angaben bleiben beim Speicherumzug unverändert. Jeder Korrektureintrag enthält das Kalenderdatum und `period: true` oder `false`. Unbekannte oder beschädigte Formate werden gemeldet. Der JSON-Export in Version 2 enthält ursprüngliche Perioden, Tageseinträge und diese Tageskorrekturen gemeinsam. **Delete all local data** entfernt auch die Kalenderkorrekturen. Der Import unterstützt verschlüsselte Sicherungsdateien und frühere JSON-Exporte nach Vorschau und ausdrücklicher Bestätigung.

Die Periodenlänge unter Cycle zählt bei abgeschlossenen Perioden die tatsächlich markierten Blutungstage. Der Tageszähler auf Home bleibt der Kalendertag seit dem korrigierten Beginn. Bei Lücken erklärt die Anzeige zusätzlich die Zahl der eingetragenen Blutungstage. Berechnungsregeln und Phasenschätzung bleiben vorläufig und werden später gemeinsam präzisiert.
