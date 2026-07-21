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

String _$workoutNotifierHash() => r'de4043c523f2d3cb686597c0d32a60ac7e23ce90';

abstract class _$WorkoutNotifier extends $AsyncNotifier<WorkoutState> {
  FutureOr<WorkoutState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<WorkoutState>, WorkoutState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<WorkoutState>, WorkoutState>,
              AsyncValue<WorkoutState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
