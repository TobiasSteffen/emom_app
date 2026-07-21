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
    r'f9c12fbe24fd37c40531c034f475226041a8cb25';

abstract class _$EquipmentCatalogNotifier
    extends $AsyncNotifier<EquipmentCatalog> {
  FutureOr<EquipmentCatalog> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
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
    return element.handleCreate(ref, build);
  }
}
