import 'package:flutter/services.dart';

import '../../application/ports/emergency_alert_port.dart';

/// Offline-safe local siren & haptic escalation adapter for S-08 Fall Guard.
class LocalEmergencyAlertAdapter implements EmergencyAlertPort {
  const LocalEmergencyAlertAdapter();

  @override
  Future<void> triggerLocalSiren() async {
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
    try {
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  @override
  Future<void> stopLocalSiren() async {}

  @override
  Future<bool> dispatchCaregiverAlert({required String reason}) async {
    await triggerLocalSiren();
    return false;
  }
}
