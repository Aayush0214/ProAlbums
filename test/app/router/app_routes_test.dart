import 'package:flutter_test/flutter_test.dart';
import 'package:proalbums/app/router/app_routes.dart';

void main() {
  test('album path carries the id and the title', () {
    final uri = Uri.parse(AppRoutes.album('-161', 'Holiday & Fun'));
    expect(uri.pathSegments, ['album', '-161']);
    expect(uri.queryParameters['name'], 'Holiday & Fun');
  });

  test('ids with special characters stay one path segment', () {
    final uri = Uri.parse(AppRoutes.viewer('a/b c'));
    expect(uri.pathSegments.length, 2);
    expect(Uri.decodeComponent(uri.pathSegments.last), 'a/b c');
  });

  test('change cover path', () {
    expect(AppRoutes.changeCover('all'), '/change-cover/all');
  });

  test('move/copy path, with and without the source album', () {
    expect(AppRoutes.moveCopy(), AppRoutes.moveCopyPath);
    final uri = Uri.parse(AppRoutes.moveCopy(fromAlbumId: '-161 &x'));
    expect(uri.path, AppRoutes.moveCopyPath);
    expect(uri.queryParameters['from'], '-161 &x');
  });
}
