// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'history_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(HistoryNotifier)
final historyProvider = HistoryNotifierProvider._();

final class HistoryNotifierProvider
    extends $AsyncNotifierProvider<HistoryNotifier, List<WorkoutRecord>> {
  HistoryNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'historyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$historyNotifierHash();

  @$internal
  @override
  HistoryNotifier create() => HistoryNotifier();
}

String _$historyNotifierHash() => r'2ae032e4fd0fda24038e96a0377ae76796ff76e9';

abstract class _$HistoryNotifier extends $AsyncNotifier<List<WorkoutRecord>> {
  FutureOr<List<WorkoutRecord>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<WorkoutRecord>>, List<WorkoutRecord>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<WorkoutRecord>>, List<WorkoutRecord>>,
              AsyncValue<List<WorkoutRecord>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
