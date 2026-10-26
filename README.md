# Kuyena

Lokales Zyklustagebuch mit Flutter und Dart für Android, iPhone und Browser.
Der erste Funktionsumfang dokumentiert Perioden mit Beginn und optionalem Ende. Symptome,
Vorhersagen, Empfehlungen und Export sind noch nicht implementiert.

## Aktueller Ablauf

- Beginn und optionales Ende erfassen, Verlauf anzeigen, Angaben korrigieren.
- Ein Ende später ergänzen oder wieder als unbekannt angeben.
- Einzelne oder alle Einträge nach Bestätigung löschen.
- Einträge beim erneuten Öffnen aus dem lokalen Speicher laden.
- Keine Konten, keine Synchronisation und kein Backend für Gesundheitsdaten.

Über den Plusknopf auf Home oder „Periode eintragen“ im Verlauf öffnet sich
die Eingabemaske. Beginn wählen, bei Bedarf „Ende (optional)“ auswählen und
„Speichern“ drücken. Bestehende Einträge lassen sich über „Korrigieren“
bearbeiten. Ein leeres Ende bedeutet unbekannt. Angegebene Enddaten müssen
zwischen Beginn und heute liegen. Abbrechen speichert keine Änderungen.

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
Speichern werden sie zusammen mit den Änderungen in Version 2 übernommen.
Der bisherige Speicherschlüssel bleibt erhalten. Ein bloßes Öffnen schreibt
die Daten nicht um; beschädigte oder unbekannte Formate werden gemeldet.

## Kursdokumentation

[Periodenmodell, Erklärung und aktueller Speicherablauf](docs/periodenmodell.md)

[Erster Meilenstein: Periodenbeginn (Stand 18.10.2026)](docs/periodenbeginn.md)

## Quellen

- [Flutter Secure Storage: Plattformen, Android-Backup, iOS-Konfiguration und Web-Grenzen](https://pub.dev/packages/flutter_secure_storage)
- [Web-Implementierung und HTTPS-Anforderung](https://pub.dev/packages/flutter_secure_storage_web)
- [Browser-Speicher und Origin](https://developer.mozilla.org/en-US/docs/Web/API/Window/localStorage)
