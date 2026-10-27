# Periodentag, wachsender Bogen und persönlicher Countdown

Stand: 26.10.2026. Der Kreis verwendet lokal dokumentierte Perioden.
Die übrigen Karten zu Phase, Beschwerden und Bewegung bleiben Designbeispiele.

## Speichern

Erst „Speichern“ übernimmt den Entwurf. Beginn, optionales Ende und die
freiwillige ausdrückliche Angabe „Periode läuft noch“ bleiben lokal auf
diesem Gerät bzw. in diesem Browser. Der Speicher bestätigt den geschriebenen
Wert durch erneutes Lesen. Es gibt weiterhin keine Cloud-Synchronisation
oder Sicherungskopie. Im Browser gehören Daten zur Adresse einschließlich
Port und Browserprofil.

Das aktuelle Dokumentformat ist Version 3. Version 1 und 2 bleiben lesbar;
ein altes unbekanntes Ende wird nicht automatisch als laufend interpretiert.
Bloßes Laden schreibt nichts um. Erst beim nächsten bestätigten Speichern
werden die vorhandenen Einträge zusammen mit der Änderung in Version 3
übernommen. Kennungen und Datumsangaben bleiben erhalten. Beschädigte oder
unbekannte Formate werden nicht durch leere Daten ersetzt.

Tageszahl, Ringanteil und Countdown werden berechnet und nicht zusätzlich
gespeichert. Nach Rückkehr von einer Änderung lädt Home erneut. Bei
Mitternacht folgt die Auswahl dem neuen Tag, wenn zuvor heute ausgewählt
war. Bewusst gewählte andere Tage bleiben ausgewählt. Bei Rückkehr aus dem
Hintergrund werden Datum und Einträge aktualisiert.

## Periode und Farbe

**Periodentag = Kalenderabstand seit Beginn + 1.** Beginn zählt als Tag 1.
Die Datumsrechnung zählt Kalendertage unabhängig von 23-/25-Stunden-Tagen.
Das Datumsrad zeigt den Wert für den ausgewählten Tag; „Heute“ führt zurück.

| Angaben | Bedeutung im Kreis |
| --- | --- |
| „Periode läuft noch“ ausdrücklich aktiviert | Rot, „Deine Periode – Tag N“. Ein zukünftiger Tag wird dadurch nicht als beobachtete Blutung bestätigt. |
| Ausgewählter Tag liegt zwischen dokumentiertem Beginn und Ende | Rot, dokumentierter Periodentag. Beginn und Ende sind eingeschlossen. |
| Keine bestätigte Periode, genug Beginne für eine Schätzung | Hellrosa, „Bis zur nächsten Periode – Noch ca. N Tage“. |
| Ende unbekannt, zu wenige Beginne | Hellrosa Startpunkt und „Noch offen“. Das bestätigt keine laufende Blutung. |
| Periode beendet, zu wenige Beginne | „Bis zur nächsten Periode – Noch offen“. |
| Kein Beginn am oder vor dem ausgewählten Tag | „Kein Eintrag“. |
| Widersprüchliche überschneidende Zeiträume | „Angaben prüfen“, keine geratene Zuordnung. |
| Lesefehler | „Nicht verfügbar“ mit erneutem Ladeversuch beim Antippen. |

„Periode läuft noch“ kann beim Eintragen oder über „Korrigieren“ aktiviert
werden. Das setzt ein vorhandenes Ende im Entwurf auf unbekannt. Ein
angegebenes Ende beendet die Markierung. Die Fachklasse lehnt beides
gleichzeitig ab. Die Markierung wird nicht aus einem fehlenden Ende geraten.

## Wie der Bogen wächst

Der Bogen beginnt oben und wächst im Uhrzeigersinn. Es gibt keinen ständig
vollständig eingefärbten Hintergrundring. Eine kurze Animation zeichnet
von null bis zum berechneten Anteil. Ein neuer Beginn setzt den Bogen an
den Startpunkt zurück. Reduzierte Bewegung wird berücksichtigt.

Mit Zyklusschätzung ist der Anteil:

**Abstand seit letztem Beginn / geschätzte Zykluslänge**, begrenzt auf 0 bis 1.

Tag 1 beginnt bei null. Ohne Zyklusschätzung kann ein vollständig
dokumentierter Periodenzeitraum als Maßstab dienen: erster Tag am Start,
Endtag am Ende. Ohne bekannten Maßstab bleibt ein farbiger Startpunkt statt
eines erfundenen Prozentwerts. Die Tageszahl wird trotzdem angezeigt.

## Formel aus persönlichen Einträgen

1. Abstände zwischen aufeinanderfolgenden Periodenbeginnen in Kalendertagen zählen.
2. Von den letzten höchstens sechs Abständen den Median berechnen.
3. Letzter Beginn plus Median ergibt den geschätzten nächsten Beginn.
4. Abstand vom ausgewählten Tag zu diesem Datum ergibt den Countdown.

Bei 26, 28 und 30 Tagen ist der Median 28. Bei einer geraden Anzahl wird
der Mittelwert der beiden mittleren Werte auf ganze Tage gerundet. Es
wird keine feste Zykluslänge von 28 Tagen unterstellt. Für diese einfache
Rechnung braucht man keine zusätzlichen Angaben etwa zu Gewicht.

Mindestens drei Beginne, also zwei Abstände, sind die bewusst einfache
Produktregel dieses Prototyps. Das ist keine medizinisch validierte
Genauigkeitsschwelle. Bei widersprüchlichen dokumentierten Zeiträumen gibt
es keine Schätzung. Spätere Beginne werden für eine historische Auswahl
nicht benutzt. Eingetragene zukünftige Beginne werden ebenfalls nicht als
bereits beobachtete Grundlage verwendet.

Die Anzeige sagt „Noch ca. N Tage“ oder „Ca. heute“. Ist der geschätzte
Termin vorbei, steht dort „Termin vorbei“ mit dem erwarteten Datum. Es
wird weder ein neuer Beginn erfunden noch der Countdown automatisch um
einen Zyklus weitergeschoben. Beim Antippen sind Median, Anzahl und
Spannweite der verwendeten Abstände und das geschätzte Datum nachlesbar.
Die Spannweite beschreibt vorhandene Einträge, kein Vertrauensintervall.

Die Schätzung ist ein nachvollziehbarer erster Prototyp. Fehlende Einträge
und wechselnde Zykluslängen können sie deutlich verändern. Die
[Studie zur Vorhersage unter Berücksichtigung der Tracking-Vollständigkeit](https://pubmed.ncbi.nlm.nih.gov/34534312/)
vergleicht unter anderem Mittelwert und Median mit einem weitergehenden
Modell; sie validiert diesen hier vereinfachten Prototyp nicht. Eine
[Untersuchung von Periodentracker-Vorhersagen](https://pmc.ncbi.nlm.nih.gov/articles/PMC8504278/)
zeigt ebenfalls die Grenzen fester Vorhersagedaten.

## Vom Kurs zum Code

- `CalendarDate`: Abstand und Addition von Kalendertagen ohne Zeitzonenverschiebung.
- `Period`: Kennung, Beginn, optionales Ende und ausdrücklich bestätigte laufende Periode.
- `CycleEstimate`: Median und geschätzter nächster Beginn, ohne Speicherzugriff.
- `PeriodDayOverview`: berechnete Übersicht für den ausgewählten Tag.
- `PeriodStatusRing`: animierter, passend gefärbter Bogen und Beschriftung.
- `PeriodDiary` und Repository: bestätigte Änderungen und Erhalt alter Daten.

Die Anzeigefälle sind kein biologischer Zustandsautomat. Der nächste
Periodenbeginn wird nicht als sicher oder medizinisch bestätigt dargestellt.

## Prüfung

Am 26.10.2026: alle 86 automatisierten Tests bestanden, Codeprüfung ohne
Probleme und Browser-Build erfolgreich. Geprüft sind insbesondere Median,
Datenminimum, Begrenzung auf sechs Abstände, Start bei null, Animation,
Farbe, Zurücksetzen bei neuem Beginn, reduzierte Bewegung, vergangener
Schätztermin, aktive Markierung und Erhalt alter Speicherformate.
Die Tests verwenden ausschließlich erfundene Angaben.

## KI-Nutzung

26.10.2026: Codex hat auf Wunsch der nutzenden Person Tageszähler, animierten
Bogen, Farbwechsel und Median-Schätzung aus persönlichen Periodenbeginnen
umgesetzt. Dazu kommen eine ausdrückliche laufende Markierung und das
abwärtskompatible Lesen alter Dokumente. Die Erklärung und Tests verwenden
erfundene Beispiele; reale Android-/iOS-Gerätetests stehen weiterhin aus.
