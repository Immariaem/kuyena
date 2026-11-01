# Kuyena

Lokales Zyklustagebuch mit Flutter und Dart für Android, iPhone und Browser.
Kuyena dokumentiert Perioden mit Beginn und optionalem Ende sowie Symptome, Stimmung, Energie und Notizen pro Tag. Kalender, allgemeine Ideen und ein JSON-Export ergänzen das lokale Tagebuch. Der nächste Periodenbeginn wird näherungsweise aus persönlichen Startabständen geschätzt.

**Online-Demo:** [Kuyena im Browser öffnen](https://kuyena.netlify.app/)

[Online ausprobieren](#online-ausprobieren) · [Lokal starten](#lokal-starten) ·
[Website aktualisieren](#website-aktualisieren)

## Online ausprobieren

Für die Online-Demo ist keine Installation von Flutter oder einer Handy-App
nötig. Zum Ausprobieren empfehlen wir einen aktuellen Chrome-Browser. Kuyena
öffnet zuerst die Handyansicht; auf großen Bildschirmen kann oben rechts zur
Desktopansicht gewechselt werden.

**Projektstand: Prototyp. Bitte ausschließlich erfundene Testdaten verwenden.**
Einträge werden im jeweiligen Browser gespeichert. Es gibt kein Benutzerkonto
und keine Synchronisation zwischen Geräten oder Browsern. Das Löschen von
Website-Daten kann die Einträge entfernen. Eine Sicherung kann unter
**Cycle → Sicherung & Wiederherstellung** erstellt werden.

### Kurzer Testablauf

1. [Online-Demo öffnen](https://kuyena.netlify.app/) und die Einrichtung starten.
   Für einen vollständigen Test einen erfundenen letzten Periodenzeitraum
   angeben, zum Beispiel Beginn vor zehn Tagen und Ende vor sechs Tagen.
   Weitere Angaben sind freiwillig und können offenbleiben.
2. Auf **Home** den Zyklus-Kreis und die vorläufige Phasenschätzung ansehen.
3. Über **+ / Log** für heute mindestens ein Symptom auswählen, bei Bedarf eine
   Notiz ergänzen und speichern. Die Symptomkarte auf Home sollte die gewählten
   Symptome zeigen.
4. Unter **Calendar** die eingetragenen Tage ansehen. Über
   **Periodentage bearbeiten** können vergangene Tage markiert oder entfernt
   werden; erst **Speichern** übernimmt die Änderung. Das Info-Symbol erklärt
   die Farben und Schätzungen.
5. Die Seite neu laden und prüfen, ob die Testeinträge noch vorhanden sind.

Die angezeigten Schätzungen sind ein vorläufiges Kalendermodell. Empfehlungen
zu Ernährung und Bewegung sind derzeit allgemeine Beispiele. Erinnerungen
funktionieren bisher nur bei geöffneter App. Weitere offene Punkte stehen im
[Backend-Stand](docs/backend-stand.md).

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
Der vollständige Ring zeigt eingetragene Periodentage rot, das geschätzte
Eisprungfenster rosa und die übrigen Tage sehr hellrosa. Ein Punkt markiert den ausgewählten Tag.
Das Datumsrad zeigt den Wert für den ausgewählten Tag, „Heute“ führt zurück.
Mit mindestens einem Startabstand zeigt der Kreis außerhalb einer
bestätigten Periode den ungefähren Countdown aus dem Mittelwert der dokumentierten
Startabstände. Zuvor dient die genau angegebene übliche Zykluslänge oder ein als allgemein gekennzeichneter 28-Tage-Startwert als Richtwert. Antippen erklärt die Rechnung. Ohne Periodenbeginn wird kein Datum erfunden; ein vergangener geschätzter
Termin wird als solcher angezeigt.

Die Regeln und die geplante Sprachumschaltung sind in [Phase und Symptome auf Home](docs/home-phase-symptome.md) einfach erklärt. Die Phasenschätzung wird später durch die vereinbarte Projektberechnung ersetzt.

## Lokal starten

Dieser Weg startet den Quellcode aus dem Repository auf dem eigenen Rechner.
Die Online-Demo kann unabhängig davon über den obigen Link verwendet werden.

### Voraussetzungen

- Flutter-SDK installiert und der Befehl `flutter` im Terminal verfügbar:
  [offizielle Flutter-Einrichtung](https://docs.flutter.dev/install).
- Geprüfte Ausgangsversion: **Flutter 3.47.7 mit Dart 3.13.5**. Dart wird mit
  Flutter mitgeliefert.
- Google Chrome installiert, um die Browserfassung zu starten.
- Das Repository lokal geklont oder als ZIP heruntergeladen und entpackt.

### Schritt für Schritt

1. Den Projektordner in VS Code öffnen. Gemeint ist der Ordner mit
   `pubspec.yaml`, `lib` und `web`.
2. Über **Terminal → Neues Terminal** ein Terminal in diesem Ordner öffnen.
3. Prüfen, ob Flutter verfügbar ist:

   ```bash
   flutter --version
   ```

4. Die benötigten Programmpakete laden:

   ```bash
   flutter pub get
   ```

5. Die App in Chrome starten:

   ```bash
   flutter run -d chrome --web-port 7357
   ```

   Das Terminal geöffnet lassen, solange die App läuft. Zum Beenden im
   Terminal **Strg + C** drücken. Eine `localhost`- oder `127.0.0.1`-Adresse
   ist nur auf dem Rechner erreichbar, auf dem die App gestartet wurde.

Beim erneuten Start denselben Web-Port verwenden: Browser-Speicher ist an
Protokoll, Hostname und Port gebunden. Die lokale Vorschau und die Online-Demo
haben daher getrennte Einträge. Bei späteren Starts ist normalerweise Schritt 5
ausreichend; nach Änderungen an den Abhängigkeiten erneut `flutter pub get`
ausführen.

### Code prüfen

Die vorhandene statische Analyse und die automatischen Tests lassen sich im
Projektordner so ausführen:

```bash
flutter analyze
flutter test
```

### Auf einem Handy oder im Simulator starten

Zunächst Emulator, Simulator oder ein angeschlossenes Gerät einrichten.
Android benötigt das Android SDK, iOS einen Mac mit vollständigem Xcode und
gegebenenfalls die passende Signierung. Die Werkzeuge für Android und iOS sind
für einen reinen Browserstart nicht erforderlich.

```bash
flutter devices
flutter run -d DEINE_GERAETE_ID
```

`DEINE_GERAETE_ID` durch die Kennung aus `flutter devices` ersetzen. Nach einer
Änderung an nativen Plugins die App vollständig neu starten; Hot Reload allein
registriert neue native Plugins nicht. Reale Gerätetests sind vor einer Nutzung
mit Gesundheitsdaten noch erforderlich.

### Häufige Startprobleme

| Problem | Nächster Schritt |
| --- | --- |
| `flutter: command not found` | Flutter installieren bzw. zum `PATH` hinzufügen und das Terminal neu öffnen; siehe [Flutter-Einrichtung](https://docs.flutter.dev/install). |
| `package:flutter/material.dart` wird nicht gefunden | Den Projektordner mit `pubspec.yaml` öffnen und dort `flutter pub get` ausführen. In VS Code prüfen, ob das Flutter-SDK erkannt wird. |
| Chrome wird als Zielgerät nicht gefunden | Chrome installieren und mit `flutter devices` prüfen, ob es erkannt wird. |
| Einträge aus einer anderen Vorschau fehlen | Dieselbe Adresse, denselben Port und dasselbe Browserprofil verwenden oder eine zuvor erstellte Sicherung importieren. |

## Website aktualisieren

Die Online-Demo liegt unter [kuyena.netlify.app](https://kuyena.netlify.app/).
Bei einem manuellen Netlify-Upload erscheinen lokale Codeänderungen erst nach
einem neuen Build und Upload online.

1. Änderungen speichern und die Codeprüfungen ausführen.
2. Im Projektordner die fertige Website erzeugen:

   ```bash
   flutter build web --no-web-resources-cdn
   ```

   Der Befehl erstellt bzw. aktualisiert den Ordner `build/web`. Die zusätzliche
   Option bündelt auch Flutters Web-Ressourcen lokal.
3. Bei Netlify das **vorhandene Kuyena-Projekt** öffnen und **Deploys** wählen.
4. Den vollständigen Ordner **`build/web`** in die Upload-Fläche ziehen. Er enthält
   unter anderem `index.html`, `flutter_bootstrap.js`, `main.dart.js` und die
   benötigten Assets. Der andere Ordner `web` direkt neben `lib` enthält die
   Ausgangsdateien und ist nicht der fertige Website-Ordner.
5. Auf die Veröffentlichung warten bzw. diese gegebenenfalls bestätigen.
6. Die bisherige Hauptadresse öffnen und den kurzen Testablauf wiederholen.
   Durch das Aktualisieren desselben Netlify-Projekts bleibt die Adresse erhalten.

Anleitung des Anbieters:
[Netlify: manuelle Aktualisierungen](https://docs.netlify.com/deploy/create-deploys/#drag-and-drop).

Die Browserfassung öffnet zuerst die Handyansicht, auch auf einem großen
Bildschirm. Sie ist dort mittig und höchstens 412 logische Pixel breit. Über
„Desktopansicht“ oben rechts lässt sich auf breiten Fenstern zur bisherigen
Desktopansicht wechseln; „Handyansicht“ führt zurück. Navigation und offene
Eingaben bleiben beim Wechsel erhalten. Auf schmalen Bildschirmen entfällt der
Umschalter. Ein Neuladen startet wieder in der Handyansicht. Die native Handy-App
verwendet weiterhin die verfügbare Bildschirmgröße.

Die README gehört zur Dokumentation im Git-Repository. Für reine Änderungen an
der README ist kein neuer Website-Build nötig; die geänderte README muss im
Repository gespeichert und per Commit und Push übernommen werden. Ein
Website-Upload ersetzt die Abgabe von Code und Dokumentation im Gruppen-Repository
nicht. Online-Demo und Repository können bei manuellen Uploads unterschiedliche
Stände haben.

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
Periodenzeitraum wird mit Beginn und angegebenem letztem Blutungstag übernommen. Die Dauer wird einschließlich beider Randtage berechnet und im Kalender angezeigt. Ein unbekanntes Ende wird weiterhin nicht erfunden. Im Log erscheinen
bevorzugte Symptome zuerst; alle weiteren bleiben erreichbar.

Erinnerungen erscheinen zur gewählten Uhrzeit innerhalb der geöffneten App.
Benachrichtigungen im Hintergrund sowie individuell geprüfte Rezept- und
Trainingsvorschläge sind noch nicht angebunden. Details: [Onboarding](docs/onboarding.md).


Home begrüßt neutral mit „Hallo“. Der Kreis zeigt den gesamten geschätzten Zyklus:
Rot für eingetragene Periodentage, Rosa für das geschätzte Eisprungfenster und sehr
helles Rosa für die übrigen Tage. Ein Punkt markiert den ausgewählten Tag.
Nach der Periode zählt die Mitte bis zum Eisprungfenster, nach diesem bis zur nächsten Periode.
Die frühere zusätzliche Vorhersagekarte auf Home entfällt. Geschätzter nächster
Periodenbeginn, Eisprungfenster und Rechnungsgrundlage stehen jetzt im Kalender.
Dort sind Schätzungen von tatsächlichen Einträgen unterscheidbar und im Bearbeitungsmodus ausgeblendet.
Der allgemeine Startwert ist vom persönlichen Richtwert bzw. beobachteten Mittelwert
unterscheidbar. Mehr Einträge garantieren keine höhere Vorhersagegenauigkeit.
