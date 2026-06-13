import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/training_series.dart';
import '../services/notification_service.dart';

part 'series_notifier.g.dart';

@Riverpod(keepAlive: true)
class SeriesNotifier extends _$SeriesNotifier {
  @override
  Future<List<TrainingSeries>> build() => SeriesStorage.load();

  Future<void> addSeries(TrainingSeries series) async {
    final list = [...state.requireValue, series];
    await SeriesStorage.save(list);
    state = AsyncData(list);
    await rescheduleReminders(ref);
  }

  Future<void> removeSeries(String id) async {
    final list = state.requireValue.where((s) => s.id != id).toList();
    await SeriesStorage.save(list);
    state = AsyncData(list);
    await rescheduleReminders(ref);
  }

  Future<void> addException(String id, DateTime date) async {
    final list = state.requireValue.map((s) {
      if (s.id != id) return s;
      return s.copyWith(
          exceptions: {...s.exceptions, TrainingSeries.dateKey(date)});
    }).toList();
    await SeriesStorage.save(list);
    state = AsyncData(list);
    await rescheduleReminders(ref);
  }
}
