import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../application/ports/onboarding_repository_port.dart';
import '../../domain/entities/consent_preferences.dart';
import '../../domain/entities/onboarding_status.dart';
import '../../domain/enums/onboarding_auth_mode.dart';
import '../../domain/enums/user_role.dart';
import '../../domain/errors/onboarding_failure.dart';

/// Offline-first persistence adapter backed by SharedPreferences with
/// explicit schema versioning, UTC ISO-8601 timestamps, and String Enums.
class LocalOnboardingRepository implements OnboardingRepositoryPort {
  const LocalOnboardingRepository(this._prefs);

  final SharedPreferences _prefs;

  static const String _storageKey = 'parkinstep_onboarding_v1';

  @override
  Future<OnboardingStatus> loadStatus() async {
    try {
      final rawJson = _prefs.getString(_storageKey);
      if (rawJson == null || rawJson.isEmpty) {
        return const OnboardingStatus();
      }
      final Object? decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, Object?>) {
        return const OnboardingStatus();
      }

      final Object? consentRaw = decoded['consent'];
      ConsentPreferences consent = const ConsentPreferences();
      if (consentRaw is Map<String, Object?>) {
        consent = ConsentPreferences(
          consentLocal: _readBool(consentRaw['consent_local'], fallback: true),
          consentSkeletonSync:
              _readBool(consentRaw['consent_skeleton_sync'], fallback: false),
          consentCloudVideo:
              _readBool(consentRaw['consent_cloud_video'], fallback: false),
          acceptedAtUtc: _parseUtc(consentRaw['accepted_at_utc']),
        );
      }

      final displayNameRaw = decoded['display_name'];
      final displayName = displayNameRaw is String && displayNameRaw.isNotEmpty
          ? displayNameRaw
          : 'Pengguna';

      return OnboardingStatus(
        authMode: OnboardingAuthMode.fromWire(
          decoded['auth_mode'] is String ? decoded['auth_mode']! as String : null,
        ),
        consent: consent,
        displayName: displayName,
        role: UserRole.fromWire(
          decoded['role'] is String ? decoded['role']! as String : null,
        ),
        updatedAtUtc: _parseUtc(decoded['updated_at_utc']),
      );
    } catch (_) {
      throw const StorageFailure();
    }
  }

  @override
  Future<void> saveStatus(OnboardingStatus status) async {
    try {
      final payload = <String, Object?>{
        'auth_mode': status.authMode?.wireValue,
        'display_name': status.displayName,
        'role': status.role.wireValue,
        'updated_at_utc':
            (status.updatedAtUtc ?? DateTime.now().toUtc()).toUtc().toIso8601String(),
        'consent': <String, Object?>{
          'consent_local': status.consent.consentLocal,
          'consent_skeleton_sync': status.consent.consentSkeletonSync,
          'consent_cloud_video': status.consent.consentCloudVideo,
          'accepted_at_utc':
              status.consent.acceptedAtUtc?.toUtc().toIso8601String(),
        },
      };
      final ok = await _prefs.setString(_storageKey, jsonEncode(payload));
      if (!ok) {
        throw const StorageFailure();
      }
    } catch (e) {
      if (e is OnboardingFailure) rethrow;
      throw const StorageFailure();
    }
  }

  @override
  Future<void> clearStatus() async {
    await _prefs.remove(_storageKey);
  }

  static bool _readBool(Object? raw, {required bool fallback}) {
    if (raw is bool) return raw;
    return fallback;
  }

  static DateTime? _parseUtc(Object? raw) {
    if (raw is! String || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    return parsed?.toUtc();
  }
}
