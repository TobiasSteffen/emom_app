// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'workout_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(WorkoutNotifier)
final workoutProvider = WorkoutNotifierProvider._();

final class WorkoutNotifierProvider
    extends $AsyncNotifierProvider<WorkoutNotifier, WorkoutState> {
  WorkoutNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'workoutProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$workoutNotifierHash();

  @$internal
  @override
  WorkoutNotifier create() => WorkoutNotifier();
}

String _$workoutNotifierHash() => r'acd6f388d63399de6197cd1212424bab058a7947';

abstract class _$WorkoutNotifier extends $AsyncNotifier<WorkoutState> {
  FutureOr<WorkoutState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<WorkoutState>, WorkoutState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<WorkoutState>, WorkoutState>,
              AsyncValue<WorkoutState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
