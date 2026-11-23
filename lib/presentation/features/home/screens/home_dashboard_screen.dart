import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../di/dashboard_providers.dart';
import '../../../../di/onboarding_providers.dart';
import '../../../../domain/constants/clinical_copy.dart';
import '../../../../domain/entities/home_dashboard_summary.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/design_system/parkin_brand_lockup.dart';
import '../../../widgets/design_system/parkin_dark_reminder_card.dart';
import '../../../widgets/design_system/parkin_empty_state_card.dart';
import '../../../widgets/design_system/parkin_icons.dart';
import '../../../widgets/design_system/parkin_metric_pill.dart';
import '../../../widgets/design_system/parkin_session_carousel_card.dart';
import '../../../widgets/design_system/parkin_vertical_feature_card.dart';
import '../widgets/medication_log_sheet.dart';
import '../widgets/privacy_shield_sheet.dart';

/// S-03: Patient Home Dashboard faithful to Figma v2 (`15:117`), `UI_UX_SPEC.md`,
/// and Parkinson's high-contrast clinical visual clarity with WCAG 2.1 tokens.
class HomeDashboardScreen extends ConsumerWidget {
  const HomeDashboardScreen({super.key});

  static String _greetingForHour(int hour) {
    if (hour >= 4 && hour < 11) return 'Selamat Pagi,';
    if (hour >= 11 && hour < 15) return 'Selamat Siang,';
    if (hour >= 15 && hour < 18) return 'Selamat Sore,';
    return 'Selamat Malam,';
  }

  static String _formatShortDate(DateTime localTime) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final m = months[(localTime.month - 1).clamp(0, 11)];
    return '${localTime.day} $m';
  }

  static String _formatDecimalId(double value) {
    return value.toStringAsFixed(1).replaceAll('.', ',');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingState = ref.watch(onboardingControllerProvider);
    final dashboardState = ref.watch(homeDashboardControllerProvider);
    final clock = ref.watch(homeDashboardClockProvider);
    final summary = dashboardState.summary;

    final nowLocal = clock().toLocal();
    final greeting = _greetingForHour(nowLocal.hour);
    final todayIso =
        ref.read(homeDashboardControllerProvider.notifier).todayLocalDateIso;
    final showReminder = !summary.isReminderDismissedOn(todayIso);

    final (metricHero, metricSubtitle, metricBadge, metricTap) =
        _buildMetricPillModel(context, summary);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.pureWhite,
        body: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Header: Brand Lockup | hairline | Greeting + Name + Privacy Shield
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Flexible(
                            flex: 5,
                            child: ParkinBrandLockup(
                              variant: ParkinLockupVariant.light,
                              emblemSize: 22,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 1,
                            height: 28,
                            color: AppColors.subtleBorderLight,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  greeting,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.captionBadge(
                                    color: AppColors.mutedSlate,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  onboardingState.status.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.cardTitle(size: 16),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Semantics(
                      button: true,
                      label: 'Perlindungan privasi dan informasi keselamatan',
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 56,
                          minHeight: 56,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const Key('home_privacy_shield_button'),
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => showPrivacyShieldSheet(
                              context,
                              status: onboardingState.status,
                              onOpenSettings: () => context.go('/settings'),
                            ),
                            child: Center(
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: const BoxDecoration(
                                  color: AppColors.iceSurface,
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: ParkinIcons.offlineShield(
                                  color: AppColors.clinicalAzure,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // 2. Section 1: "Pilih untuk Memulai" + 3 Vertical Feature Cards
                Text(
                  ClinicalCopy.dashboardStartSectionTitle,
                  style: AppTypography.screenTitle(size: 24),
                ),
                const SizedBox(height: 14),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: ParkinVerticalFeatureCard(
                          key: const Key('home_card_tes_360'),
                          title: 'Mulai Tes',
                          tiltRadians: -0.0873,
                          illustration: ParkinIcons.tes360Illustration(),
                          semanticLabel:
                              'Pilih dan mulai tes video berputar, berjalan bolak-balik, atau duduk berdiri',
                          onPressed: () => context.push('/select-test'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ParkinVerticalFeatureCard(
                          key: const Key('home_card_cueing_ras'),
                          title: 'Cueing RAS',
                          tiltRadians: 0.0611,
                          illustration: ParkinIcons.cueingRasIllustration(),
                          semanticLabel: 'Buka Cueing Metronom RAS',
                          onPressed: () => context.push('/metronome'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ParkinVerticalFeatureCard(
                          key: const Key('home_card_catat_obat'),
                          title: 'Catat Obat',
                          tiltRadians: -0.0873,
                          illustration: ParkinIcons.catatObatIllustration(),
                          semanticLabel: 'Catat konsumsi dan status ON OFF obat',
                          onPressed: () => showMedicationLogSheet(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 3. Section 2: Metric Pill (Latest Session OR Honest Pre-Test State)
                ParkinMetricPill(
                  key: const Key('home_metric_pill'),
                  heroText: metricHero,
                  subtitleText: metricSubtitle,
                  badgeLabel: metricBadge,
                  onTap: metricTap,
                ),

                if (dashboardState.errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Semantics(
                    liveRegion: true,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.redSoftBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.alertRed),
                      ),
                      child: Row(
                        children: [
                          ParkinIcons.alertTriangle(
                            color: AppColors.redDarkText,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              dashboardState.errorMessage!,
                              style: AppTypography.captionBadge(
                                color: AppColors.redDarkText,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // 4. Section 3: Dismissible Dark Reminder Banner
                if (showReminder) ...[
                  const SizedBox(height: 18),
                  ParkinDarkReminderCard(
                    key: const Key('home_reminder_card'),
                    title: ClinicalCopy.reminderTitle,
                    body: ClinicalCopy.reminderBody,
                    onDismiss: () => ref
                        .read(homeDashboardControllerProvider.notifier)
                        .dismissDailyReminder(),
                    onStart: () => context.push('/select-test'),
                  ),
                ],

                const SizedBox(height: 22),

                // 5. Section 4: "Sesi Terakhir" (Empty State R-27 or Session Carousel)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        ClinicalCopy.dashboardRecentSessionsTitle,
                        style: AppTypography.cardTitle(size: 19),
                      ),
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: TextButton(
                        key: const Key('home_see_all_history_button'),
                        onPressed: () => context.go('/history'),
                        child: Text(
                          'Lihat Semua',
                          style: AppTypography.captionBadge(
                            color: AppColors.onIceAzure,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (summary.recentSessions.isEmpty)
                  ParkinEmptyStateCard(
                    key: const Key('home_empty_history_state'),
                    title: ClinicalCopy.emptyHistoryTitle,
                    description: ClinicalCopy.emptyHistoryBody,
                    ctaLabel: ClinicalCopy.emptyHistoryCta,
                    ctaKey: const Key('empty_start_first_test_button'),
                    onCtaPressed: () => context.push('/select-test'),
                  )
                else
                  SizedBox(
                    height: 152,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: summary.recentSessions.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final session = summary.recentSessions[index];
                        final tone = ParkinSessionCardTone
                            .values[index % ParkinSessionCardTone.values.length];
                        final fraction =
                            (1.0 - (session.fogPercentage / 100.0)).clamp(
                          0.12,
                          1.0,
                        );
                        return ParkinSessionCarouselCard(
                          dateLabel: _formatShortDate(
                            session.startedAtUtc.toLocal(),
                          ),
                          medBadge: session.medState.labelId,
                          fogPercentLabel:
                              '${_formatDecimalId(session.fogPercentage)}%',
                          progressFraction: fraction,
                          tone: tone,
                          onTap: () => context.push(
                            '/session-report/${session.sessionId}',
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  (String, String, String?, VoidCallback) _buildMetricPillModel(
    BuildContext context,
    HomeDashboardSummary summary,
  ) {
    final latestSession = summary.latestSession;
    if (latestSession != null) {
      final dateStr = _formatShortDate(latestSession.startedAtUtc.toLocal());
      final pct = _formatDecimalId(latestSession.fogPercentage);
      final epLabel = latestSession.episodeCount == 0
          ? '0 Episode'
          : '${latestSession.episodeCount} Episode';
      return (
        '$pct% FoG',
        '${latestSession.protocol.shortLabelId} · ${latestSession.medState.labelId} · $dateStr',
        epLabel,
        () => context.go('/history'),
      );
    }

    final latestMed = summary.latestMedicationLog;
    if (latestMed != null) {
      return (
        latestMed.medState.labelId,
        '${latestMed.drugName} ${latestMed.dosageMg.round()} mg · Belum ada tes video',
        'Tercatat',
        () => showMedicationLogSheet(context),
      );
    }

    return (
      'Belum Ada Tes',
      'Pilih tes video 2 menit pertama Anda untuk memantau skor FoG',
      null,
      () => context.push('/select-test'),
    );
  }
}
