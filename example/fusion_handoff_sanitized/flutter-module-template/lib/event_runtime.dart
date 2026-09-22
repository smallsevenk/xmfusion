import 'package:fusion/fusion.dart';

class GenericEventRuntime {
  static const entityChanged = 'entityChanged';

  void start() {
    FusionEventManager.instance.register(entityChanged, _onEntityChanged);
  }

  void dispose() {
    FusionEventManager.instance.unregister(entityChanged, _onEntityChanged);
  }

  void _onEntityChanged(Map<String, dynamic>? payload) {
    if (payload == null ||
        payload['entityId'] is! String ||
        payload['revision'] is! int ||
        payload['changedAt'] is! int) {
      return;
    }
    // Forward the validated generic notification to application state here.
  }
}
