import 'dart:async';
import 'dart:isolate';

enum EasyIsolateCommand { stop }

class EasyIsolate {
  var closed = false;
  var count = 0;
  Completer? completer;
  final ReceivePort _returnPort = ReceivePort();
  SendPort? _argsPort;
  late final dynamic Function(List<dynamic>) _func;
  Stream<dynamic>? _stream;

  EasyIsolate(this._func) {
    final metaPort = ReceivePort();
    void Function(List<dynamic>) _generateFunc(
        dynamic Function(List<dynamic>) func) {
      return (List<dynamic> args) async {
        SendPort responsePort = args[0];
        SendPort metaSendPort = args[1];
        ReceivePort inputPort = ReceivePort();
        metaSendPort.send(inputPort.sendPort);

        inputPort.listen((args) {
          if (args is EasyIsolateCommand) {
            if (args == EasyIsolateCommand.stop) {
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

    Isolate.spawn(
        _generateFunc(_func), [_returnPort.sendPort, metaPort.sendPort]);

    metaPort.listen((data) {
      _argsPort = data;
      metaPort.close();
    });

    _stream = _returnPort.asBroadcastStream();

    _stream?.listen((data) async {
      count -= 1;
      if (completer == null) {
        return;
      }
      completer?.complete(data);
      completer = null;
    });
  }

  Stream<dynamic> get stream {
    return _stream!;
  }

  Future call(dynamic args) async {
    if (closed) {
      throw Exception("The actor is closed");
    }
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
    _argsPort?.send(EasyIsolateCommand.stop);
    _returnPort.close();
    closed = true;
  }

  static run(dynamic Function(List<dynamic>) func,
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
}
