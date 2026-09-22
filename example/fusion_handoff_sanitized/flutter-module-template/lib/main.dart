import 'package:flutter/material.dart';
import 'package:fusion/fusion.dart';

import 'event_runtime.dart';
import 'route_map.dart';

void main() {
  // Register channel handlers before any asynchronous initialization. Native may
  // create a container immediately after the Dart entrypoint starts.
  WidgetsFlutterBinding.ensureInitialized();
  Fusion.instance.install();
  runApp(const HybridModuleApp());
}

class HybridModuleApp extends StatefulWidget {
  const HybridModuleApp({super.key});

  @override
  State<HybridModuleApp> createState() => _HybridModuleAppState();
}

class _HybridModuleAppState extends State<HybridModuleApp> {
  final GenericEventRuntime _events = GenericEventRuntime();

  @override
  void initState() {
    super.initState();
    _events.start();
  }

  @override
  void dispose() {
    _events.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FusionApp(
      title: 'Hybrid Module',
      debugShowCheckedModeBanner: false,
      routeMap: buildRouteMap(),
    );
  }
}
