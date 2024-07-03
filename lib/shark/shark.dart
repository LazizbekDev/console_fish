import 'dart:async';
import 'dart:isolate';
import 'dart:math';

import 'package:aquarium/aquarium/aquarium.dart';
import 'package:aquarium/shark/shark_action.dart';
import 'package:aquarium/shark/shark_request.dart';

class Shark {
  ReceivePort? receivePort;
  SendPort? sendPort;
  Timer? _timer;
  Random random = Random();

  Shark(this.sendPort) {
    receivePort = ReceivePort();
    sendPort?.send(receivePort?.sendPort);
    _listener();
  }

  void _listener() {
    receivePort?.listen((message) {
      if (message is SharkAction) {
        if (message case SharkAction.stop) {
          _waiting();
        } else if (message case SharkAction.start) {
          if (_timer?.isActive ?? false) {
            return;
          } else {
            _start();
          }
        }
      }
    });
  }

  void createReceivePort() {
    receivePort = ReceivePort();
    _listener();
    sendPort?.send(
      SharkRequest(
        action: SharkAction.sendPort,
        args: receivePort?.sendPort,
      ),
    );
  }

  void _killFish() {
    sendPort?.send(SharkRequest(action: SharkAction.kill));
  }

  void _waiting() {
    _timer?.cancel();
  }

  void _start() {
    if (_timer != null) {
      _timer?.cancel();
    }
    final seconds = intervalBetween();
    _timer = Timer(Duration(seconds: seconds), () {
      _killFish();
      _start();
    });
  }

  static run(Shark shark) {
    shark.createReceivePort();
  }

  int intervalBetween() {
    final fishCount = Aquarium().getFishCount();
    final int baseInterval = 10;
    

    return random.nextInt(fishCount > 30
            ? 20
            : fishCount > 20
                ? 40
                : 50) +
        baseInterval;
  }
}
