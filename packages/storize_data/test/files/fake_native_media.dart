import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:storize_platform_android/storize_platform_android.dart';

import 'plugin_rules.dart';

class FakeRow {
  FakeRow(this.size, this.relativePath, this.displayName);
  final int size;
  final String relativePath;
  final String displayName;
}

/// A fake `storize/media` native side with an in-memory MediaStore.
///
/// It applies the plugin's validation rules, renames duplicates to
/// `name (1).ext`, and can refuse `Pictures/` for video like some Android 10
/// builds do.
class FakeNativeMedia {
  FakeNativeMedia() {
    _messenger.setMockMethodCallHandler(channel, _handle);
    addTearDown(
      () => _messenger.setMockMethodCallHandler(channel, null),
    );
  }

  static final TestDefaultBinaryMessenger _messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final MethodChannel channel = const MethodChannel('storize/media');
  final Map<String, FakeRow> rows = {};
  final List<MethodCall> calls = [];

  /// Make video inserts land in `Movies/Storize/`.
  bool videoFallsBackToMovies = false;

  /// Leave `relativePath` out of the insert answer.
  bool omitRelativePath = false;

  /// Throw this on the next call.
  PlatformException? failNext;
  int _next = 0;

  StorizePlatformAndroid get api => StorizePlatformAndroid(media: channel);

  Future<Object?> _handle(MethodCall call) async {
    calls.add(call);
    final err = failNext;
    if (err != null) {
      failNext = null;
      throw err;
    }
    final args = Map<String, Object?>.from(call.arguments as Map);
    switch (call.method) {
      case 'insert':
        final dir = args['relativeDir'] as String?;
        final name = args['displayName'] as String?;
        final mime = args['mime'] as String?;
        final dirReason = pluginRejectsRelativeDir(dir);
        final nameReason = pluginRejectsDisplayName(name);
        if (dirReason != null || nameReason != null) {
          throw PlatformException(
            code: 'INVALID_ARGUMENT',
            message: 'rejected ${dirReason ?? nameReason}',
          );
        }
        final source = File(args['sourcePath']! as String);
        if (!source.existsSync()) {
          throw PlatformException(
            code: 'SOURCE_NOT_FOUND',
            message: 'missing ${source.path}',
          );
        }
        final isVideo = mime == 'video/mp4';
        final top = isVideo && videoFallsBackToMovies ? 'Movies' : 'Pictures';
        final path = '$top/Storize/$dir/';
        var finalName = name!;
        var i = 0;
        while (rows.values.any(
          (r) => r.relativePath == path && r.displayName == finalName,
        )) {
          final dot = name.lastIndexOf('.');
          final base = dot > 0 ? name.substring(0, dot) : name;
          final ext = dot > 0 ? name.substring(dot) : '';
          finalName = '$base (${++i})$ext';
        }
        final size = source.lengthSync();
        final uri =
            'content://media/external/${isVideo ? 'video' : 'images'}'
            '/media/${++_next}';
        rows[uri] = FakeRow(size, path, finalName);
        return {
          'uri': uri,
          'size': size,
          'displayName': finalName,
          if (!omitRelativePath) 'relativePath': path,
        };
      case 'delete':
        return rows.remove(args['uri']) != null;
      case 'exists':
        return rows.containsKey(args['uri']);
      case 'size':
        return rows[args['uri']]?.size;
    }
    throw MissingPluginException(call.method);
  }
}
