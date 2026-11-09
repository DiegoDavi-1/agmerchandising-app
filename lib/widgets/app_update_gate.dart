import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:url_launcher/url_launcher.dart';

enum UpdateCheckResult { required, notRequired, unknown }

typedef UpdateChecker = Future<UpdateCheckResult> Function();
typedef UpdateStarter = Future<bool> Function();

/// Bloqueia o app enquanto a Google Play informar uma versão mais nova.
/// Sem resposta da Play (sem internet, app fora da loja), o acesso segue liberado.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({
    super.key,
    required this.child,
    this.checker = checkPlayUpdate,
    this.starter = startPlayUpdate,
    this.storeOpener = openPlayStore,
    this.initialTimeout = const Duration(seconds: 6),
  });

  final Widget child;
  final UpdateChecker checker;
  final UpdateStarter starter;
  final Future<bool> Function() storeOpener;
  final Duration initialTimeout;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  bool _initialCheckDone = false;
  bool _required = false;
  bool _updating = false;
  bool _checking = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check(initial: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check({bool initial = false}) async {
    if (_checking) return;
    _checking = true;
    try {
      final future = widget.checker();
      final result = initial
          ? await future.timeout(widget.initialTimeout,
              onTimeout: () => UpdateCheckResult.unknown)
          : await future;
      if (!mounted) return;
      setState(() {
        // Uma falha de consulta não libera quem já foi bloqueado nesta sessão.
        if (result != UpdateCheckResult.unknown) {
          _required = result == UpdateCheckResult.required;
        }
        if (!_required) _error = null;
      });
    } catch (_) {
      // Mantém o estado atual; a próxima abertura do app tenta de novo.
    } finally {
      _checking = false;
      if (mounted && !_initialCheckDone) {
        setState(() => _initialCheckDone = true);
      }
    }
  }

  Future<void> _update() async {
    setState(() {
      _updating = true;
      _error = null;
    });
    var started = false;
    try {
      started = await widget.starter();
    } catch (_) {}
    if (!started) {
      try {
        started = await widget.storeOpener();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _updating = false;
      if (!started) {
        _error = 'Não foi possível abrir a atualização. Abra a Play Store e '
            'atualize o Merch Hub.';
      }
    });
    await _check();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialCheckDone) {
      return const Material(child: Center(child: CircularProgressIndicator()));
    }
    // A árvore do app permanece montada para não perder a navegação ao desbloquear.
    return Stack(children: [
      ExcludeSemantics(excluding: _required, child: widget.child),
      if (_required)
        Positioned.fill(
          child: _UpdateRequiredScreen(
            updating: _updating,
            error: _error,
            onUpdate: _update,
          ),
        ),
    ]);
  }
}

class _UpdateRequiredScreen extends StatelessWidget {
  const _UpdateRequiredScreen({
    required this.updating,
    required this.error,
    required this.onUpdate,
  });

  final bool updating;
  final String? error;
  final VoidCallback onUpdate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.system_update,
                    size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 24),
                Text('Atualização obrigatória',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text(
                  'Há uma nova versão do Merch Hub. Para continuar usando o '
                  'aplicativo, atualize agora pela Google Play.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: updating ? null : onUpdate,
                    icon: updating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download),
                    label: Text(updating ? 'Abrindo…' : 'Atualizar agora'),
                    style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Text(error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _packageName = 'com.merchhub.app';

Future<UpdateCheckResult> checkPlayUpdate() async {
  if (kIsWeb || !Platform.isAndroid) return UpdateCheckResult.notRequired;
  try {
    final info = await InAppUpdate.checkForUpdate();
    final pending = info.updateAvailability ==
            UpdateAvailability.updateAvailable ||
        info.updateAvailability ==
            UpdateAvailability.developerTriggeredUpdateInProgress;
    return pending ? UpdateCheckResult.required : UpdateCheckResult.notRequired;
  } catch (_) {
    return UpdateCheckResult.unknown;
  }
}

Future<bool> startPlayUpdate() async {
  if (kIsWeb || !Platform.isAndroid) return false;
  final info = await InAppUpdate.checkForUpdate();
  final inProgress = info.updateAvailability ==
      UpdateAvailability.developerTriggeredUpdateInProgress;
  if (!inProgress && !info.immediateUpdateAllowed) return false;
  final result = await InAppUpdate.performImmediateUpdate();
  // Recusar ou cancelar o fluxo da Play mantém o bloqueio.
  return result != AppUpdateResult.inAppUpdateFailed;
}

Future<bool> openPlayStore() async {
  final market = Uri.parse('market://details?id=$_packageName');
  if (await launchUrl(market, mode: LaunchMode.externalApplication)) {
    return true;
  }
  return launchUrl(
    Uri.parse('https://play.google.com/store/apps/details?id=$_packageName'),
    mode: LaunchMode.externalApplication,
  );
}
