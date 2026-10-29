# Phase und Symptome auf Home

Stand: 29.10.2026. Vorläufige Umsetzung bis zur Festlegung der Projektberechnung.

## Was sich für die Nutzerin ändert

Beide Karten beziehen sich auf den Tag in der Mitte des Datumsrads. Ein anderer Tag zeigt dessen Angaben. Nach dem Speichern, Bearbeiten oder Löschen im Log werden die Karten beim Zurückkehren aktualisiert. „Heute“ springt zum aktuellen Datum und lädt erneut. Beim Tageswechsel folgt die Auswahl dem neuen Tag, wenn zuvor heute ausgewählt war.

- **Current phase / Phase on this day:** Dokumentierte Perioden zeigen „Menstruation“. Dafür wird dieselbe Periodenübersicht wie im Kreis verwendet. Beginn und Ende werden separat vom Wohlbefinden erfasst. Für ältere Blutungsangaben bleibt die bisherige None-Regel erhalten.
- **Estimated phase:** Weitere Phasen sind ausschließlich vorläufige Kalenderschätzungen. Ein Tipp erklärt Grundlage und Grenzen. Es wird kein Eisprung bestätigt.
- **Phase unknown:** Ohne passende Angaben wird keine Phase erfunden. Das gilt beispielsweise bei fehlendem Beginn, unbekanntem Ende, zu wenig Verlauf, widersprüchlichen Zeiträumen oder erreichtem geschätztem nächsten Beginn ohne neuen Eintrag.
- **Logged symptoms:** Alle ausgewählten Symptome aus dem Tageseintrag werden angezeigt, unabhängig von einer Periode. Andere Tage und Beschwerden aus dem Figma-Beispiel werden nicht dazugemischt.
- **Possible symptoms:** Wenn keine Symptome ausgewählt wurden, bleibt vorerst „Cramps“ als Designbeispiel stehen. „Example · not a prediction“ und die antippbare Erklärung machen dies sichtbar. Ein leerer Symptomwert bestätigt nicht ausdrücklich Beschwerdefreiheit.
- **Lesefehler:** Beide Karten zeigen „Unavailable“ statt alte Angaben oder Beispiele als aktuelle Daten auszugeben. Antippen lädt erneut.

Die Bewegungsideen bleiben allgemeine Beispiele. Sie werden durch diese Änderung nicht zu persönlichen Gesundheitsempfehlungen.

## Wie die vorläufige Phase berechnet wird

Zuerst wird wie bisher aus manuellen Perioden und Blutungsangaben im Log eine gemeinsame Übersicht berechnet. Daraus liest `CyclePhaseOverview` den ausgewählten Tag. Diese eigene, kleine Berechnung lässt sich später ersetzen, ohne Speicher oder Oberfläche neu aufzubauen.

Für eine Schätzung nach der Periode werden mindestens drei Periodenbeginne benötigt. Aus den jüngsten bis zu sechs Start-zu-Start-Abständen wird der Median genommen. Diese bereits vorhandene Rechnung liefert den geschätzten nächsten Beginn. Es wird keine feste Zykluslänge von 28 Tagen angenommen. Die Mindestzahl ist eine vorläufige Produktentscheidung, keine medizinische Zuverlässigkeitsgrenze.

Als grobe Orientierung wird ein Zeitraum 10–16 Tage vor dem geschätzten nächsten Beginn als „Around ovulation“ bezeichnet. Der NHS nennt ungefähr diesen Abstand zwischen Eisprung und folgender Periode und betont, dass der genaue Zeitpunkt schwer festzustellen ist. Die Übertragung auf eine erst geschätzte nächste Periode ist unsere vorläufige Modellannahme, keine medizinisch bestätigte individuelle Phase. [Quelle: NHS – Periods and fertility in the menstrual cycle](https://www.nhs.uk/conditions/periods/fertility-in-the-menstrual-cycle/).

Nach dem bekannten Periodenende und vor diesem Zeitraum zeigt die Karte „Follicular phase“, danach bis zum geschätzten nächsten Beginn „Luteal phase“. Menstruation wird in der Oberfläche gesondert dargestellt, obwohl sie biologisch zur Follikelphase gehört. Lässt sich dieser vereinfachte Ablauf nicht mit den Datumsangaben vereinbaren, bleibt die Phase unbekannt. Symptome werden nicht zur Erkennung einer Phase benutzt. Es werden keine fruchtbaren oder sicheren Tage ausgewiesen.

Die Rechnung benutzt nur Periodenbeginne bis zum ausgewählten Tag und bis heute. Ein späterer Beginn wird nicht vorweggenommen. Ein erreichter Schätztermin erzeugt keinen neuen Zyklus. Auch die errechnete Phase wird nicht gespeichert; die dokumentierten Angaben bleiben die Grundlage.

## Deutsch und Englisch

Eine vollständige Sprachumschaltung ist für einen eigenen folgenden Schritt vorgesehen, sobald Texte und Berechnungen feststehen. Jetzt bleiben die englischen Designtexte und die bestehenden deutschen Hinweise erhalten. Es gibt keinen Schalter, der nur Teile der App übersetzt.

Der spätere Schritt umfasst zentrale Übersetzungstexte (Flutter-Lokalisierung), Datums- und Zahlenformate, Deutsch/Englisch unter Cycle → App settings sowie das lokale Merken der Auswahl. Die gespeicherten Beobachtungen verwenden bereits sprachunabhängige Werte wie `cramps` oder `light`; dafür müssen keine Gesundheitsdaten übersetzt oder migriert werden.

## Prüfung

Tests prüfen die Phasenübergänge und ihre Grenzen, andere persönliche Zykluslängen, zu wenige Angaben, unbekannte Enden, überlappende Perioden und ausbleibende neue Beginne. Oberflächentests prüfen Tageswechsel im Datumsrad, Speichern/Bearbeiten/Löschen und erneutes Öffnen der Symptome, Lesefehler mit erneutem Laden sowie alle vier Symptome auf Handy und Desktop mit vergrößerter Schrift. Statische Analyse und Web-Build ergänzen die Prüfung.
