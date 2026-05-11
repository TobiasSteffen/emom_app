import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../core/models/workout_history.dart';

part 'history_notifier.g.dart';

@riverpod
class HistoryNotifier extends _$HistoryNotifier {
  @override
  Future<List<WorkoutRecord>> build() => WorkoutHistory.load();

  Future<void> addOrUpdate(WorkoutRecord record) async {
    await WorkoutHistory.addOrUpdateRecord(record);
    ref.invalidateSelf();
  }
}
