import 'package:fc_frontend/core/geometry/area_math.dart';
import 'package:fc_frontend/core/widgets/obstacle_map_layers.dart';
import 'package:fc_frontend/data/repositories/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _areaUnitKey = 'ground_plan_area_unit';

class AreaUnitController extends StateNotifier<AreaUnit> {
  AreaUnitController(this._preferences) : super(_stored(_preferences));

  final SharedPreferences _preferences;

  Future<void> cycle() async {
    final next = AreaUnit.values[(state.index + 1) % AreaUnit.values.length];
    state = next;
    await _preferences.setString(_areaUnitKey, next.name);
  }
}

final areaUnitProvider = StateNotifierProvider<AreaUnitController, AreaUnit>((ref) {
  return AreaUnitController(ref.watch(sharedPreferencesProvider));
});

AreaUnit _stored(SharedPreferences preferences) {
  final name = preferences.getString(_areaUnitKey);
  for (final unit in AreaUnit.values) {
    if (unit.name == name) {
      return unit;
    }
  }
  return AreaUnit.hectare;
}

/// Plain area text. No fill, border, or card behind it.
class AreaMapChip extends StatelessWidget {
  const AreaMapChip({
    super.key,
    required this.area,
    required this.unit,
    required this.onCycleUnit,
  });

  final FieldArea area;
  final AreaUnit unit;
  final VoidCallback onCycleUnit;

  @override
  Widget build(BuildContext context) {
    final label = area.isValid ? formatArea(area.netSquareMeters!, unit) : '-';
    return GestureDetector(
      onTap: onCycleUnit,
      behavior: HitTestBehavior.translucent,
      child: Center(child: AreaValueText(label)),
    );
  }
}
