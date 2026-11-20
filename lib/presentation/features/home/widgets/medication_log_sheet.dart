import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../di/dashboard_providers.dart';
import '../../../../domain/enums/medication_state.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_typography.dart';
import '../../../widgets/design_system/parkin_icons.dart';
import '../../../widgets/design_system/parkin_primary_pill_button.dart';

/// Launches the accessible ON/OFF Levodopa medication logging modal sheet.
Future<void> showMedicationLogSheet(BuildContext context) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => MedicationLogSheet(
      onSaved: (MedicationState medState, String drugName, double dosageMg) {
        messenger?.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.royalNavy,
            content: Text(
              'Catatan obat tersimpan: ${medState.labelId} ($drugName ${dosageMg.round()} mg).',
              style: AppTypography.captionBadge(
                color: AppColors.pureWhite,
                weight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Modal bottom sheet enabling Parkinson's patients & caregivers to log
/// ON/OFF Levodopa medication state without thin sliders or tiny hit targets.
class MedicationLogSheet extends ConsumerStatefulWidget {
  const MedicationLogSheet({
    super.key,
    required this.onSaved,
  });

  final void Function(
    MedicationState medState,
    String drugName,
    double dosageMg,
  ) onSaved;

  @override
  ConsumerState<MedicationLogSheet> createState() => _MedicationLogSheetState();
}

class _MedicationLogSheetState extends ConsumerState<MedicationLogSheet> {
  final TextEditingController _drugController =
      TextEditingController(text: 'Levodopa / Carbidopa');
  final TextEditingController _dosageController =
      TextEditingController(text: '100');
  final TextEditingController _notesController = TextEditingController();

  MedicationState _selectedState = MedicationState.on;
  String? _localError;

  @override
  void dispose() {
    _drugController.dispose();
    _dosageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _localError = null);

    final parsedDosage = double.tryParse(
      _dosageController.text.trim().replaceAll(',', '.'),
    );
    if (parsedDosage == null || parsedDosage <= 0 || parsedDosage > 2000) {
      setState(
        () => _localError =
            'Masukkan angka dosis yang valid antara 1 hingga 2000 mg.',
      );
      return;
    }

    final drugName = _drugController.text.trim();
    final err = await ref
        .read(homeDashboardControllerProvider.notifier)
        .logMedicationIntake(
          drugName: drugName,
          dosageMg: parsedDosage,
          medState: _selectedState,
          notes: _notesController.text,
        );

    if (!mounted) return;
    if (err != null) {
      setState(() => _localError = err);
      return;
    }
    Navigator.of(context).pop();
    widget.onSaved(_selectedState, drugName, parsedDosage);
  }

  void _selectPresetDosage(int mg) {
    setState(() {
      _dosageController.text = '$mg';
      _localError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isBusy = ref.watch(
      homeDashboardControllerProvider.select((s) => s.isBusy),
    );
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.subtleBorderLight,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Catat Obat Levodopa',
                        style: AppTypography.screenTitle(size: 21),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Tutup formulir catat obat',
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: Material(
                          color: AppColors.iceSurface,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            key: const Key('med_sheet_close_button'),
                            borderRadius: BorderRadius.circular(14),
                            onTap: isBusy
                                ? null
                                : () => Navigator.of(context).pop(),
                            child: Center(
                              child: ParkinIcons.close(
                                color: AppColors.royalNavy,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Tandai status ON atau OFF obat saat ini agar tren gejala FoG lebih akurat dibaca dokter.',
                  style: AppTypography.bodyLarge(size: 14.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Status Efek Obat Sekarang',
                  style: AppTypography.captionBadge(
                    color: AppColors.royalNavy,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _MedStateButton(
                      key: const Key('med_state_on'),
                      state: MedicationState.on,
                      selected: _selectedState == MedicationState.on,
                      onPressed: isBusy
                          ? null
                          : () => setState(
                                () => _selectedState = MedicationState.on,
                              ),
                    ),
                    const SizedBox(width: 8),
                    _MedStateButton(
                      key: const Key('med_state_off'),
                      state: MedicationState.off,
                      selected: _selectedState == MedicationState.off,
                      onPressed: isBusy
                          ? null
                          : () => setState(
                                () => _selectedState = MedicationState.off,
                              ),
                    ),
                    const SizedBox(width: 8),
                    _MedStateButton(
                      key: const Key('med_state_unknown'),
                      state: MedicationState.unknown,
                      selected: _selectedState == MedicationState.unknown,
                      onPressed: isBusy
                          ? null
                          : () => setState(
                                () => _selectedState = MedicationState.unknown,
                              ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Nama Obat',
                  style: AppTypography.captionBadge(
                    color: AppColors.royalNavy,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('med_drug_field'),
                  controller: _drugController,
                  enabled: !isBusy,
                  textInputAction: TextInputAction.next,
                  style: AppTypography.bodyLarge(
                    color: AppColors.royalNavy,
                    weight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Contoh: Levodopa / Carbidopa',
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Dosis (mg)',
                  style: AppTypography.captionBadge(
                    color: AppColors.royalNavy,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('med_dosage_field'),
                  controller: _dosageController,
                  enabled: !isBusy,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  style: AppTypography.bodyLarge(
                    color: AppColors.royalNavy,
                    weight: FontWeight.w600,
                  ),
                  decoration: const InputDecoration(
                    hintText: '100',
                    suffixText: 'mg',
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    for (final mg in const [100, 150, 200]) ...[
                      Expanded(
                        child: _QuickDoseButton(
                          label: '$mg mg',
                          onPressed: isBusy
                              ? null
                              : () => _selectPresetDosage(mg),
                        ),
                      ),
                      if (mg != 200) const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Catatan Tambahan (Opsional)',
                  style: AppTypography.captionBadge(
                    color: AppColors.royalNavy,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  key: const Key('med_notes_field'),
                  controller: _notesController,
                  enabled: !isBusy,
                  textInputAction: TextInputAction.done,
                  maxLines: 2,
                  style: AppTypography.bodyLarge(
                    color: AppColors.royalNavy,
                    weight: FontWeight.w400,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Contoh: Diminum 30 menit sebelum tes',
                  ),
                ),
                if (_localError != null) ...[
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
                              _localError!,
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
                const SizedBox(height: 20),
                ParkinPrimaryPillButton(
                  key: const Key('med_submit_button'),
                  label: 'Simpan Catatan Obat',
                  leadingIcon: ParkinIcons.capsule(
                    color: AppColors.clinicalAzure,
                  ),
                  isLoading: isBusy,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MedStateButton extends StatelessWidget {
  const _MedStateButton({
    super.key,
    required this.state,
    required this.selected,
    required this.onPressed,
  });

  final MedicationState state;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final bgColor = selected ? AppColors.clinicalAzure : AppColors.iceSurface;
    final fgColor = selected ? AppColors.pureWhite : AppColors.royalNavy;
    final borderColor =
        selected ? AppColors.clinicalAzure : AppColors.skyCard;

    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: '${state.labelId}: ${state.descriptionId}',
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Material(
            color: bgColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: borderColor, width: 1.5),
            ),
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      state.labelId,
                      style: AppTypography.buttonLabel(
                        color: fgColor,
                        size: 14.5,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickDoseButton extends StatelessWidget {
  const _QuickDoseButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Material(
        color: AppColors.softIce,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: AppTypography.buttonLabel(
                    color: AppColors.onIceAzure,
                    size: 14.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
