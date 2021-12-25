import 'package:easy_isolate/easy_isolate.dart';
import 'dart:io';

Future<void> main() async {
  var o = await EasyIsolate.run((args) {
    return args[2];
  }, [2, 3]);
  if (o is Error) {
    print(o);
  }

  EasyIsolate actor = EasyIsolate((args) {
    return 'actor' + args.toString();
  });
  actor.stream.listen((data) {
    print(data);
  });
  await actor.call(["bye"]);
  await actor.call(["bye"]);
  await actor.call(["bye"]);
  await actor.close();

  EasyIsolate actor1 = EasyIsolate((args) {
    return args + args;
  }, worker: 1);
  actor1.stream.listen((data) {
    print('listen $data');
  });
  actor1.call(['1']).then((data) {
    print('call $data');
  });
  actor1.call(['2']).then((data) {
    print('call $data');
  });
  actor1.call(['3']).then((data) {
    print('call $data');
  });
  actor1.call(['4']).then((data) {
    print('call $data');
  });
  actor1.close();

  EasyIsolate.createStream((args) => Stream.fromIterable([1, 2, 3]))
      .listen((data) {
    print('stream: $data');
  });
}

Stream testStream(List<dynamic> args) async* {
  var index = 0;
  while (index < 5) {
    yield index++;
  }
}
