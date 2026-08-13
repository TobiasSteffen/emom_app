// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'garmin_workout_sync_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GarminWorkoutSyncNotifier)
final garminWorkoutSyncProvider = GarminWorkoutSyncNotifierProvider._();

final class GarminWorkoutSyncNotifierProvider
    extends $AsyncNotifierProvider<GarminWorkoutSyncNotifier, void> {
  GarminWorkoutSyncNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'garminWorkoutSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$garminWorkoutSyncNotifierHash();

  @$internal
  @override
  GarminWorkoutSyncNotifier create() => GarminWorkoutSyncNotifier();
}

String _$garminWorkoutSyncNotifierHash() =>
    r'831f9675cde7299a008c5b6f4c309efc82f1aaf5';

abstract class _$GarminWorkoutSyncNotifier extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
