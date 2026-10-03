import 'package:fc_frontend/core/widgets/home_button.dart';
import 'package:fc_frontend/features/ground_plan/ground_plan_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroundPlanBar extends ConsumerWidget {
  const GroundPlanBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(groundPlanSectionProvider).section;
    return Row(
      children: [
        const Expanded(child: HomeButton()),
        Expanded(
          child: _SectionButton(
            label: 'Boundaries',
            icon: Icons.polyline_outlined,
            selected: open == GroundPlanSection.boundary,
            onPressed: () => _toggle(ref, GroundPlanSection.boundary),
          ),
        ),
        Expanded(
          child: _SectionButton(
            label: 'Split',
            icon: Icons.call_split,
            selected: open == GroundPlanSection.split,
            onPressed: () => _toggle(ref, GroundPlanSection.split),
          ),
        ),
        Expanded(
          child: _SectionButton(
            label: 'Obstacles',
            icon: Icons.block,
            selected: open == GroundPlanSection.obstacles,
            onPressed: () => _toggle(ref, GroundPlanSection.obstacles),
          ),
        ),
        Expanded(
          child: _SectionButton(
            label: 'Waypoints',
            icon: Icons.place_outlined,
            selected: open == GroundPlanSection.waypoints,
            onPressed: () => _toggle(ref, GroundPlanSection.waypoints),
          ),
        ),
        Expanded(
          child: _SectionButton(
            label: 'History',
            icon: Icons.history,
            selected: open == GroundPlanSection.history,
            onPressed: () => _toggle(ref, GroundPlanSection.history),
          ),
        ),
      ],
    );
  }

  void _toggle(WidgetRef ref, GroundPlanSection section) {
    ref.read(groundPlanSectionProvider.notifier).toggle(section);
  }
}

class _SectionButton extends StatelessWidget {
  const _SectionButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurface;
    return InkWell(
      onTap: onPressed,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, height: 1.1, color: color),
          ),
        ],
      ),
    );
  }
}

