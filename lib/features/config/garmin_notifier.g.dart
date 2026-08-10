// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'garmin_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GarminNotifier)
final garminProvider = GarminNotifierProvider._();

final class GarminNotifierProvider
    extends $AsyncNotifierProvider<GarminNotifier, GarminConnectionStatus> {
  GarminNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'garminProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$garminNotifierHash();

  @$internal
  @override
  GarminNotifier create() => GarminNotifier();
}

String _$garminNotifierHash() => r'd13496f19751f4ef3401568c9bf949e2da88860f';

abstract class _$GarminNotifier extends $AsyncNotifier<GarminConnectionStatus> {
  FutureOr<GarminConnectionStatus> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<GarminConnectionStatus>, GarminConnectionStatus>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<GarminConnectionStatus>,
                GarminConnectionStatus
              >,
              AsyncValue<GarminConnectionStatus>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
