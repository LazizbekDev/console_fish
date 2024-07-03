import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'package:aquarium/shark/shark_action.dart';

class Shark {
  ReceivePort? receivePort;
  SendPort? sendPort;
  Timer? _timer;
  Random random = Random();

  Shark(this.sendPort);

  void _listener() {
    receivePort?.listen((message) {
      if (message is Map<String, dynamic>) {
        switch (message['action']) {
          case SharkAction.start:
            if (_timer?.isActive ?? false) {
              return;
            } else {
              _start(message['fishCount']);
            }
            break;
          case SharkAction.stop:
            _waiting();
            break;
          default:
            break;
        }
      }
    });
  }

  void createReceivePort() {
    receivePort = ReceivePort();
    _listener();
    sendPort?.send(receivePort!.sendPort);
  }

  void _killFish() {
    sendPort?.send(SharkAction.kill);
  }

  void _waiting() {
    _timer?.cancel();
  }

  void _start(fishCount) {
    if (_timer != null) {
      _timer?.cancel();
    }
    int interval = fishCount > 30
        ? 2
        : fishCount > 20
            ? 5
            : 10;
    _timer = Timer.periodic(Duration(seconds: interval), (timer) {
      _killFish();
    });
  }

  static run(Shark shark) {
    shark.createReceivePort();
  }
}
