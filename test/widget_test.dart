// Basic smoke test for the converted app's actual root widget.
//
// The original Flutter-template counter test (which built `MyApp` and
// tapped a '+' icon) no longer applies to this app and has been replaced.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pharma_game_changer/main.dart';

void main() {
  testWidgets('PharmaGameChangerApp builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const PharmaGameChangerApp());
    await tester.pump();

    // Confirms the root widget is a correctly configured MaterialApp.
    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.title, 'Pharma Game Changer');

    // The home screen depends on whether Supabase credentials have been
    // filled in (SetupNeededScreen if not, LoginScreen if so) -- either is
    // a valid successful build, so just confirm something real rendered
    // rather than pinning the test to one specific screen.
    expect(find.byType(Scaffold), findsWidgets);
  });
}
