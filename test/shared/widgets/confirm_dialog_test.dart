import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/shared/widgets/confirm_dialog.dart';

Future<bool?> _open(
  WidgetTester tester, {
  String? cancelLabel,
  String tap = 'Cancel',
}) async {
  bool? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await (cancelLabel == null
                ? showConfirmDialog(
                    context,
                    title: 'T',
                    message: 'M',
                    confirmLabel: 'Go',
                  )
                : showConfirmDialog(
                    context,
                    title: 'T',
                    message: 'M',
                    confirmLabel: 'Go',
                    cancelLabel: cancelLabel,
                  ));
          },
          child: const Text('open'),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(tap));
  await tester.pumpAndSettle();
  return result;
}

void main() {
  testWidgets('Cancel gives false', (tester) async {
    expect(await _open(tester), isFalse);
  });

  testWidgets('the action button gives true', (tester) async {
    expect(await _open(tester, tap: 'Go'), isTrue);
  });

  testWidgets('cancelLabel replaces the Cancel text', (tester) async {
    expect(await _open(tester, cancelLabel: 'Not now', tap: 'Not now'), isFalse);
  });
}
