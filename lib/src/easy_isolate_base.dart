import 'dart:async';
import 'dart:isolate';
import 'package:async/async.dart';

enum EasyIsolateCommand { stop, notReady }

class EasyIsolate {
  var closed = false;
  var init = false;
  var count = 0;
  Completer? completer;
  late final List<ReceivePort> _returnPort;
  late List<SendPort?> _sendPort;
  late final dynamic Function(List<dynamic>) _func;
  late List<Stream<dynamic>?> _stream;
  late List<Completer?> _completerList;
  int worker;
  int _lastFreeWorkerIndex = 0;

  EasyIsolate(this._func, {this.worker = 1}) {
    if (worker < 1) {
      throw Exception("The worker should be at least 1.");
    }
    final tempReceivePort = List.generate(worker, (_) => ReceivePort());
    _returnPort = List.generate(worker, (_) => ReceivePort());
    _sendPort = List.filled(worker, null);
    _stream = List.filled(worker, null);
    _completerList = List.filled(worker, null);

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

    for (var i = 0; i < worker; i++) {
      Isolate.spawn(_generateFunc(_func),
          [_returnPort[i].sendPort, tempReceivePort[i].sendPort]);

      tempReceivePort[i].first.then((data) {
        _sendPort[i] = data;
        tempReceivePort[i].close();
      });

      _stream[i] = _returnPort[i].asBroadcastStream();
    }
  }

  int get lastFreeWorkerIndex => _lastFreeWorkerIndex;

  set lastFreeWorkerIndex(int v) {
    if (v >= worker) {
      _lastFreeWorkerIndex = 0;
    } else {
      _lastFreeWorkerIndex = v;
    }
  }

  Stream<dynamic> get stream async* {
    while (!init) {
      await Future.delayed(Duration(microseconds: 1));
    }
    await for (final i in StreamGroup.merge(
        _stream.where((i) => i != null).cast<Stream<dynamic>>())) {
      yield i;
    }
  }

  Future call(dynamic args) async {
    if (closed) {
      throw Exception("The instance is closed");
    }
    count += 1;
    if (!init) {
      for (var i = 0; i < worker; i++) {
        while (_sendPort[i] == null) {
          await Future.delayed(Duration(microseconds: 1));
        }
      }
      init = true;
    }
    var freeWorkerIndex = lastFreeWorkerIndex;
    while (true) {
      if (freeWorkerIndex >= worker) {
        freeWorkerIndex = 0;
        await Future.delayed(Duration(microseconds: 100));
      }
      if (_completerList[freeWorkerIndex] == null) break;
      freeWorkerIndex += 1;
    }
    lastFreeWorkerIndex = freeWorkerIndex + 1;
    _completerList[freeWorkerIndex] = Completer();
    _stream[freeWorkerIndex]?.first.then((data) {
      count -= 1;
      _completerList[freeWorkerIndex]?.complete(data);
      _completerList[freeWorkerIndex] = null;
    });

    if (_sendPort[freeWorkerIndex] != null) {
      _sendPort[freeWorkerIndex]?.send(args);
    } else {
      _completerList[freeWorkerIndex]?.complete(EasyIsolateCommand.notReady);
      _completerList[freeWorkerIndex] = null;
      count -= 1;
    }
    var ret = _completerList[freeWorkerIndex]!.future;
    return ret;
  }

  Future close() async {
    while (count > 0) {
      await Future.delayed(Duration(microseconds: 1));
    }
    for (var i = 0; i < worker; i++) {
      _sendPort[i]?.send(EasyIsolateCommand.stop);
      _returnPort[i].close();
    }
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
