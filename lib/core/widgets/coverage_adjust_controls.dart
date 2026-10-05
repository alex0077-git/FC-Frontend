import 'package:fc_frontend/core/widgets/joystick_control.dart';
import 'package:fc_frontend/core/widgets/line_spacing_control.dart';
import 'package:fc_frontend/data/repositories/mission_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The orientation stick, line spacing, and edge margin on the Ground Plan
/// map. The stick moves on its own; the spray path follows on the coverage
/// timer.
class CoverageAdjustControls extends ConsumerWidget {
  const CoverageAdjustControls({super.key, this.gap = 8});

  final double gap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mission = ref.watch(missionRepositoryProvider);
    final repository = ref.read(missionRepositoryProvider.notifier);
    return Column(
      children: [
        Row(
          children: [
            JoystickControl(
              label: '',
              degrees: mission.orientationDegrees,
              size: 96,
              onChanged: (degrees) {
                repository.scheduleCoverage(orientationDegrees: degrees);
              },
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Orientation', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: repository.alignCoverageToLongestEdge,
                    child: const Text('Auto-align'),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: gap),
        LineSpacingControl(
          spacingMeters: mission.spacingMeters,
          lowerMeters: MissionRepository.lineSpacingLowerBound(
            mission.boundaryPoints,
          ),
          upperMeters: MissionRepository.lineSpacingUpperBound(
            mission.boundaryPoints,
          ),
          onChanged: (spacing) {
            repository.scheduleCoverage(spacingMeters: spacing);
          },
        ),
        LineSpacingControl(
          title: 'Edge margin',
          spacingMeters: mission.marginMeters,
          lowerMeters: 0,
          upperMeters: maxCoverageMarginMeters,
          decreaseTooltip: 'Decrease margin',
          increaseTooltip: 'Increase margin',
          onChanged: (margin) {
            repository.setCoverageMargin(margin);
          },
        ),
      ],
    );
  }
}
