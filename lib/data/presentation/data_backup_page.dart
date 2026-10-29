import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../app/presentation/kuyena_components.dart';
import '../../home/presentation/home_design.dart';
import '../application/data_backup_service.dart';
import '../backup/backup_document.dart';
import '../backup/backup_files.dart';
import '../backup/encrypted_backup.dart';
import '../storage/local_app_store.dart';

class DataBackupPage extends StatefulWidget {
  const DataBackupPage({super.key, required this.service, required this.files});
  final DataBackupService service;
  final BackupFiles files;
  @override
  State<DataBackupPage> createState() => _DataBackupPageState();
}

class _DataBackupPageState extends State<DataBackupPage> {
  final _password = TextEditingController(),
      _repeat = TextEditingController(),
      _restorePassword = TextEditingController();
  bool _busy = false, _creating = false, _encrypted = false;
  Uint8List? _prepared, _picked;
  RestorePreview? _preview;
  String? _error, _notice;
  @override
  void dispose() {
    _password.clear();
    _repeat.clear();
    _restorePassword.clear();
    _password.dispose();
    _repeat.dispose();
    _restorePassword.dispose();
    super.dispose();
  }

  void _failure(Object error) => setState(
    () => _error = switch (error) {
      BackupException e => e.message,
      LocalDataException e => e.message,
      _ =>
        'Der Vorgang konnte nicht bestätigt werden. Bitte versuche es erneut. Deine Datei und dein Passwort werden nicht weitergegeben.',
    },
  );
  Future<void> _create() async {
    if (_busy) return;
    setState(() {
      _error = null;
      _notice = null;
    });
    try {
      EncryptedBackup.validatePassword(_password.text);
      if (_password.text != _repeat.text) {
        throw const BackupException(
          'Die beiden Passwörter stimmen nicht überein.',
        );
      }
      setState(() => _busy = true);
      final bytes = await widget.service.create(_password.text);
      if (mounted) {
        setState(() {
          _prepared = bytes;
          _password.clear();
          _repeat.clear();
          _creating = false;
        });
      }
    } catch (e) {
      if (mounted) _failure(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveFile() async {
    final bytes = _prepared;
    if (_busy || bytes == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      // A separate fresh click opens the file dialog after key derivation.
      final saved = await widget.files.save(
        'kuyena-backup-${widget.service.today().iso}.kuyena',
        bytes,
      );
      if (mounted) {
        setState(
          () => _notice = saved
              ? kIsWeb
                    ? 'Download gestartet. Bitte bewahre die Sicherungsdatei und dein Passwort auf.'
                    : 'Sicherungsdatei gespeichert. Bewahre das Passwort getrennt auf.'
              : 'Speichern abgebrochen. Die vorbereitete Datei ist weiterhin verfügbar.',
        );
      }
    } catch (e) {
      if (mounted) _failure(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final bytes = await widget.files.pick();
      if (bytes != null && mounted) {
        final encrypted = EncryptedBackup.isEncrypted(bytes);
        setState(() {
          _picked = bytes;
          _encrypted = encrypted;
          _preview = null;
          _restorePassword.clear();
        });
      }
    } catch (e) {
      if (mounted) _failure(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _check() async {
    final bytes = _picked;
    if (_busy || bytes == null) return;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
      _preview = null;
    });
    try {
      final preview = await widget.service.preview(
        bytes,
        password: _encrypted ? _restorePassword.text : null,
      );
      if (mounted) {
        setState(() {
          _preview = preview;
          _restorePassword.clear();
        });
      }
    } catch (e) {
      if (mounted) _failure(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    final preview = _preview;
    if (_busy || preview == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Vorhandene Daten ersetzen?'),
        content: const Text(
          'Die geprüfte Sicherung ersetzt deine aktuellen Perioden, Tageseinträge, Kalenderkorrekturen und die Erinnerungseinstellung auf diesem Gerät. Sichere vorher die aktuellen Daten, wenn du sie behalten möchtest.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            key: const ValueKey('confirm-restore'),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Daten ersetzen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.service.restore(preview);
      if (mounted) {
        _picked = null;
        _preview = null;
        _prepared = null;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sicherung wiederhergestellt.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) _failure(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController controller, String label, String key) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: TextField(
          key: ValueKey(key),
          controller: controller,
          enabled: !_busy,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          maxLength: 1024,
          decoration: InputDecoration(
            labelText: label,
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      );
  Widget _card(List<Widget> children) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: HomeDesign.palePink,
      borderRadius: BorderRadius.circular(26),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      backgroundColor: const Color(0xFFFFF7F9),
      appBar: AppBar(
        backgroundColor: HomeDesign.red,
        foregroundColor: Colors.white,
        title: Text(
          'Deine Datensicherung',
          style: HomeDesign.text(21, color: Colors.white),
        ),
        leading: IconButton(
          tooltip: 'Zurück',
          onPressed: _busy ? null : () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Sichern und wiederherstellen',
                    style: HomeDesign.text(25),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Du entscheidest, wo du deine Sicherungsdatei aufbewahrst. Kuyena verarbeitet sie auf diesem Gerät. Dein Passwort wird nicht gespeichert.',
                    style: HomeDesign.text(
                      15,
                      color: HomeDesign.ink,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _card([
                    Text('Sicherung erstellen', style: HomeDesign.text(20)),
                    const SizedBox(height: 8),
                    Text(
                      'Perioden, Wohlbefinden, Kalenderkorrekturen und Erinnerungen werden gemeinsam mit einem Passwort verschlüsselt.',
                      style: HomeDesign.text(14, weight: FontWeight.w600),
                    ),
                    if (_creating) ...[
                      _field(
                        _password,
                        'Passwort (mindestens 12 Zeichen)',
                        'backup-password',
                      ),
                      _field(_repeat, 'Passwort wiederholen', 'backup-repeat'),
                      const SizedBox(height: 12),
                      Text(
                        'Ohne dieses Passwort kannst du die Sicherung nicht öffnen. Ein langes, eigenes Passwort schützt die Datei besser.',
                        style: HomeDesign.text(13, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 14),
                      DesignButton(
                        key: const ValueKey('prepare-backup'),
                        label: 'Sicherung vorbereiten',
                        onPressed: _busy ? null : _create,
                      ),
                    ] else ...[
                      const SizedBox(height: 14),
                      DesignButton(
                        key: const ValueKey('create-backup'),
                        label: 'Neue Sicherung erstellen',
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _creating = true;
                                _error = null;
                              }),
                      ),
                    ],
                    if (_prepared != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        'Deine verschlüsselte Datei ist vorbereitet. Sie enthält den Datenstand zum Zeitpunkt ihrer Erstellung.',
                        style: HomeDesign.text(13, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      DesignButton(
                        key: const ValueKey('save-backup-file'),
                        label: 'Datei speichern',
                        onPressed: _busy ? null : _saveFile,
                      ),
                    ],
                  ]),
                  const SizedBox(height: 18),
                  _card([
                    Text(
                      'Sicherung wiederherstellen',
                      style: HomeDesign.text(20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Wähle eine Kuyena-Sicherung oder einen früheren JSON-Export. Zuerst prüfen wir die Datei. Erst deine Bestätigung ersetzt die aktuellen Daten.',
                      style: HomeDesign.text(14, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 14),
                    DesignButton(
                      key: const ValueKey('pick-backup-file'),
                      label: 'Datei auswählen',
                      onPressed: _busy ? null : _pick,
                    ),
                    if (_picked != null) ...[
                      if (_encrypted && _preview == null)
                        _field(
                          _restorePassword,
                          'Passwort dieser Sicherung',
                          'restore-password',
                        ),
                      if (!_encrypted) ...[
                        const SizedBox(height: 10),
                        Text(
                          'Diese Datei ist ein unverschlüsselter JSON-Export.',
                          style: HomeDesign.text(13, weight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 12),
                      DesignButton(
                        key: const ValueKey('check-backup'),
                        label: 'Sicherung prüfen',
                        onPressed: _busy ? null : _check,
                      ),
                    ],
                    if (_preview case final preview?) ...[
                      const SizedBox(height: 16),
                      Text('Sicherung geprüft', style: HomeDesign.text(18)),
                      const SizedBox(height: 8),
                      Text(
                        '${preview.document.periods.length} Perioden\n${preview.document.journal.entries.length} Tageseinträge\n${preview.document.journal.periodDays.length} Kalenderkorrekturen\nPersönliche Einstellungen: ${preview.document.profile == null ? 'in dieser Sicherung nicht enthalten' : 'enthalten'}\nErinnerungen: ${preview.document.journal.reminders ? 'an' : 'aus'}',
                        style: HomeDesign.text(14, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Die Wiederherstellung ersetzt die vorhandenen Daten vollständig. Es wird nichts zusammengeführt.',
                        style: HomeDesign.text(13, weight: FontWeight.w700),
                      ),
                      const SizedBox(height: 14),
                      DesignButton(
                        key: const ValueKey('restore-backup'),
                        label: 'Wiederherstellen',
                        onPressed: _busy ? null : _restore,
                      ),
                    ],
                  ]),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(_error!, style: HomeDesign.text(14)),
                      ),
                    ),
                  if (_notice != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(_notice!, style: HomeDesign.text(14)),
                      ),
                    ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: LinearProgressIndicator(color: HomeDesign.red),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
