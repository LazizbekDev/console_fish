import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:aquarium/aquarium/fish_model.dart';
import 'package:aquarium/fish/fish.dart';
import 'package:aquarium/fish/fish_action.dart';
import 'package:aquarium/fish/fish_request.dart';
import 'package:aquarium/fish/genders.dart';
import 'package:aquarium/shark/shark.dart';
import 'package:aquarium/shark/shark_action.dart';
import 'package:aquarium/utils/fish_names.dart';
import 'package:uuid/uuid.dart';

class Aquarium {
  final Random _random = Random();
  final LinkedHashMap<String, FishModel> _fishList = LinkedHashMap();
  final ReceivePort _mainReceivePort = ReceivePort();
  SendPort? sharkSendPort;
  Isolate? sharkIsolate;
  int _newFishCount = 0;
  int _diedFishCount = 0;
  int _sharkTargets = 0;
  static int limitFishCount = 0;

  void runApp() {
    stdout.write("Enter initial fish count: ");
    final int count = int.tryParse(stdin.readLineSync() ?? '0') ?? 0;
    limitFishCount = count;
    portListener();
    initial(count);
    createShark();
  }

  void portListener() {
    _mainReceivePort.listen((value) {
      if (value is FishRequest) {
        switch (value.action) {
          case FishAction.sendPort:
            _fishList.update(
              value.fishId,
              (model) {
                (value.args as SendPort?)?.send(FishAction.startLife);
                return model.copyWith(
                  sendPort: (value.args as SendPort?),
                );
              },
            );
            break;
          case FishAction.fishDied:
            final model = _fishList[value.fishId];
            model?.sendPort?.send(FishAction.close);
            _diedFishCount++;
            break;
          case FishAction.killIsolate:
            death(value.fishId, false);

            _fishCount();
            break;
          case FishAction.needPopulate:
            population(value.fishId, value.args as Genders);
            break;
          default:
            break;
        }
      } else if (value is SendPort) {
        sharkSendPort = value;
        _sharkTargets = _fishList.length;
        _fishCount();
      } else if (value == SharkAction.kill) {
        _huntFish();
      }
    });
  }

  void _fishCount() {
    if (sharkSendPort != null) {
      final fishCount = _fishList.length;
      if (fishCount > limitFishCount) {
        sharkSendPort?.send({
          'action': SharkAction.start,
          'fishCount': fishCount,
        });
      } else {
        sharkSendPort?.send({'action': SharkAction.stop});
      }
    }
  }

  Future<void> createShark() async {
    final shark = Shark(_mainReceivePort.sendPort);
    sharkIsolate = await Isolate.spawn(Shark.run, shark);
  }

  void _huntFish() {
    if (_fishList.isNotEmpty) {
      final randomFishId =
          _fishList.keys.elementAt(_random.nextInt(_fishList.length));
      death(randomFishId, true);
      _diedFishCount++;
      _fishCount();
    }
  }

  void death(value, bool isShark) {
    final model = _fishList[value];
    model?.sendPort?.send(FishAction.close);
    model?.isolate.kill(
      priority: Isolate.immediate,
    );
    _fishList.remove(value);
    print(toString());
    if (isShark) {
      print('Shark ate id $value gender ${model?.genders}\n');
    }
  }

  void population(String fishId, Genders gender) {
    if (_fishList.isNotEmpty) {
      final sortFishList = _fishList.entries
          .where(
            (element) => element.value.genders != gender,
          )
          .toList();
      if (sortFishList.isNotEmpty) {
        final findIndex = _random.nextInt(sortFishList.length);
        final findFishId = sortFishList[findIndex].key;
        if (gender.isMale) {
          createFish(
            maleId: fishId,
            femaleId: findFishId,
          );
        } else {
          createFish(
            maleId: findFishId,
            femaleId: fishId,
          );
        }
      } else {
        closeAquarium();
      }
    }
  }

  void initial(int count) {
    for (int i = 0; i < count; i++) {
      createFish();
    }
  }

  void createFish({
    String? maleId,
    String? femaleId,
  }) async {
    final fishId = Uuid().v1(options: {
      "Male": maleId,
      "Female": femaleId,
    });
    final gender = _random.nextBool() ? Genders.male : Genders.female;
    final firstName = gender.isMale
        ? FishNames.maleFirst[_random.nextInt(FishNames.maleFirst.length)]
        : FishNames.femaleFirst[_random.nextInt(FishNames.femaleFirst.length)];
    final lastName = gender.isMale
        ? FishNames.maleLast[_random.nextInt(FishNames.maleLast.length)]
        : FishNames.femaleLast[_random.nextInt(FishNames.femaleLast.length)];
    final lifespan = Duration(seconds: _random.nextInt(40) + 5);
    final populateCount = _random.nextInt(1) + 1;
    final List<Duration> listPopulationTime = List.generate(
      populateCount,
      (index) => Duration(seconds: _random.nextInt(15) + 5),
    );

    final fish = Fish(
      id: fishId,
      firstName: firstName,
      lastName: lastName,
      gender: gender,
      lifespan: lifespan,
      listPopulationTime: listPopulationTime,
      sendPort: _mainReceivePort.sendPort,
    );
    final isolate = await Isolate.spawn(Fish.run, fish);
    _fishList[fishId] = FishModel(
      isolate: isolate,
      genders: gender,
    );
    _newFishCount++;
    print(toString());
  }

  void closeAquarium() {
    print(
        "there's no fishes in aquarium. shark have eaten $_sharkTargets fishes");
    exit(0);
  }

  @override
  String toString() {
    int fishCount = 0;
    int maleCount = 0;
    int femaleCount = 0;

    _fishList.forEach((key, value) {
      fishCount++;
      if (value.genders == Genders.male) {
        maleCount++;
      } else {
        femaleCount++;
      }
    });

    if (fishCount == 0) {
      closeAquarium();
    }
    // print('\x1B[2J\x1B[0;0H');
    return 'Aquarium info - Fish count: $fishCount, Male count: $maleCount, Female count: $femaleCount, New fish count: $_newFishCount, Died fish count: $_diedFishCount';
  }
}
