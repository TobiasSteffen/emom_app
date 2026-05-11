import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/settings.dart';

part 'settings_provider.g.dart';

@Riverpod(keepAlive: true)
class SettingsNotifier extends _$SettingsNotifier {
  @override
  Future<AppSettings> build() => AppSettings.load();

  void replace(AppSettings settings) => state = AsyncData(settings);

  Future<void> save() async {
    final s = state.valueOrNull;
    if (s != null) await s.save();
  }
}
