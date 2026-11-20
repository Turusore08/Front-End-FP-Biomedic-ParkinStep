import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../presentation/theme/app_theme.dart';
import 'router.dart';

class ParkinStepApp extends ConsumerWidget {
  const ParkinStepApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    return MaterialApp.router(
      title: 'ParkinStep',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      routerConfig: router,
    );
  }
}
