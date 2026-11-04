import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:proalbums/features/vault/presentation/widgets/vault_pin_pad.dart';

Widget _app(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('digits, forgot and delete call back', (tester) async {
    final typed = <String>[];
    var deleted = 0;
    var forgot = 0;
    await tester.pumpWidget(
      _app(
        VaultPinPad(
          onDigit: typed.add,
          onDelete: () => deleted++,
          canDelete: true,
          onForgot: () => forgot++,
        ),
      ),
    );
    for (final digit in ['1', '5', '9', '0']) {
      await tester.tap(find.text(digit));
    }
    await tester.tap(find.byIcon(LucideIcons.delete));
    await tester.tap(find.text('Forgot\npassword'));
    expect(typed, ['1', '5', '9', '0']);
    expect(deleted, 1);
    expect(forgot, 1);
  });

  testWidgets('delete is off while empty, all keys off when disabled', (
    tester,
  ) async {
    final typed = <String>[];
    var deleted = 0;
    await tester.pumpWidget(
      _app(
        VaultPinPad(
          onDigit: typed.add,
          onDelete: () => deleted++,
          canDelete: false,
        ),
      ),
    );
    await tester.tap(find.byIcon(LucideIcons.delete));
    expect(deleted, 0);

    await tester.pumpWidget(
      _app(
        VaultPinPad(
          onDigit: typed.add,
          onDelete: () => deleted++,
          canDelete: true,
          enabled: false,
        ),
      ),
    );
    await tester.tap(find.text('7'));
    await tester.tap(find.byIcon(LucideIcons.delete));
    expect(typed, isEmpty);
    expect(deleted, 0);
    // No "Forgot password" key when none is given.
    expect(find.text('Forgot\npassword'), findsNothing);
  });

  testWidgets('dots show how many digits, never the digits', (tester) async {
    await tester.pumpWidget(_app(const VaultPinDots(filled: 3)));
    expect(find.bySemanticsLabel('3 of 6 digits entered'), findsOneWidget);
    expect(find.text('3'), findsNothing);
  });
}
