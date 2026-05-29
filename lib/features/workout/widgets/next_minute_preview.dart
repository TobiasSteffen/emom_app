import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/models/training_plan.dart';
import '../../../core/models/settings.dart';
import '../../../core/providers/equipment_catalog_notifier.dart';

class NextMinutePreview extends ConsumerWidget {
  final IntervalConfig interval;

  const NextMinutePreview({super.key, required this.interval});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const style = TextStyle(color: Colors.white38, fontSize: 11, letterSpacing: 1);

    if (interval.isPause) {
      return Text('Nächste: PAUSE · ${interval.durationSeconds}s', style: style);
    }

    final catalogAsync = ref.watch(equipmentCatalogProvider);
    return catalogAsync.when(
      loading: () => const SizedBox(),
      error: (e, _) => const SizedBox(),
      data: (catalog) {
        final eqType = catalog.findType(interval.equipmentTypeId);
        if (eqType == null) return const SizedBox();
        final variant = interval.variantId != null
            ? eqType.variants.where((v) => v.id == interval.variantId).firstOrNull
            : null;
        final exercise = eqType.exercises
            .where((e) => e.id == interval.exerciseTypeId)
            .firstOrNull;
        final equipLabel = variant != null
            ? '${eqType.name} ${variant.label}'
            : eqType.name;
        final exerciseLabel = interval.side != null
            ? '${exercise?.name ?? '?'} ${interval.side!.shortLabel}'
            : (exercise?.name ?? '?');
        final parts = [equipLabel, exerciseLabel, '${interval.reps}W', '${interval.durationSeconds}s'];
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(eqType.iconAsset, width: 12, height: 12, color: Colors.white38),
            const SizedBox(width: 5),
            Text(parts.join(' · '), style: style),
          ],
        );
      },
    );
  }
}
