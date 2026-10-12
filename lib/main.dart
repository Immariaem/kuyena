
import 'package:flutter/material.dart';

void main() {
  runApp(const ZyklusApp());
}

class ZyklusApp extends StatelessWidget {
  const ZyklusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mein Zyklus',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE58BA5),
        ),
        useMaterial3: true,
      ),
      home: const Startseite(),
    );
  }
}

class Startseite extends StatefulWidget {
  const Startseite({super.key});

  @override
  State<Startseite> createState() => _StartseiteState();
}

class _StartseiteState extends State<Startseite> {
  DateTime? periodenStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7F9),
      appBar: AppBar(
        title: const Text('Mein Zyklus 🌸'),
        backgroundColor: const Color(0xFFFFE4EC),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Willkommen bei deinem Zyklus-Tracker',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Halte deinen Zyklus fest und lerne '
                'deinen Körper besser kennen.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              const Icon(
                Icons.favorite,
                size: 76,
                color: Color(0xFFE58BA5),
              ),
              const SizedBox(height: 24),
              Text(
                periodenStart == null
                    ? 'Wann hat deine letzte Periode begonnen?'
                    : 'Periodenbeginn: '
                        '${periodenStart!.day}.'
                        '${periodenStart!.month}.'
                        '${periodenStart!.year}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 17),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  final heute = DateTime.now();
                  final datum = await showDatePicker(
                    context: context,
                    initialDate: heute,
                    firstDate: DateTime(2020),
                    lastDate: heute,
                    helpText: 'Ersten Periodentag auswählen',
                  );

                  if (datum != null && mounted) {
                    setState(() {
                      periodenStart = datum;
                    });
                  }
                },
                icon: const Icon(Icons.calendar_month),
                label: const Text('Periode eintragen'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
