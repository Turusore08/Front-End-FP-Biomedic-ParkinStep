/// Gateway triggering local siren feedback and caregiver emergency escalation on S-08.
abstract interface class EmergencyAlertPort {
  Future<void> triggerLocalSiren();

  Future<void> stopLocalSiren();

  Future<bool> dispatchCaregiverAlert({required String reason});
}
