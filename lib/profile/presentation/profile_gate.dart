import 'package:flutter/material.dart';
import '../../app/presentation/kuyena_components.dart';
import '../../data/application/data_backup_service.dart';
import '../../data/backup/backup_files.dart';
import '../../data/presentation/data_backup_page.dart';
import '../../home/presentation/home_design.dart';
import '../application/profile_controller.dart';
import 'onboarding_flow.dart';

class ProfileGate extends StatefulWidget {
  const ProfileGate({
    super.key,
    required this.controller,
    required this.child,
    this.backupService,
    this.backupFiles,
  });
  final ProfileController controller;
  final Widget child;
  final DataBackupService? backupService;
  final BackupFiles? backupFiles;
  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  bool _loading = true, _failed = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      await widget.controller.load();
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore() async {
    await Navigator.push(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => DataBackupPage(
          service: widget.backupService!,
          files: widget.backupFiles ?? BackupFiles(),
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Alle lokalen Daten löschen?'),
        content: const Text(
          'Das entfernt alle Einträge und Einstellungen auf diesem Gerät. Ohne Sicherung lässt sich das nicht rückgängig machen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Alle Daten löschen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.controller.store.clear();
      if (mounted) await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Löschen konnte nicht bestätigt werden. Bitte erneut versuchen.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: HomeDesign.red)),
      );
    }
    if (_failed) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Deine Daten konnten nicht geladen werden.',
                    style: HomeDesign.text(24),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Vorhandene Einträge werden nicht überschrieben. Du kannst es erneut versuchen oder eine Sicherung wiederherstellen.',
                    style: HomeDesign.text(16),
                  ),
                  const SizedBox(height: 20),
                  DesignButton(label: 'Erneut versuchen', onPressed: _load),
                  TextButton(
                    onPressed: _clear,
                    child: const Text('Alle lokalen Daten löschen'),
                  ),
                  if (widget.backupService != null)
                    TextButton(
                      onPressed: _restore,
                      child: const Text('Sicherung wiederherstellen'),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => widget.controller.value?.completed == true
          ? widget.child
          : OnboardingFlow(controller: widget.controller),
    );
  }
}
