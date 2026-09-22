import 'package:flutter/material.dart';
import 'package:fusion/fusion.dart';

Map<String, FusionPageFactory> buildRouteMap() {
  final routes = <String, FusionPageFactory>{};
  _mergeRoutes(routes, featureRoutes());
  return Map.unmodifiable(routes);
}

void _mergeRoutes(
  Map<String, FusionPageFactory> target,
  Map<String, FusionPageFactory> incoming,
) {
  final duplicates = target.keys.toSet().intersection(incoming.keys.toSet());
  if (duplicates.isNotEmpty) {
    throw StateError('Duplicate Fusion routes: ${duplicates.join(', ')}');
  }
  target.addAll(incoming);
}

Map<String, FusionPageFactory> featureRoutes() => {
      '/feature/home': (args) => FeatureHomePage(
            entryId: args?['entryId'] as String? ?? 'missing-entry',
            title: args?['title'] as String?,
          ),
    };

class FeatureHomePage extends StatelessWidget {
  const FeatureHomePage({required this.entryId, this.title, super.key});

  final String entryId;
  final String? title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title ?? 'Feature')),
      body: Center(child: Text('Entry: $entryId')),
    );
  }
}
