import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

class PersonalGrowthApp extends ConsumerWidget {
  const PersonalGrowthApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = ref.watch(themePaletteProvider);
    final displayMode = ref.watch(displayModeProvider);

    return MaterialApp.router(
      title: '个人成长工作台',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(palette),
      darkTheme: AppTheme.dark(palette),
      themeMode: displayMode.themeMode,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
