import 'dart:async';
import 'dart:isolate';

/// A helper to run long-running tasks in an isolate with progress reporting.
class IsolateProgressHelper {
  /// Runs [entryPoint] in an isolate.
  /// 
  /// The [entryPoint] function receives:
  /// 1. A [SendPort] to report progress (as a [double] between 0 and 1).
  /// 2. A [SendPort] to report the final result.
  /// 3. The [params] passed to this method.
  static Future<T> run<T, P>(
    void Function(SendPort progressPort, SendPort resultPort, P params) entryPoint,
    P params, {
    void Function(double)? onProgress,
  }) async {
    final progressReceivePort = ReceivePort();
    final resultReceivePort = ReceivePort();
    final errorReceivePort = ReceivePort();

    final isolate = await Isolate.spawn<_IsolateInitParams<P>>(
      _isolateEntry,
      _IsolateInitParams<P>(
        entryPoint: entryPoint,
        params: params,
        progressSendPort: progressReceivePort.sendPort,
        resultSendPort: resultReceivePort.sendPort,
      ),
      onError: errorReceivePort.sendPort,
    );

    final completer = Completer<T>();

    // Listen for progress updates
    final progressSubscription = progressReceivePort.listen((message) {
      if (message is double && onProgress != null) {
        onProgress(message);
      }
    });

    // Listen for results
    final resultSubscription = resultReceivePort.listen((message) {
      if (!completer.isCompleted) {
        completer.complete(message as T);
      }
    });

    // Listen for errors
    final errorSubscription = errorReceivePort.listen((message) {
      if (!completer.isCompleted) {
        if (message is List && message.length >= 2) {
          completer.completeError(
            message[0],
            StackTrace.fromString(message[1] as String),
          );
        } else {
          completer.completeError(message);
        }
      }
    });

    try {
      final result = await completer.future;
      return result;
    } finally {
      // Cleanup
      progressSubscription.cancel();
      resultSubscription.cancel();
      errorSubscription.cancel();
      progressReceivePort.close();
      resultReceivePort.close();
      errorReceivePort.close();
      isolate.kill();
    }
  }

  static void _isolateEntry<P>(_IsolateInitParams<P> init) {
    init.entryPoint(init.progressSendPort, init.resultSendPort, init.params);
  }
}

class _IsolateInitParams<P> {
  final void Function(SendPort, SendPort, P) entryPoint;
  final P params;
  final SendPort progressSendPort;
  final SendPort resultSendPort;

  _IsolateInitParams({
    required this.entryPoint,
    required this.params,
    required this.progressSendPort,
    required this.resultSendPort,
  });
}
