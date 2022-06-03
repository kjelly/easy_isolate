import 'package:easy_isolate/easy_isolate.dart';

Future<void> main() async {
  var outside = 1;
  var o = await EasyIsolate.run((args) {
    print('outside: $outside');
    return args[2];
  }, [2, 3]);
  outside = 2;
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

  EasyIsolate.createStream((args) {
    return testStream(args);
  }).listen((data) {
    print('stream: $data');
  });
}

Stream testStream(List<dynamic> args) async* {
  var index = 0;
  while (index < 5) {
    yield index++;
  }
}
