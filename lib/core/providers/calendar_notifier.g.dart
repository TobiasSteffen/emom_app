// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CalendarNotifier)
final calendarProvider = CalendarNotifierProvider._();

final class CalendarNotifierProvider
    extends $AsyncNotifierProvider<CalendarNotifier, List<CalendarEntry>> {
  CalendarNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'calendarProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$calendarNotifierHash();

  @$internal
  @override
  CalendarNotifier create() => CalendarNotifier();
}

String _$calendarNotifierHash() => r'339f3de75debc3431cd2ba81ab077560a75dfd7b';

abstract class _$CalendarNotifier extends $AsyncNotifier<List<CalendarEntry>> {
  FutureOr<List<CalendarEntry>> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<CalendarEntry>>, List<CalendarEntry>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<CalendarEntry>>, List<CalendarEntry>>,
              AsyncValue<List<CalendarEntry>>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
