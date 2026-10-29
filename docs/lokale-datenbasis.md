# Lokale Datenbasis, Sicherung und Wiederherstellung

Stand: 29.10.2026. Geltungsbereich: lokale erste Version für Handy und Browser. Es gibt keinen Server für Gesundheitsdaten, keine Konten und keine automatische Cloud-Synchronisation. Berechnungen und Empfehlungen erhalten durch diesen Schritt keine neuen medizinischen Regeln.

## Einfach erklärt

Die App hat bisher Perioden und Tageseinträge in zwei getrennten Speicherwerten aufbewahrt. Jetzt liegen beide Bereiche gemeinsam in einem versionierten Speicherwert. Dadurch kann eine Wiederherstellung den gesamten Stand mit einem Schreibvorgang übernehmen. Symptome und Periodentage bleiben weiterhin unabhängig bearbeitbar.

Unter **Cycle → Sicherung & Wiederherstellung** gibt es zwei Wege:

1. **Neue Sicherung erstellen:** Passwort mit mindestens zwölf Zeichen zweimal eingeben. „Sicherung vorbereiten“ verschlüsselt die Daten. Erst „Datei speichern“ öffnet die Dateiauswahl bzw. startet den Browser-Download. Die Datei enthält den Stand ihrer Erstellung; spätere Änderungen erfordern eine neue Sicherung.
2. **Wiederherstellen:** Datei auswählen, bei verschlüsselten Dateien das Passwort eingeben, „Sicherung prüfen“ wählen. Die Vorschau zeigt Perioden, Tageseinträge, Kalenderkorrekturen und Erinnerungen. Erst „Wiederherstellen“ und „Daten ersetzen“ übernehmen den Inhalt. Es wird vollständig ersetzt, nicht zusammengeführt. Vorherige Daten gegebenenfalls zuerst sichern.

Das Passwort wird nicht gespeichert und ist nicht wiederherstellbar. Ein langes, eigenes Passwort wählen und getrennt aufbewahren. Ein falsches Passwort oder eine veränderte Datei führt zu keiner Übernahme. Es gibt keinen Upload durch Kuyena. Wählt man selbst einen synchronisierten Ordner für die Datei, bestimmt dessen Anbieter die weitere Übertragung.

Der bisherige **Export data** zeigt weiter unverschlüsseltes JSON zum bewussten Kopieren. Dieses Format ist lesbar ohne Passwort. Importiert werden Kuyena-JSON-Exporte Version 1 und 2 sowie die neue verschlüsselte Sicherung. Dateinamen und Erweiterungen gelten nicht als Vertrauensnachweis; geprüft wird der Inhalt.

## Speicher und Übernahme vorhandener Daten

`LocalAppStore` verwendet über `flutter_secure_storage` den Schlüssel `kuyena.local_data.v1`. Der Umschlag enthält Version 1, eine zufällige Generation und die beiden bisherigen versionierten Dokumente. Periodenformate 1–3 und Journalformate 1–2 bleiben lesbar. Die Generation und ein SHA-256-Fingerabdruck erkennen veraltete Wiederherstellungsvorschauen; sie sind kein Ersatz für Verschlüsselung und enthalten kein Passwort.

Beim ersten erfolgreichen Laden liest die App die bisherigen Schlüssel `kuyena.period_starts.v1` und `kuyena.day_journal.v1`, prüft beide, schreibt die gemeinsame Kopie und liest sie zur Bestätigung zurück. Erst danach werden die bisherigen Schlüssel entfernt. Ein Schreibfehler erhält die Originale. Wird die Bereinigung unterbrochen, bleibt die bereits bestätigte Kopie maßgeblich; die Bereinigung wird erneut versucht. Beschädigte alte oder neue Dokumente werden nicht automatisch durch leere Daten überschrieben.

Eine ausdrückliche Wiederherstellung kann auch einen beschädigten aktuellen Speicher ersetzen. Der Inhalt der gewählten Datei muss vorher gültig sein und die Nutzerin muss das Ersetzen bestätigen. Ein unveränderter Fingerabdruck wird unmittelbar vor dem Schreiben unter derselben Sperre geprüft.

**Delete all local data** schreibt zuerst einen leeren gemeinsamen Stand und entfernt auch die alten Schlüssel. Dadurch können alte Daten nach einem Abbruch nicht wieder auftauchen. Es bleiben nur Format- und zufällige Generationsangaben zur Konflikterkennung erhalten, keine Perioden, Tageseinträge, Kalenderkorrekturen oder Erinnerungseinstellungen. Eine unvollständige Bereinigung wird gemeldet. Externe Sicherungsdateien werden durch diese Funktion nicht gelöscht.

## Gleichzeitige Änderungen

`DataLock` schützt vollständige Lese-/Änderungs-/Schreibvorgänge und erlaubt verschachtelte Use Cases. In der produktiven App teilen PeriodDiary, DayJournal und LocalAppStore dieselbe Sperre. Im Browser wird zusätzlich die Web Locks API mit einem festen Namen für dieselbe Origin verwendet. Fehlt diese API, wird der Zugriff abgewiesen; es gibt keinen stillen ungeschützten Schreibmodus.

Unabhängige Änderungen an verschiedenen Tagen werden aus dem aktuellen Speicher zusammengeführt. Ein bereits anderweitig geänderter Wohlbefindenseintrag wird durch eine ältere offene Eingabe weder überschrieben noch gelöscht. Neue Blutungsangaben können weiterhin mit einem unveränderten Wohlbefindensentwurf zusammengeführt werden. Manuelle Datumskorrekturen und Löschungen prüfen den zuvor angezeigten Periodeneintrag. Der Kalendereditor prüft weiterhin seine Ausgangsauswahl. Wiederherstellungen prüfen den gesamten Ausgangsstand.

Nach einem Update alle offenen Tabs neu laden: frühere Versionen kennen weder den gemeinsamen Schlüssel noch die neue Sperre. Verschiedene Ports, Browserprofile und Geräte bleiben getrennte Speicher. Beim erneuten Aktivieren aktualisieren Kalender und Cycle ihre geladenen Daten; Home hat seine bestehende Aktualisierung. Ein gerade aktiv sichtbarer Tab erhält noch keine laufende Hintergrundübertragung jeder Änderung aus einem anderen Tab.

## Sicherungsformat und Grenzen

Die neue Datei endet auf `.kuyena`. Sie enthält einen JSON-Umschlag mit Format `kuyena-backup`, Version 1, PBKDF2-HMAC-SHA256 mit 600.000 Iterationen, zufälligem 16-Byte-Salt, AES-256-GCM mit zufälligem 12-Byte-Nonce, verschlüsseltem Inhalt und 16-Byte-Authentifizierungstag. Feste zusätzliche Authentifizierungsdaten binden Format und Algorithmen. Das KDF erzeugt einen 256-Bit-Schlüssel; der abgeleitete Schlüssel wird nach Verwendung freigegeben. Implementierung über `cryptography`, mit `cryptography_flutter` für die nativen Plattformen. Keine selbst implementierte Verschlüsselungsprimitive.

Unbekannte Versionen/Algorithmen und unerwartete Parameter werden vor der Schlüsselableitung abgewiesen. So können importierte Dateien keine beliebig teure Schlüsselableitung verlangen. Das Passwort wird nicht getrimmt oder normalisiert, UTF-8 und Unicode bleiben erhalten; maximal 1024 Passwortbytes sind erlaubt. Die Oberfläche leert Passwortfelder nach erfolgreicher Verwendung und beim Schließen. Eine vollständige garantierte Speicherlöschung von Dart-Strings ist damit nicht zugesichert.

Dateien sind auf 12 MiB, unverschlüsselter Inhalt auf 8 MiB und die Gesamtzahl der importierten Datensätze auf 50.000 begrenzt. Doppelte Kennungen, doppelte Datumsangaben, ungültige Kalenderdaten, ungültige Typen/Enums, leere Tageseinträge und künftige Beobachtungen werden abgewiesen. Bestehende nachvollziehbare Überschneidungen werden erhalten und wie bisher als prüfbedürftig angezeigt. Es werden keine Periodenenden oder Zykluslängen beim Import erfunden.

Die Sicherungsdatei schützt den exportierten Inhalt bei einem geeigneten Passwort. Der Schutz des laufenden App-Speichers bleibt plattformabhängig. Im Browser liegen Schlüssel und Daten im Browserprofil derselben Origin; dies schützt nicht gegen Schadcode auf derselben Origin oder Personen mit Zugriff auf ein entsperrtes Profil. HTTPS bzw. localhost ist nötig. Website-Datenbereinigung kann weiterhin alle lokalen Daten entfernen. Auf Android bleibt automatisches App-Backup deaktiviert; iOS verwendet weiterhin den Zugriff auf dem entsperrten Gerät ohne Keychain-Synchronisation.

## Prüfung und verbleibende Arbeit

Automatisierte Tests decken Übernahme älterer Formate, Schreibfehler, unterbrochene Bereinigung, gemeinsames Speichern, verschachtelte Sperren, veraltete Eingaben, vollständige Löschung, sichere Vorschau, beschädigte und zu große Dateien sowie echte Verschlüsselung mit falschem Passwort und verändertem Authentifizierungstag ab. Oberflächentests verwenden ausschließlich Testspeicher und prüfen Bestätigung, Abbrechen, Fehlversuche und kleine/breite Ansichten mit größerer Schrift. Ein eigener Browser-Test prüft Web Locks mit zwei unabhängigen Sperrinstanzen. Dateiauswahl ist als Grenze für Tests austauschbar.

Vor Nutzung als veröffentlichtes Gesundheitsprodukt fehlen weiterhin reale Android-/iPhone-Gerätetests, Prüfung von App-Update/Neuinstallation und nativen Dateiablagen sowie eine unabhängige Sicherheits- und Datenschutzprüfung. Die hier beschriebenen Tests sind keine solche Freigabe. Onboarding, Sprachauswahl, neue persönliche Einstellungen, endgültige fachliche Berechnungen und persönliche Empfehlungsregeln folgen ihren eigenen Anforderungen.

## Technische Quellen

- [Web Locks API – MDN](https://developer.mozilla.org/en-US/docs/Web/API/Web_Locks_API)
- [cryptography – Paket und API](https://pub.dev/packages/cryptography)
- [cryptography_flutter – native Implementierungen](https://pub.dev/packages/cryptography_flutter)
- [file_picker – Dateiauswahl und Speichern](https://pub.dev/packages/file_picker)
- [OWASP: PBKDF2-Arbeitsfaktor](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html#pbkdf2)


## Erweiterung um die Einrichtung (29.10.2026)

Die gespeicherte Dokumentversion ist jetzt 2; zusätzlich zu Perioden und Journal
enthält sie die validierten persönlichen Einstellungen. Die Speicheradresse bleibt
gleich und Dokumentversion 1 ist weiterhin lesbar. Exportversion 3 nimmt das Profil
in dieselbe atomare Sicherung auf; frühere Exporte ohne Profil bleiben importierbar.
Das vollständige Löschen entfernt auch diese Angaben. Siehe [Onboarding](onboarding.md).
