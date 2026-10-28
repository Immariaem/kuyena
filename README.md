# Kuyena

Lokales Zyklustagebuch mit Flutter und Dart für Android, iPhone und Browser.
Kuyena dokumentiert Perioden mit Beginn und optionalem Ende sowie Symptome, Stimmung, Energie und Notizen pro Tag. Kalender, allgemeine Ideen und ein JSON-Export ergänzen das lokale Tagebuch. Der nächste Periodenbeginn wird näherungsweise aus persönlichen Startabständen geschätzt.

## Aktueller Ablauf

- Mit + / Log ein Datum wählen und Symptome, Blutungsstärke, Stimmung, Energie oder eine Notiz speichern.
- Tageseinträge im Kalender wieder öffnen und bearbeiten.
- Unter Cycle → Edit cycle data Periodenbeginn und optionales Ende erfassen und korrigieren.
- Ein Ende später ergänzen oder wieder als unbekannt angeben.
- „Periode läuft noch“ ausdrücklich markieren und mit einem Enddatum beenden.
- Auf Home Tage seit Beginn bzw. den dokumentierten Periodentag im Kreis anzeigen.
- Einzelne oder alle Einträge nach Bestätigung löschen.
- Einträge beim erneuten Öffnen aus dem lokalen Speicher laden.
- Keine Konten, keine Synchronisation und kein Backend für Gesundheitsdaten.

Der Plusknopf öffnet zunächst die Datumsauswahl für einen Tageseintrag.
Die Periodenerfassung erreichst du über Cycle → Edit cycle data →
„Periode eintragen“. Dort Beginn wählen, bei Bedarf „Ende (optional)“ auswählen und
„Speichern“ drücken. Bestehende Einträge lassen sich über „Korrigieren“
bearbeiten. Ein leeres Ende bedeutet unbekannt. Angegebene Enddaten müssen
zwischen Beginn und heute liegen. Abbrechen speichert keine Änderungen.

Nach Rückkehr zu Home wird der Kreis aktualisiert: Beginn zählt als Tag 1.
Ein unbekanntes Ende wird nicht automatisch als laufende Periode interpretiert.
Die ausdrückliche Markierung „Periode läuft noch“ macht den Bogen rot,
sonst ist er hellrosa. Er baut sich von oben im Uhrzeigersinn auf.
Das Datumsrad zeigt den Wert für den ausgewählten Tag, „Heute“ führt zurück.
Mit mindestens drei Periodenbeginnen zeigt der Kreis außerhalb einer
bestätigten Periode den ungefähren Countdown aus dem Median der letzten
bis zu sechs Startabstände. Antippen erklärt die Rechnung. Zu wenige
Angaben ergeben keine erfundene Standardlänge; ein vergangener geschätzter
Termin wird als solcher angezeigt.

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
deaktiviert. Die Löschfunktion entfernt ausschließlich Kuyenas Periodendokument.

Die Web-Implementierung des Plugins ist upstream **experimentell**. Sie benötigt
HTTPS oder localhost. Browser-Schlüssel liegen ebenfalls im Browserprofil;
dies ist keine Passwortsperre und kein Schutz vor Schadcode derselben Origin
oder Personen mit Zugriff auf das Browserprofil. Die Browserfassung verwendet
deshalb vorerst **Testdaten**. Das Löschen von Website-Daten, ein privates
Browserfenster und Speicherbereinigung können Daten entfernen. Es gibt noch
keinen Export oder Wiederherstellungsweg. Auf Mobilgeräten sind reale
Gerätetests vor einer Nutzung mit Gesundheitsdaten ebenfalls erforderlich.

Vorgänge werden innerhalb einer App-Instanz nacheinander ausgeführt.
Mehrere gleichzeitig bearbeitende Browser-Tabs werden noch nicht koordiniert.
Für eine größere Symptomdatenbank ist die Speicherung neu zu bewerten.

Bereits gespeicherte Periodenbeginne aus Dokumentversion 1 werden mit
unverändertem Datum und unbekanntem Ende gelesen. Beim nächsten bestätigten
Speichern werden sie zusammen mit den Änderungen in Version 3 übernommen.
Version-2-Perioden ohne Aktiv-Markierung bleiben ebenfalls lesbar;
ihre unbekannten Enden bleiben unbekannt.
Der bisherige Speicherschlüssel bleibt erhalten. Ein bloßes Öffnen schreibt
die Daten nicht um; beschädigte oder unbekannte Formate werden gemeldet.

## Kursdokumentation

[Periodenmodell, Erklärung und aktueller Speicherablauf](docs/periodenmodell.md)

[Tageszähler im Kreis und Berechnung aus den gespeicherten Angaben](docs/periodentag.md)

[Erster Meilenstein: Periodenbeginn (Stand 18.10.2026)](docs/periodenbeginn.md)

## Quellen

- [Flutter Secure Storage: Plattformen, Android-Backup, iOS-Konfiguration und Web-Grenzen](https://pub.dev/packages/flutter_secure_storage)
- [Web-Implementierung und HTTPS-Anforderung](https://pub.dev/packages/flutter_secure_storage_web)
- [Browser-Speicher und Origin](https://developer.mozilla.org/en-US/docs/Web/API/Window/localStorage)


## Weitere Figma-Seiten

Kalender, Ansichtsmenü, Tageseintrag, Datumsauswahl, Empfehlungen, Cycle & App und Startbildschirm sind umgesetzt. Die Navigation und lokalen Funktionen sind in [docs/figma-seiten.md](docs/figma-seiten.md) erklärt. Mit **+ / Log** wird ein Tageseintrag erfasst; Periodenbeginn und -ende verwaltest du unter **Cycle → Edit cycle data**.
