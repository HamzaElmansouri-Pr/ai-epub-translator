import 'dart:async';
import 'package:flutter/foundation.dart';

class IsolateUtils {
  static Future<T> runInIsolate<T>(FutureOr<T> Function() computation) async {
    return await compute((_) => computation(), null);
  }
}
