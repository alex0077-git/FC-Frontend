import 'package:flutter_riverpod/legacy.dart';

enum GroundPlanSection { boundary, split, obstacles, waypoints, history }

class GroundPlanFocus {
  const GroundPlanFocus({this.section, this.revision = 0});

  final GroundPlanSection? section;
  final int revision;
}

class GroundPlanSectionController extends StateNotifier<GroundPlanFocus> {
  GroundPlanSectionController() : super(const GroundPlanFocus());

  void open(GroundPlanSection section) {
    state = GroundPlanFocus(section: section, revision: state.revision + 1);
  }

  void toggle(GroundPlanSection section) {
    final next = state.section == section ? null : section;
    state = GroundPlanFocus(section: next, revision: state.revision + 1);
  }

  void close() {
    if (state.section == null) {
      return;
    }
    state = GroundPlanFocus(revision: state.revision + 1);
  }
}

final groundPlanSectionProvider =
    StateNotifierProvider.autoDispose<GroundPlanSectionController, GroundPlanFocus>(
      (ref) => GroundPlanSectionController(),
    );
