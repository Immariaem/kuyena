import 'package:flutter/material.dart';
import '../../home/presentation/home_design.dart';

const privacyText =
    'Kuyena braucht kein Konto. Deine Perioden, Tageseinträge und persönlichen Einstellungen werden lokal auf diesem Gerät bzw. in diesem Browserprofil gespeichert. Die App überträgt diese Angaben nicht an einen Kuyena-Server. Es gibt keine automatische Synchronisation zwischen Geräten.\n\nIm Browser gehören die Daten zu dieser Website-Adresse und diesem Browserprofil. Wenn du Website-Daten löschst oder einen anderen Browser benutzt, können deine Einträge fehlen. Die Browser-Version ist ein Prototyp; verwende zunächst Testdaten. Wer Zugriff auf ein entsperrtes Gerät oder Browserprofil hat, kann unter Umständen auch die App öffnen.\n\nDu kannst Angaben unter „Cycle & App“ und im Kalender ändern oder löschen. Unter „Sicherung & Wiederherstellung“ kannst du eine passwortgeschützte Sicherungsdatei erstellen. Das Passwort wird nicht gespeichert. Ohne Passwort lässt sich diese Datei nicht öffnen. Der zusätzliche JSON-Export ist unverschlüsselt und enthält deine Angaben in lesbarer Form.\n\nErinnerungen erscheinen derzeit nur innerhalb der geöffneten App. Es werden keine Push-Dienste angesprochen. Angaben zu Allergien, Ernährung oder Bewegung sind freiwillige Präferenzen. Sie ersetzen keine medizinische Prüfung.\n\nDie nächste Periode ist eine ungefähre Kalenderschätzung aus deinen eigenen Angaben oder zunächst einem allgemeinen 28-Tage-Richtwert. Ein Eisprung wird damit weder erkannt noch bestätigt. Die App ist nicht zur Verhütung bestimmt.';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      backgroundColor: HomeDesign.red,
      foregroundColor: Colors.white,
      title: Text(
        'Datenschutzinformationen',
        style: HomeDesign.text(20, color: Colors.white),
      ),
    ),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: SelectableText(
            privacyText,
            style: HomeDesign.text(
              16,
              color: HomeDesign.ink,
              weight: FontWeight.w600,
              height: 1.65,
            ),
          ),
        ),
      ),
    ),
  );
}
