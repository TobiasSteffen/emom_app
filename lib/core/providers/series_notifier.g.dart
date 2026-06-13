// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'series_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SeriesNotifier)
final seriesProvider = SeriesNotifierProvider._();

final class SeriesNotifierProvider
    extends $AsyncNotifierProvider<SeriesNotifier, List<TrainingSeries>> {
  SeriesNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'seriesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$seriesNotifierHash();

  @$internal
  @override
  SeriesNotifier create() => SeriesNotifier();
}

String _$seriesNotifierHash() => r'589f2ed8b3ce48769458a755151a61c41ccb1b03';

abstract class _$SeriesNotifier extends $AsyncNotifier<List<TrainingSeries>> {
  FutureOr<List<TrainingSeries>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<List<TrainingSeries>>, List<TrainingSeries>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<TrainingSeries>>,
                List<TrainingSeries>
              >,
              AsyncValue<List<TrainingSeries>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
