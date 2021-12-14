import 'dart:async';
import 'dart:isolate';

Future<dynamic> runInIsolate(dynamic Function(List<dynamic>) func,
    [List<dynamic> args = const []]) async {
  void Function(List<dynamic>) _generateFunc(
      dynamic Function(List<dynamic>) func) {
    return (List<dynamic> args) {
      SendPort responsePort = args[0];
      dynamic ret;
      try {
        ret = func(args.sublist(1));
      } catch (e) {
        ret = e;
      }
      Isolate.exit(responsePort, ret);
    };
  }

  final p = ReceivePort();
  await Isolate.spawn(_generateFunc(func), [p.sendPort, ...args]);
  return (await p.first);
}

enum ActorCommand { stop }

class Actor {
  var count = 0;
  Completer? completer;
  final ReceivePort _returnPort = ReceivePort();
  SendPort? _argsPort;
  late final dynamic Function(List<dynamic>) _func;
  Stream<dynamic>? _stream;

  Actor(this._func) {
    void Function(List<dynamic>) _generateFunc(
        dynamic Function(List<dynamic>) func) {
      return (List<dynamic> args) async {
        SendPort responsePort = args[0];
        ReceivePort inputPort = ReceivePort();
        responsePort.send(inputPort.sendPort);

        inputPort.listen((args) {
          if (args is ActorCommand) {
            if (args == ActorCommand.stop) {
              inputPort.close();
              Isolate.exit();
            }
            return;
          }
          dynamic ret;
          try {
            ret = func(args);
          } catch (e) {
            ret = e;
          }
          responsePort.send(ret);
        });
      };
    }

    Isolate.spawn(_generateFunc(_func), [_returnPort.sendPort]);

    _stream = _returnPort.where((data) {
      if (data is SendPort) {
        _argsPort = data;
        return false;
      }
      count -= 1;
      return true;
    }).asBroadcastStream();

    stream.listen((data) async {
      if (completer == null) {
        return;
      }
      completer?.complete(data);
      completer = null;
    });
  }

  Stream<dynamic> get stream async* {
    while (_stream == null) {
      await Future.delayed(Duration(microseconds: 1));
    }
    await for (final i in _stream!) {
      yield i;
    }
  }

  Future call(dynamic args) async {
    count += 1;
    while (completer != null || _argsPort == null) {
      await Future.delayed(Duration(microseconds: 1));
    }
    completer = Completer();
    if (_argsPort != null) {
      _argsPort?.send(args);
    } else {
      completer?.complete(null);
      count -= 1;
    }
    var ret = completer!.future;
    return ret;
  }

  Future close() async {
    while (count > 0) {
      await Future.delayed(Duration(microseconds: 1));
    }
    _argsPort?.send(ActorCommand.stop);
    _returnPort.close();
  }

  Future wait([Duration duration = const Duration(milliseconds: 1)]) async {
    await Future.delayed(duration);
  }
}
