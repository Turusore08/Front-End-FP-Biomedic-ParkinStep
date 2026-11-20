import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../widgets/design_system/parkin_bottom_nav.dart';
import 'package:go_router/go_router.dart';

/// Root scaffold hosting the 4 persistent navigation branches (`BERANDA`,
/// `RIWAYAT`, `BANTUAN`, `PENGATURAN`) via StatefulNavigationShell.
class MainNavigationShell extends ConsumerWidget {
  const MainNavigationShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: ParkinBottomNav(
        currentIndex: navigationShell.currentIndex,
        onSelected: (int index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}
