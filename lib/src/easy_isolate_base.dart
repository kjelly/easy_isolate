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
  bool initialized = false;
  var count = 0;
  Completer? completer;
  final ReceivePort _returnPort = ReceivePort();
  SendPort? _argsPort;
  late final dynamic Function(List<dynamic>) _func;
  Stream<dynamic>? _stream;

  Actor(this._func);

  Future init() async {
    if (initialized) {
      throw Exception('The actor already initialized');
    }
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

    await Isolate.spawn(_generateFunc(_func), [_returnPort.sendPort]);

    _stream = _returnPort.where((data) {
      if (data is SendPort) {
        _argsPort = data;
        initialized = true;
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
    await Future.delayed(Duration(milliseconds: 1));
  }

  Stream<dynamic> get stream {
    return _stream!;
  }

  Future _send(dynamic args) async {
    while (_argsPort == null) {
      await Future.delayed(Duration(milliseconds: 1));
    }
    if (_argsPort != null) {
      count += 1;
      _argsPort?.send(args);
    }
  }

  Future call(dynamic args) async {
    if (!initialized) {
      await init();
    }
    while (completer != null) {
      await Future.delayed(Duration(milliseconds: 1));
    }
    completer = Completer();
    await _send(args);
    var ret = completer!.future;
    return ret;
  }

  Future close() async {
    while (count > 0) {
      await Future.delayed(Duration(milliseconds: 1));
    }
    _argsPort?.send(ActorCommand.stop);
    _returnPort.close();
  }
}
