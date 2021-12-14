import 'package:easy_isolate/easy_isolate.dart';

Future<void> main() async {
  var o = await runInIsolate((args) {
    return args[2];
  }, [2, 3]);
  if (o is Error) {
    print(o);
  }

  Actor actor = Actor((args) {
    return 'actor' + args.toString();
  });
  actor.stream.listen((data) {
    print(data);
  });
  await actor.call(["bye"]);
  await actor.call(["bye"]);
  await actor.call(["bye"]);
  await actor.close();

  Actor actor1 = Actor((args) {
    return args + args;
  });
  actor1.stream.listen((data) {
    print('listen $data');
  });

  actor1.call(['1']).then((data) {
    print('call $data');
  });
  actor1.call(['2']).then((data) {
    print('call $data');
  });
  await actor.wait();
  actor1.close();
}
