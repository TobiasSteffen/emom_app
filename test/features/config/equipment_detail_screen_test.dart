import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:emom_app/core/models/equipment_catalog.dart';
import 'package:emom_app/core/models/training_plan.dart';
import 'package:emom_app/core/providers/equipment_catalog_notifier.dart';
import 'package:emom_app/core/providers/plan_library_notifier.dart';
import 'package:emom_app/features/config/equipment_detail_screen.dart';

// ── Test-Fixtures ────────────────────────────────────────────────────────────

/// Minimales Gerät mit zwei Varianten und zwei Übungen für die meisten Tests.
EquipmentType _testType() => const EquipmentType(
      id: 'test_geraet',
      name: 'Testgerät',
      iconAsset: 'assets/icon/kettlebell.png',
      variants: [
        EquipmentVariant(id: 'var_a', label: '10 kg', shortLabel: '10'),
        EquipmentVariant(id: 'var_b', label: '20 kg', shortLabel: '20'),
      ],
      exercises: [
        ExerciseType(id: 'ex_a', name: 'Übung A', hasSide: false),
        ExerciseType(id: 'ex_b', name: 'Übung B', hasSide: true),
      ],
    );

/// Gerät mit nur einer Übung — für den „letzte Übung"-Schutztest.
EquipmentType _singleExerciseType() => const EquipmentType(
      id: 'single_ex_geraet',
      name: 'Einzel-Gerät',
      iconAsset: 'assets/icon/kettlebell.png',
      variants: [
        EquipmentVariant(id: 'var_c', label: '5 kg', shortLabel: '5'),
      ],
      exercises: [
        ExerciseType(id: 'ex_only', name: 'Einzige Übung', hasSide: false),
      ],
    );

// ── Fake-Notifier ────────────────────────────────────────────────────────────

class _FakeEquipmentCatalogNotifier extends EquipmentCatalogNotifier {
  final EquipmentCatalog _initial;
  _FakeEquipmentCatalogNotifier(this._initial);

  @override
  Future<EquipmentCatalog> build() async => _initial;
}

class _FakePlanLibraryNotifier extends PlanLibraryNotifier {
  final PlanLibrary _initial;
  _FakePlanLibraryNotifier(this._initial);

  @override
  Future<PlanLibrary> build() async => _initial;
}

// ── Pump-Helper ───────────────────────────────────────────────────────────────

/// Pumpt [EquipmentDetailScreen] eingebettet in einen [Navigator], damit
/// Navigator.of(context).pop() funktioniert und PopScope ausgelöst wird.
Future<ProviderContainer> _pumpScreen(
  WidgetTester tester, {
  required EquipmentType type,
  PlanLibrary? library,
}) async {
  final catalog = EquipmentCatalog(types: [type]);
  final planLib = library ??
      PlanLibrary(
        plans: [
          TrainingPlan(
            id: 'empty-plan',
            name: 'Leerer Plan',
            intervals: [
              IntervalConfig(
                equipmentTypeId: 'other',
                exerciseTypeId: 'other_ex',
                reps: 10,
                durationSeconds: 60,
              ),
              IntervalConfig(
                equipmentTypeId: 'other',
                exerciseTypeId: 'other_ex',
                reps: 10,
                durationSeconds: 60,
              ),
              IntervalConfig(
                equipmentTypeId: 'other',
                exerciseTypeId: 'other_ex',
                reps: 10,
                durationSeconds: 60,
              ),
            ],
          )
        ],
        activePlanId: 'empty-plan',
      );

  late ProviderContainer container;

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        equipmentCatalogProvider
            .overrideWith(() => _FakeEquipmentCatalogNotifier(catalog)),
        planLibraryProvider
            .overrideWith(() => _FakePlanLibraryNotifier(planLib)),
      ],
      child: Builder(
        builder: (context) {
          container = ProviderScope.containerOf(context);
          return MaterialApp(
            home: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (_) => EquipmentDetailScreen(type: type),
              ),
            ),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

// ── Bild-Asset-Fehler unterdrücken ───────────────────────────────────────────

/// Flutter-Tests schmeißen [FlutterError] wenn Assets fehlen.
/// Da wir path_provider nicht initialisieren und Assets nicht gebündelt sind,
/// fangen wir Image-Ladefehler lokal ab, ohne den Test zu blockieren.
void Function(FlutterErrorDetails)? _originalError;

void _suppressImageErrors() {
  _originalError = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.exceptionAsString();
    // Bild-Ladefehler durchlassen, Rest normal behandeln
    if (msg.contains('Unable to load asset') ||
        msg.contains('HttpException') ||
        msg.contains('ImageCodecException')) {
      return; // ignorieren
    }
    _originalError?.call(details);
  };
}

void _restoreErrorHandler() {
  FlutterError.onError = _originalError;
}

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(_suppressImageErrors);
  tearDown(_restoreErrorHandler);

  testWidgets(
      'Speichern beim Verlassen übernimmt den neuen Namen',
      (tester) async {
    final type = _testType();
    final container = await _pumpScreen(tester, type: type);

    // Namensfeld leeren und neuen Namen eingeben
    final nameField = find.byType(TextField).first;
    await tester.tap(nameField);
    await tester.pumpAndSettle();
    await tester.enterText(nameField, 'Neuer Name');
    await tester.pumpAndSettle();

    // Zurück-Button tippen → löst PopScope → _save() wird aufgerufen
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    // Nach dem Pop lesen wir den Catalog-Zustand direkt aus dem Container
    final catalog = container.read(equipmentCatalogProvider).value;
    expect(catalog, isNotNull);
    final saved = catalog!.types.firstWhere((t) => t.id == type.id);
    expect(saved.name, 'Neuer Name');
  });

  testWidgets(
      'Leeres Namensfeld beim Verlassen behält den ursprünglichen Namen',
      (tester) async {
    final type = _testType();
    final container = await _pumpScreen(tester, type: type);

    // Namensfeld komplett leeren
    final nameField = find.byType(TextField).first;
    await tester.tap(nameField);
    await tester.pumpAndSettle();
    await tester.enterText(nameField, '');
    await tester.pumpAndSettle();

    // Zurück-Button → PopScope → _save()
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();

    final catalog = container.read(equipmentCatalogProvider).value;
    expect(catalog, isNotNull);
    final saved = catalog!.types.firstWhere((t) => t.id == type.id);
    // Leeres Feld → ursprünglicher Name bleibt erhalten
    expect(saved.name, type.name);
  });

  testWidgets(
      'Löschen einer benutzten Variante zeigt roten Snackbar und entfernt keine Zeile',
      (tester) async {
    final type = _testType();

    // Plan mit einer Variante referenzieren: var_a
    final library = PlanLibrary(
      plans: [
        TrainingPlan(
          id: 'plan-1',
          name: 'Plan mit Variante',
          intervals: [
            IntervalConfig(
              equipmentTypeId: type.id,
              variantId: 'var_a',
              exerciseTypeId: 'ex_a',
              reps: 10,
              durationSeconds: 60,
            ),
            IntervalConfig(
              equipmentTypeId: type.id,
              variantId: 'var_a',
              exerciseTypeId: 'ex_a',
              reps: 10,
              durationSeconds: 60,
            ),
            IntervalConfig(
              equipmentTypeId: type.id,
              variantId: 'var_a',
              exerciseTypeId: 'ex_a',
              reps: 10,
              durationSeconds: 60,
            ),
          ],
        )
      ],
      activePlanId: 'plan-1',
    );

    final container = await _pumpScreen(tester, type: type, library: library);

    // Sicherstellen, dass der PlanLibrary-Provider geladen ist,
    // bevor der EquipmentCatalogNotifier auf ihn zugreift.
    await container.read(planLibraryProvider.future);
    await tester.pump();

    // Ersten ✕-Button (Variante var_a) tippen
    // VariantRow enthält einen GestureDetector mit Icons.close
    final closeIcons = find.byIcon(Icons.close);
    // Die ersten Icons gehören zu den Varianten (var_a zuerst)
    await tester.tap(closeIcons.first);
    // pump damit setState abläuft, dann pump für Snackbar-Animation
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Snackbar-Text erscheint (ScaffoldMessenger zeigt den Text)
    expect(find.textContaining('Variante'), findsOneWidget);
    expect(find.textContaining('10 kg'), findsWidgets); // Variante noch vorhanden
    // Beide Varianten noch sichtbar (nicht gelöscht)
    expect(find.text('10 kg'), findsOneWidget);
    expect(find.text('20 kg'), findsOneWidget);
  });

  testWidgets(
      'Einzige Übung hat deaktivierten Löschen-Button (onDelete null)',
      (tester) async {
    final type = _singleExerciseType();
    await _pumpScreen(tester, type: type);

    // ExerciseRow hat ein Icon.close; bei onDelete==null ist es Colors.white12
    // Wir verifizieren, dass der Icon mit der schwachen Farbe dargestellt wird
    final closeIcon = tester.widget<Icon>(
      find.descendant(
        of: find.byType(GestureDetector),
        matching: find.byIcon(Icons.close),
      ).last,
    );
    expect(closeIcon.color, Colors.white12);
  });
}
