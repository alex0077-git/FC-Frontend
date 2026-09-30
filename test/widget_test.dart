import 'package:fc_frontend/core/router/app_router.dart';
import 'package:fc_frontend/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => appRouter.go('/'));

  testWidgets('shows a blank scaffold', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: FcApp()));

    expect(find.byType(Scaffold), findsOneWidget);
  });
}
