import 'package:aquarium/shark/shark_action.dart';

class SharkRequest {
  // final String fishId;
  final SharkAction action;
  final Object? args;

  const SharkRequest({
    required this.action,
    this.args,
  });
}
