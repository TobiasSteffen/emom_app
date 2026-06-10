// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_library_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PlanLibraryNotifier)
final planLibraryProvider = PlanLibraryNotifierProvider._();

final class PlanLibraryNotifierProvider
    extends $AsyncNotifierProvider<PlanLibraryNotifier, PlanLibrary> {
  PlanLibraryNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'planLibraryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$planLibraryNotifierHash();

  @$internal
  @override
  PlanLibraryNotifier create() => PlanLibraryNotifier();
}

String _$planLibraryNotifierHash() =>
    r'efe37d69a0c940e288511defb90d29be3fe64de6';

abstract class _$PlanLibraryNotifier extends $AsyncNotifier<PlanLibrary> {
  FutureOr<PlanLibrary> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PlanLibrary>, PlanLibrary>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PlanLibrary>, PlanLibrary>,
              AsyncValue<PlanLibrary>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
