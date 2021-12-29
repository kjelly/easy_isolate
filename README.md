# EasyIsolate

The library provide a wrapper to use the isolate more easily.

## Usecase

### Call one, get one

Run the anonymous function in the another isolate. When the anonymous function finished,
the isolate end.
```
import 'package:easy_isolate/easy_isolate.dart';
Future<void> main() async {
  var o = await EasyIsolate.run((args) {return args[0];}, [1, 2]);
  // o will be 1.
}
```

### Call one, get one, multiple isolates

Create multiple isolates to  wait for request.
Send the request by calling the `call` method.
If no more request, call the close method to end the isolates.
The isolates will be alive till the `close` method is called.

```
import 'package:easy_isolate/easy_isolate.dart';
Future<void> main() async {
  EasyIsolate actor1 = EasyIsolate((args) {
    return args + args;
  }, worker: 2);
  await actor.call(["bye"]);
  await actor.close();
}
```

### Call one, get stream, multiple isolates

Create the stream in the another isolate. When the stream end,
The isolate end.

```
import 'package:easy_isolate/easy_isolate.dart';
Future<void> main() async {
  EasyIsolate.createStream((args) {
    return testStream();
  }).listen((data) {
    print('stream: $data');
  });
}
Stream testStream() async* {
  var index = 0;
  while (index < 5) {
    yield index++;
  }
}
```
