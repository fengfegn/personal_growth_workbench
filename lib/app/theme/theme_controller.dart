import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../features/settings/data/app_settings_repository.dart';
import 'app_theme.dart';

final displayModeProvider = StateProvider<DisplayMode>((ref) {
  return DisplayMode.system;
});

final themePaletteProvider =
    StateNotifierProvider<ThemePaletteController, ThemePalette>((ref) {
      return ThemePaletteController(
        AppSettingsRepository(ref.watch(appDatabaseProvider)),
      );
    });

class ThemePaletteController extends StateNotifier<ThemePalette> {
  ThemePaletteController(this._settings) : super(ThemePalette.yuan1) {
    _initialization = _restore();
    unawaited(_initialization);
  }

  static const _settingsKey = 'theme_preferences';
  static const _paletteKey = 'palette';

  final AppSettingsRepository _settings;
  late final Future<void> _initialization;
  bool _hasUserSelection = false;

  Future<void> get initialized => _initialization;

  Future<void> setPalette(ThemePalette palette) async {
    _hasUserSelection = true;
    state = palette;
    await _settings.writeJson(_settingsKey, {_paletteKey: palette.name});
  }

  Future<void> _restore() async {
    final json = await _settings.readJson(_settingsKey);
    if (!mounted || _hasUserSelection) {
      return;
    }

    final savedName = json?[_paletteKey];
    if (savedName is! String) {
      return;
    }

    for (final palette in ThemePalette.values) {
      if (palette.name == savedName) {
        state = palette;
        return;
      }
    }
  }
}
