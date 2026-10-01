import 'package:fc_frontend/core/theme/app_theme.dart';
import 'package:fc_frontend/data/models/boundary_edit.dart';
import 'package:fc_frontend/data/repositories/mission_repository.dart';
import 'package:fc_frontend/data/repositories/settings_repository.dart';
import 'package:fc_frontend/features/ground_plan/ground_plan_page.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('undo steps back through add, move, and delete', () {
    final repo = MissionRepository();
    repo.addBoundaryPoint(latitude: 1, longitude: 10);
    repo.addBoundaryPoint(latitude: 2, longitude: 20);
    repo.addBoundaryPoint(latitude: 3, longitude: 30);
    final moved = repo.state.boundaryPoints[1];
    repo.updateBoundaryPoint(
      id: moved.id,
      latitude: 2.5,
      longitude: 20.5,
      altitude: 40,
      speed: 6,
    );
    final last = repo.state.boundaryPoints.last;
    repo.deleteBoundaryPoint(last.id);

    expect(repo.state.boundaryPoints.length, 2);
    expect(repo.state.undoHistory.last.kind, BoundaryEditKind.delete);

    repo.undoBoundaryEdit();
    expect(repo.state.boundaryPoints.length, 3);
    expect(repo.state.boundaryPoints[1].latitude, 2.5);

    repo.undoBoundaryEdit();
    expect(repo.state.boundaryPoints[1].latitude, 2);
    expect(repo.state.boundaryPoints[1].altitude, 30);
    expect(repo.state.boundaryPoints[0].latitude, 1);

    repo.undoBoundaryEdit();
    expect(repo.state.boundaryPoints.length, 2);
    expect(repo.state.boundaryPoints.last.latitude, 2);

    repo.redoBoundaryEdit();
    expect(repo.state.boundaryPoints.length, 3);
    repo.addBoundaryPoint(latitude: 4, longitude: 40);
    expect(repo.state.redoHistory, isEmpty);
    expect(repo.state.boundaryPoints.last.latitude, 4);
  });

  test('undo does not change coverage after call for job', () async {
    final repo = MissionRepository();
    repo.addBoundaryPoint(latitude: 12.970, longitude: 77.590);
    repo.addBoundaryPoint(latitude: 12.970, longitude: 77.595);
    repo.addBoundaryPoint(latitude: 12.974, longitude: 77.595);

    await repo.generateCoverage(spacingMeters: 40, orientationDegrees: 0);
    final lines = repo.state.coverageLines.length;
    final boundary = [
      for (final point in repo.state.boundaryPoints) point.latitude,
    ];

    repo.undoBoundaryEdit();
    repo.updateBoundaryPoint(
      id: repo.state.boundaryPoints.first.id,
      latitude: 0,
      longitude: 0,
      altitude: 1,
      speed: 1,
    );
    repo.deleteBoundaryPoint(repo.state.boundaryPoints.first.id);

    expect(repo.state.boundaryEditingLocked, isTrue);
    expect(repo.state.coverageLines.length, lines);
    expect(
      [for (final point in repo.state.boundaryPoints) point.latitude],
      boundary,
    );
  });

  test('reset clears the boundary and the history', () {
    final repo = MissionRepository();
    repo.addBoundaryPoint(latitude: 1, longitude: 1);
    repo.undoBoundaryEdit();
    expect(repo.state.redoHistory, isNotEmpty);

    repo.resetBoundary();

    expect(repo.state.boundaryPoints, isEmpty);
    expect(repo.state.undoHistory, isEmpty);
    expect(repo.state.redoHistory, isEmpty);
    expect(repo.state.boundaryEditingLocked, isFalse);
  });

  testWidgets('undo and redo buttons follow the history', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const GroundPlanPage(),
        ),
      ),
    );
    await tester.pump();

    expect(_historyButton(tester, 'Undo').onPressed, isNull);
    expect(_historyButton(tester, 'Redo').onPressed, isNull);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GroundPlanPage)),
    );
    final repo = container.read(missionRepositoryProvider.notifier);
    repo.addBoundaryPoint(latitude: 12.9716, longitude: 77.5946);
    repo.addBoundaryPoint(latitude: 12.9720, longitude: 77.5950);
    await tester.pump();

    expect(find.text('Call for Job'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Call for Job')).onPressed, isNull);

    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(container.read(missionRepositoryProvider).boundaryPoints.length, 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(container.read(missionRepositoryProvider).boundaryPoints, isEmpty);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(container.read(missionRepositoryProvider).boundaryPoints.length, 1);

    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();
    expect(find.text('Latitude'), findsOneWidget);
    expect(find.text('Waypoint number'), findsOneWidget);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(container.read(missionRepositoryProvider).boundaryPoints, isEmpty);
    expect(container.read(missionRepositoryProvider).undoHistory.last.kind, BoundaryEditKind.delete);
  });

  testWidgets('dragging a marker records a move for that point only', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: const GroundPlanPage(),
        ),
      ),
    );
    await tester.pump();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(GroundPlanPage)),
    );
    final repo = container.read(missionRepositoryProvider.notifier);
    repo.addBoundaryPoint(latitude: 12.9716, longitude: 77.5946);
    repo.addBoundaryPoint(latitude: 12.9800, longitude: 77.6100);
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('1')),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(30, 16));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    final points = container.read(missionRepositoryProvider).boundaryPoints;
    expect(points.first.latitude, isNot(12.9716));
    expect(points[1].latitude, 12.9800);
    expect(points[1].longitude, 77.6100);
    expect(
      container.read(missionRepositoryProvider).undoHistory.last.kind,
      BoundaryEditKind.move,
    );
  });
}

IconButton _historyButton(WidgetTester tester, String tooltip) {
  return tester.widget<IconButton>(
    find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == tooltip,
    ),
  );
}
