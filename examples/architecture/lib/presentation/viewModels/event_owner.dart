import 'dart:async';

/// Owns an event stream; callers borrow the stream rather than its controller.
class EventOwner {
  final StreamController<int> _streamController =
      StreamController<int>.broadcast();

  Stream<int> get values => _streamController.stream;

  Future<void> dispose() => _streamController.close();

  void publish(int value) {
    _streamController.add(value);
  }
}

Future<void> main() async {
  final EventOwner eventOwner = EventOwner();
  final Future<int> firstValue = eventOwner.values.first;
  eventOwner.publish(7);
  final int value = await firstValue;
  await eventOwner.dispose();
  if (value != 7) throw StateError('unexpected_event');
}
