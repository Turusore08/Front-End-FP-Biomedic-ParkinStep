import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_typography.dart';
import 'parkin_icons.dart';

/// Persistent 4-tab bottom navigation bar (`BERANDA | RIWAYAT | BANTUAN | PENGATURAN`)
/// with >= 56 dp touch height per tab and zero horizontal clipping at 360 dp @ 1.5x.
class ParkinBottomNav extends StatelessWidget {
  const ParkinBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final items = <_NavItem>[
      _NavItem(
        key: const Key('nav_tab_home'),
        label: 'BERANDA',
        iconBuilder: (c) => ParkinIcons.navHome(color: c, size: 22),
      ),
      _NavItem(
        key: const Key('nav_tab_history'),
        label: 'RIWAYAT',
        iconBuilder: (c) => ParkinIcons.navHistory(color: c, size: 22),
      ),
      _NavItem(
        key: const Key('nav_tab_help'),
        label: 'BANTUAN',
        iconBuilder: (c) => ParkinIcons.navHelp(color: c, size: 22),
      ),
      _NavItem(
        key: const Key('nav_tab_settings'),
        label: 'PENGATURAN',
        iconBuilder: (c) => ParkinIcons.navSettings(color: c, size: 22),
      ),
    ];

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.pureWhite,
        border: Border(
          top: BorderSide(color: AppColors.subtleBorderLight, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 74),
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                _BottomNavTabButton(
                  item: items[i],
                  isActive: currentIndex == i,
                  onPressed: () => onSelected(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.key,
    required this.label,
    required this.iconBuilder,
  });

  final Key key;
  final String label;
  final Widget Function(Color color) iconBuilder;
}

class _BottomNavTabButton extends StatelessWidget {
  const _BottomNavTabButton({
    required this.item,
    required this.isActive,
    required this.onPressed,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.clinicalAzure : AppColors.mutedNavSlate;

    return Expanded(
      child: Semantics(
        button: true,
        selected: isActive,
        label: item.label,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: item.key,
              onTap: onPressed,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 32,
                      height: 3,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.clinicalAzure
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 6),
                    item.iconBuilder(color),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.label,
                        maxLines: 1,
                        style: AppTypography.captionBadge(
                          color: color,
                          weight: isActive ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
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
}
