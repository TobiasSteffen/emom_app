import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/equipment_catalog.dart';
import '../../core/providers/equipment_catalog_notifier.dart';
import 'equipment_wizard_screen.dart';

class EquipmentCatalogScreen extends ConsumerWidget {
  const EquipmentCatalogScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref, EquipmentType t) async {
    try {
      await ref.read(equipmentCatalogProvider.notifier).deleteEquipmentType(t.id);
    } on StateError catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: Colors.red[900]),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(equipmentCatalogProvider);
    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white38),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'GERÄTE & ÜBUNGEN',
          style: TextStyle(fontSize: 15, letterSpacing: 4, color: Colors.white38),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(0xFFFF6B00)),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EquipmentWizardScreen()),
            ),
          ),
        ],
      ),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Fehler: $e', style: const TextStyle(color: Colors.white38)),
        ),
        data: (catalog) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          itemCount: catalog.types.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, idx) {
            final t = catalog.types[idx];
            return _EquipmentRow(
              equipment: t,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EquipmentWizardScreen(editType: t),
                ),
              ),
              onDelete: () => _delete(context, ref, t),
            );
          },
        ),
      ),
    );
  }
}

class _EquipmentRow extends StatefulWidget {
  final EquipmentType equipment;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _EquipmentRow({
    required this.equipment,
    required this.onTap,
    required this.onDelete,
  });

  @override
  State<_EquipmentRow> createState() => _EquipmentRowState();
}

class _EquipmentRowState extends State<_EquipmentRow> {
  bool _swiped = false;

  @override
  Widget build(BuildContext context) {
    final t = widget.equipment;
    final variantCount = t.variants.length;
    final exerciseCount = t.exercises.length;
    final subtitle = variantCount > 0
        ? '$variantCount Varianten · $exerciseCount Übungen'
        : 'keine Varianten · $exerciseCount Übungen';

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < -200) {
          setState(() => _swiped = true);
        }
      },
      onTap: () {
        if (_swiped) {
          setState(() => _swiped = false);
        } else {
          widget.onTap();
        }
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.red[900],
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: GestureDetector(
                onTap: widget.onDelete,
                child: const Icon(Icons.delete_outline, color: Colors.white, size: 20),
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            transform: Matrix4.translationValues(_swiped ? -72 : 0, 0, 0),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Image.asset(t.iconAsset, width: 22, height: 22,
                    color: const Color(0xFFFF6B00)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name,
                          style: const TextStyle(color: Colors.white, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(color: Colors.white38, fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: Color(0xFFFF6B00), size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
