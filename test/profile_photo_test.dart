import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daladala/profile/profile_avatar.dart';
import 'package:daladala/profile/profile_photo_state.dart';

void main() {
  test('keeps the current photo when upload or delete fails', () {
    const current = ProfilePhotoView(updatedAt: '2026-10-07T00:00:00.000Z');
    expect(current.uploading().failed().updatedAt, current.updatedAt);
    expect(current.uploading().failed().hasPhoto, isTrue);
    expect(current.saved('2026-10-07T01:00:00.000Z').updatedAt, '2026-10-07T01:00:00.000Z');
    expect(current.removed().hasPhoto, isFalse);
  });

  testWidgets('shows initials when there is no photo and the file when there is', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProfileAvatar(initials: 'JO', onTap: () {}),
      ),
    );
    expect(find.text('JO'), findsOneWidget);
  });

  test('uses a stored file when a profile photo exists', () async {
    final missing = File('${Directory.systemTemp.path}/buspay-missing-avatar.jpg');
    expect(profilePhotoFileReady(null), isFalse);
    expect(profilePhotoFileReady(missing), isFalse);
    final file = File('${Directory.systemTemp.path}/buspay-avatar-test.jpg');
    await file.writeAsBytes(const [1]);
    addTearDown(() {
      try {
        file.deleteSync();
      } catch (_) {}
    });
    expect(profilePhotoFileReady(file), isTrue);
  });
}
