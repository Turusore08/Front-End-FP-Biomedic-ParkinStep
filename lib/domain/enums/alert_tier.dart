/// Real-time clinical FoG & safety alert tiers mapped to Two-Tier Cueing & Fall Guard.
enum AlertTier {
  gaitNormal('GAIT_NORMAL', 'NORMAL GAIT'),
  earlyWarning('EARLY_WARNING', 'PERINGATAN DINI'),
  fogConfirmed('FOG_CONFIRMED', 'KAKI MEMBEKU'),
  fallGuard('FALL_GUARD', 'PERLINDUNGAN JATUH');

  const AlertTier(this.wireValue, this.badgeLabelId);

  final String wireValue;
  final String badgeLabelId;
}
