# Kuyena

Lokales Zyklustagebuch mit Flutter und Dart für Android, iPhone und Browser.
Kuyena dokumentiert Perioden mit Beginn und optionalem Ende sowie Symptome, Stimmung, Energie und Notizen pro Tag. Kalender, allgemeine Ideen und ein JSON-Export ergänzen das lokale Tagebuch. Der nächste Periodenbeginn wird näherungsweise aus persönlichen Startabständen geschätzt.

## Aktueller Ablauf

- Auf Home unter dem Kreis „Periode starten“ wählen und den Beginn bestätigen. Mit „Periode beenden“ den letzten Blutungstag speichern.
- Mit + / Log unabhängig davon Symptome, Stimmung, Energie oder eine Notiz für einen Tag speichern.
- Vergessene Perioden und Symptome über einen vergangenen Kalendertag nachtragen. Liegt danach schon eine weitere Periode, wird für den Periodennachtrag auch das Ende abgefragt.
- Im Kalender über „Periodentage bearbeiten“ einzelne Tage antippen oder durch Ziehen einen Bereich markieren bzw. entfernen; auf dem Touchscreen dafür kurz gedrückt halten. Erst „Speichern“ übernimmt die Auswahl. Zusammenhängende Tage erscheinen als rotes Band.
- Tageseinträge im Kalender wieder öffnen und bearbeiten; Symptome bleiben beim Entfernen eines Periodentags erhalten.
- Unter Cycle → Edit cycle data Periodenbeginn und optionales Ende erfassen und korrigieren.
- Ein Ende später ergänzen oder wieder als unbekannt angeben.
- „Periode läuft noch“ ausdrücklich markieren und mit einem Enddatum beenden.
- Auf Home den Periodentag aus manuellen Angaben und Blutungsangaben im Log anzeigen; weitere Tagesangaben erscheinen als kurze Zusammenfassung im Kreis.
- Die Phase für den ausgewählten Tag anzeigen: Menstruation aus Einträgen, weitere Phasen bei ausreichenden Angaben als vorläufige Schätzung. Die Symptomkarte zeigt die tatsächlich eingetragenen Symptome dieses Tages.
- Einzelne oder alle Einträge nach Bestätigung löschen.
- Einträge beim erneuten Öffnen aus dem lokalen Speicher laden.
- Unter Cycle → Sicherung & Wiederherstellung eine passwortgeschützte Datei speichern und nach einer Vorschau wiederherstellen; frühere JSON-Exporte bleiben importierbar.
- Keine Konten, keine Synchronisation und kein Backend für Gesundheitsdaten.

Der Plusknopf öffnet ausschließlich die Datumsauswahl für Symptome und Wohlbefinden. Die schnelle Periodeneingabe ist davon getrennt. Nach „Periode starten“ bleibt die Periode aktiv, bis ein Ende erfasst wird; das Enddatum zählt noch als Blutungstag. Abbrechen speichert nichts. Beim Bearbeiten oder Löschen von Wohlbefinden bleiben Perioden und bisherige Blutungsangaben erhalten.
Die Periodenerfassung erreichst du über Cycle → Edit cycle data →
„Periode eintragen“. Dort Beginn wählen, bei Bedarf „Ende (optional)“ auswählen und
„Speichern“ drücken. Bestehende Einträge lassen sich über „Korrigieren“
bearbeiten. Ein leeres Ende bedeutet unbekannt. Angegebene Enddaten müssen
zwischen Beginn und heute liegen. Abbrechen speichert keine Änderungen.

Nach dem Speichern der Periodeneingabe aktualisieren sich Kreis und Phase: Beginn zählt als Tag 1. Auch bisherige Blutungsangaben werden weiterhin berücksichtigt: Light, Medium und Heavy führen den Abschnitt fort; None beendet ihn mit dem Vortag als letztem Tag. Diese Angaben lassen sich im Periodenverlauf über „Blutungsangaben prüfen“ getrennt korrigieren. Symptome und Stimmung allein starten keine Periode.
Ein unbekanntes Ende wird nicht automatisch als laufende Periode interpretiert.
Die ausdrückliche Markierung „Periode läuft noch“ macht den Bogen rot,
sonst ist er hellrosa. Er baut sich von oben im Uhrzeigersinn auf.
Das Datumsrad zeigt den Wert für den ausgewählten Tag, „Heute“ führt zurück.
Mit mindestens einem Startabstand zeigt der Kreis außerhalb einer
bestätigten Periode den ungefähren Countdown aus dem Mittelwert der dokumentierten
Startabstände. Zuvor kann eine genau angegebene übliche Zykluslänge als Richtwert dienen. Antippen erklärt die Rechnung. Zu wenige
Angaben ergeben keine erfundene Standardlänge; ein vergangener geschätzter
Termin wird als solcher angezeigt.

Die Regeln und die geplante Sprachumschaltung sind in [Phase und Symptome auf Home](docs/home-phase-symptome.md) einfach erklärt. Die Phasenschätzung wird später durch die vereinbarte Projektberechnung ersetzt.

## Entwicklung

Geprüfte Ausgangsversion: Flutter 3.47.7 mit Dart 3.13.5.

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome --web-port 7357
```

Den Web-Port beibehalten: Browser-Speicher ist an die jeweilige Origin
(Protokoll, Hostname, Port) gebunden. Ein anderer Port zeigt einen anderen Speicher.
Nach einer Änderung an nativen Plugins die App vollständig neu starten;
Hot Reload allein registriert neue native Plugins nicht.

Für einen mobilen Start erst Simulator/Emulator oder Gerät bereitstellen,
mit `flutter devices` die Gerätekennung anzeigen und mit
`flutter run -d DEINE_GERAETE_ID` starten. Die Gerätekennung ersetzen.
Android benötigt ein eingerichtetes Android SDK, iOS vollständiges Xcode
und gegebenenfalls die passende Signierung.

Ein Web-Build mit lokal gebündelten Flutter-Ressourcen:

```bash
flutter build web --no-web-resources-cdn
```

## Speicherung und Grenzen des Prototyps

`flutter_secure_storage` nutzt die Schutzmechanismen der jeweiligen Plattform.
Die App speichert ein versioniertes Dokument mit Kennungen und Kalenderdaten, keine Namen
oder Kontaktdaten. Auf iOS ist der Zugriff auf das entsperrte Gerät beschränkt;
Keychain-Synchronisation ist nicht aktiviert. Android-Autobackup ist für die App
deaktiviert. „Delete all local data“ entfernt Kuyenas Perioden und das Tagesjournal einschließlich Kalenderkorrekturen.

Die Web-Implementierung des Plugins ist upstream **experimentell**. Sie benötigt
HTTPS oder localhost. Browser-Schlüssel liegen ebenfalls im Browserprofil;
dies ist keine Passwortsperre und kein Schutz vor Schadcode derselben Origin
oder Personen mit Zugriff auf das Browserprofil. Die Browserfassung verwendet
deshalb vorerst **Testdaten**. Das Löschen von Website-Daten, ein privates
Browserfenster und Speicherbereinigung können Daten entfernen. Unter Cycle stehen der lesbare JSON-Export sowie passwortgeschützte Sicherungsdateien und eine geprüfte Wiederherstellung bereit. Auf Mobilgeräten sind reale
Gerätetests vor einer Nutzung mit Gesundheitsdaten ebenfalls erforderlich.

Vorgänge teilen sich einen gemeinsamen Datenzugriff. Aktuelle Browser koordinieren ihn über Web Locks zwischen Tabs derselben Origin. Nach einem Update alle alten Tabs neu laden; frühere App-Versionen verwenden noch die alten Schlüssel. Gleichzeitige Bearbeitungen desselben Tageseintrags oder einer Periode werden vor dem Überschreiben geprüft.
Für eine größere Symptomdatenbank ist die Speicherung neu zu bewerten.

Bereits gespeicherte Periodenbeginne aus Dokumentversion 1 werden mit
unverändertem Datum und unbekanntem Ende gelesen. Beim nächsten bestätigten
Speichern werden sie zusammen mit den Änderungen in Version 3 übernommen.
Version-2-Perioden ohne Aktiv-Markierung bleiben ebenfalls lesbar;
ihre unbekannten Enden bleiben unbekannt.
Die produktive App führt beide Datenbereiche unter `kuyena.local_data.v1` zusammen. Vorhandene alte Schlüssel werden beim ersten erfolgreichen Laden validiert, in den gemeinsamen Speicher kopiert, durch Rücklesen geprüft und erst danach entfernt. Beschädigte oder unbekannte Formate werden gemeldet und erhalten. Einzelheiten stehen in [Lokale Datenbasis und Sicherung](docs/lokale-datenbasis.md).

## Kursdokumentation

[Lokale Datenbasis, Sicherung und Wiederherstellung](docs/lokale-datenbasis.md)

[Getrennte Eingaben und schnelle Periodenaktionen](docs/getrennte-eingaben.md)

[Periodenmodell, Erklärung und aktueller Speicherablauf](docs/periodenmodell.md)

[Tageszähler im Kreis und Berechnung aus den gespeicherten Angaben](docs/periodentag.md)

[Erster Meilenstein: Periodenbeginn (Stand 18.10.2026)](docs/periodenbeginn.md)

## Quellen

- [Flutter Secure Storage: Plattformen, Android-Backup, iOS-Konfiguration und Web-Grenzen](https://pub.dev/packages/flutter_secure_storage)
- [Web-Implementierung und HTTPS-Anforderung](https://pub.dev/packages/flutter_secure_storage_web)
- [Browser-Speicher und Origin](https://developer.mozilla.org/en-US/docs/Web/API/Window/localStorage)


## Weitere Figma-Seiten

Kalender, Ansichtsmenü, Tageseintrag, Datumsauswahl, Empfehlungen, Cycle & App und Startbildschirm sind umgesetzt. Die Navigation und lokalen Funktionen sind in [docs/figma-seiten.md](docs/figma-seiten.md) erklärt. Mit **+ / Log** wird ein Tageseintrag erfasst; Periodenbeginn und -ende verwaltest du unter **Cycle → Edit cycle data**.


### Einrichtung und persönliche Angaben

Beim ersten Öffnen führt Kuyena durch Begrüßung, lokale Speicherung und sieben
freiwillige Einrichtungsschritte. „Weiß ich nicht“ und Überspringen sind möglich.
Die Auswahl bleibt lokal, gehört zur Datensicherung und lässt sich unter
**Cycle & App → Deine Angaben & Einstellungen** ändern. Der gemeldete letzte
Periodenbeginn wird ohne erfundenes Enddatum übernommen. Im Log erscheinen
bevorzugte Symptome zuerst; alle weiteren bleiben erreichbar.

Erinnerungen erscheinen zur gewählten Uhrzeit innerhalb der geöffneten App.
Benachrichtigungen im Hintergrund sowie individuell geprüfte Rezept- und
Trainingsvorschläge sind noch nicht angebunden. Details: [Onboarding](docs/onboarding.md).
