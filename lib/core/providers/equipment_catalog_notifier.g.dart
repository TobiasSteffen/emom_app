// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'equipment_catalog_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EquipmentCatalogNotifier)
final equipmentCatalogProvider = EquipmentCatalogNotifierProvider._();

final class EquipmentCatalogNotifierProvider
    extends $AsyncNotifierProvider<EquipmentCatalogNotifier, EquipmentCatalog> {
  EquipmentCatalogNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'equipmentCatalogProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$equipmentCatalogNotifierHash();

  @$internal
  @override
  EquipmentCatalogNotifier create() => EquipmentCatalogNotifier();
}

String _$equipmentCatalogNotifierHash() =>
    r'cff75622f6ba4b2e98874515b136d4eaf0a36a20';

abstract class _$EquipmentCatalogNotifier
    extends $AsyncNotifier<EquipmentCatalog> {
  FutureOr<EquipmentCatalog> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<EquipmentCatalog>, EquipmentCatalog>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<EquipmentCatalog>, EquipmentCatalog>,
              AsyncValue<EquipmentCatalog>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
