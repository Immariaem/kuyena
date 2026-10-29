# Einrichtung und persönliche Einstellungen

Die beiden Figma-Frames `240:2653` und `259:4211` liefern Begrüßung und
Datenschutzseite. Die sieben beigefügten Bildschirm-Entwürfe liefern den Ablauf:
Zyklusdaten, Ziele, Tracking, Bewegung, Ernährung, Erinnerungen, Zusammenfassung.
Texte sind gemäß Projektvorgabe auf Deutsch; Farben, Nunito Sans, Maskottchen,
rosa Auswahlflächen und runde Übergänge verwenden die bestehenden Designmittel.
Die Maskottchen-PNG und der Datenschutzpunkt wurden aus Figma lokal übernommen.
Systemleisten im Browser verwenden die bereits vorhandenen identischen Assets.

## Was funktioniert

- Freiwillige Fragen, unbekannte Antworten, Überspringen und Zurücknavigation.
- Mehrfachauswahl bei Zielen, Symptomen, Bewegung, Interessen und Allergien.
- Explizites „Keine“ bei Allergien schließt andere Allergien aus; freier Zusatz möglich.
- Datum nicht in der Zukunft; grobe Perioden- und Zykluslängen sowie optionale genaue Zykluslänge.
- Stimmung/Energie und Notizen als einstellbare Tracking-Präferenzen.
- Uhrzeit und zwei unabhängige Wünsche für tägliche bzw. Perioden-Hinweise.
- Entwurf wird beim Weitergehen lokal gespeichert. Beim erneuten Öffnen geht es
  beim zuletzt gespeicherten Schritt weiter. Die Zusammenfassung zeigt auch die
  Angaben aus Freitextfeldern und erlaubt Änderungen vor dem Start.
- Abgeschlossene Einrichtung wird nicht erneut vorgeschaltet. Frühere Einträge
  bleiben erhalten. Bei vorhandenen Einträgen wird der letzte Beginn vorausgefüllt.
- Unter Cycle & App → Deine Angaben & Einstellungen werden dieselben Formulare
  wiederverwendet. Dort bleiben Änderungen bis zum Speichern ein Entwurf;
  Abbrechen mit Nachfrage verwirft ihn. Die Erinnerungseinstellungen sind zusätzlich
  direkt über die bestehende Reminders-Zeile erreichbar.
- Zeitraumkorrekturen bleiben unter Edit cycle data und im Kalender erreichbar.
  Die ursprüngliche Startangabe im Profil wird später nicht erneut in den Kalender kopiert.
- Alle zehn auswählbaren Symptome lassen sich tatsächlich im Log dokumentieren.
  Bevorzugte Symptome stehen zuerst, andere sind über Weitere Symptome erreichbar.
  Frühere Beobachtungen verschwinden durch das Abschalten einer Präferenz nicht.

## Welche Aussagen bewusst genau bleiben

Die erste gemeldete Periode wird atomar zusammen mit dem Abschluss der
Einrichtung gespeichert. Bekannt ist nur ihr Beginn. Übliche Periodendauer
bedeutet nicht, dass ein tatsächliches Ende oder weitere Blutungstage bekannt sind.
Ein bereits vorhandener identischer Beginn wird nicht dupliziert; Konflikte und
entgegengesetzte Kalenderkorrekturen werden zur Prüfung zurückgegeben.

Der nächste Periodenbeginn ergibt sich aus letztem Beginn plus gerundetem
arithmetischem Mittelwert der verfügbaren Startabstände. Ohne Startabstand ist
eine ausdrücklich eingegebene genaue Zykluslänge der erste Richtwert. Ein bloßer
Bereich wird nicht automatisch in eine Zahl verwandelt. Es gibt keine 28-Tage-Vorgabe.
Prognosen werden nicht automatisch als tatsächliche Perioden eingetragen und
nach einem verstrichenen Termin nicht in den nächsten Monat weitergeschoben.

Das zusätzliche grobe Phasenfenster ist keine Eisprungmessung. Die [NHS-Erklärung
zum Menstruationszyklus](https://www.nhs.uk/conditions/periods/fertility-in-the-menstrual-cycle/)
beschreibt, dass der Abstand zwischen Eisprung und nächster Periode variieren
kann. Die App bestätigt keinen Eisprung und bestimmt keine sicheren/fruchtbaren
Tage zur Verhütung. Ohne tatsächliches Periodenende kann die Phase unbekannt bleiben.

Die gewählte Uhrzeit steuert Hinweise innerhalb der geöffneten App. Ein
Perioden-Hinweis erscheint am geschätzten Beginn und bis zu zwei Tage vorher,
ein täglicher Hinweis nur ohne Tageseintrag. Hinweise sind für den Tag wegklickbar.
Es werden keine Systemrechte angefordert. Push-/Sperrbildschirm-Benachrichtigungen
und Hintergrundplanung sind noch nicht umgesetzt. Die Texte sagen das ausdrücklich.

Ernährungs- und Bewegungsangaben werden gespeichert und sind editierbar. Die
bestehenden allgemeinen Inhalte werden dadurch noch nicht zu individuell
medizinisch geprüften Trainingsplänen oder allergiegeprüften Rezepten. Dafür
fehlen die fachlichen Inhalte und Regeln; die Formulare versprechen keine solche Prüfung.

## Speicherung und Sicherung

`UserProfile` enthält eine versionierte, validierte Auswahl ohne medizinische
Standardwerte. `ProfileController` verbindet sie mit der Oberfläche. Die vorhandene
lokale Datenbasis erhält eine dritte Sektion für die Einstellungen. Der Schlüssel
bleibt `kuyena.local_data.v1`; die Dokumentversion darin ist jetzt 2. Version 1 und
beide alten getrennten Speicherformate bleiben lesbar. Perioden- und Journaländerungen
erhalten die Profileinstellungen. Derselbe Lock verhindert verlorene parallele Änderungen.
Veraltete Einstellungen überschreiben keine neueren; fehlgeschlagene Schreibvorgänge
werden als Fehler angezeigt. Beschädigte Daten werden nicht mit einem leeren Profil ersetzt.

Exportversion 3 enthält das Profil in der bestehenden passwortgeschützten Sicherung
bzw. im ausdrücklich lesbaren JSON-Export. Exportversionen 1 und 2 bleiben importierbar;
sie enthalten kein Profil. Die Vorschau nennt diesen Unterschied. Wiederherstellung
ersetzt alle enthaltenen Bereiche gemeinsam, das vollständige Löschen entfernt auch
die Einstellungen und setzt die Einrichtung zurück.

Die automatisierten Tests verwenden erfundene Angaben und prüfen Speicherung,
Migration, Konflikte, Rücknavigation, Bearbeitung, Wiederöffnung, Datum/Uhrzeit,
Tracking, Berechnung und kleine/größere Ansichten mit vergrößerter Schrift.
Reale Android-/iOS-Gerätetests sind weiterhin separat erforderlich.
