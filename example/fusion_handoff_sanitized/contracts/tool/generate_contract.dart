import 'dart:convert';
import 'dart:io';

import 'compatibility.dart';

const _sourceName = 'route_contract.v1.json';

void main(List<String> args) {
  final root = File.fromUri(Platform.script).parent.parent;
  final checkOnly = args.contains('--check');
  final previousIndex = args.indexOf('--previous');
  final registry = _read(File('${root.path}/$_sourceName'));
  RouteContractRegistryValidator.validate(registry);

  if (previousIndex >= 0) {
    if (previousIndex + 1 >= args.length) {
      stderr.writeln('--previous requires a JSON file path.');
      exitCode = 64;
      return;
    }
    final previousPath = args[previousIndex + 1];
    final previous = _read(File(previousPath).isAbsolute
        ? File(previousPath)
        : File('${root.path}/$previousPath'));
    RouteContractRegistryValidator.validate(previous);
    RouteContractCompatibility.requireCompatible(previous, registry);
  }

  final outputs = <String, String>{
    'generated/route_contract.g.dart': _dart(registry),
    'generated/RouteContract.kt': _kotlin(registry),
    'generated/RouteContract.swift': _swift(registry),
    'fixtures/contract_fixtures.json': _fixtures(registry),
  };

  var current = true;
  for (final entry in outputs.entries) {
    final target = File('${root.path}/${entry.key}');
    if (checkOnly) {
      if (!target.existsSync() || target.readAsStringSync() != entry.value) {
        stderr.writeln('Out-of-date generated contract: ${entry.key}');
        current = false;
      }
      continue;
    }
    target.parent.createSync(recursive: true);
    target.writeAsStringSync(entry.value);
    stdout.writeln('Generated ${entry.key}');
  }
  if (!current) exitCode = 1;
}

Map<String, dynamic> _read(File file) {
  if (!file.existsSync()) throw StateError('Missing contract: ${file.path}');
  return Map<String, dynamic>.from(jsonDecode(file.readAsStringSync()) as Map);
}

List<Map<String, dynamic>> _entries(Map<String, dynamic> source, String key) =>
    (source[key] as List<Object?>)
        .map((item) => Map<String, dynamic>.from(item! as Map))
        .toList(growable: false);

String _dart(Map<String, dynamic> source) {
  final routes = _entries(source, 'routes');
  final events = _entries(source, 'events');
  final version = source['contractVersion'];
  final major = ContractVersion.parse(version as String).major;
  final out = StringBuffer()
    ..writeln('// GENERATED CODE. Source: $_sourceName')
    ..writeln("const fusionContractVersion = '$version';")
    ..writeln('const fusionContractMajorVersion = $major;')
    ..writeln()
    ..writeln('abstract final class RouteNames {');
  for (final route in routes) {
    out.writeln("  static const ${route['symbol']} = '${route['name']}';");
  }
  out
    ..writeln('}')
    ..writeln()
    ..writeln('abstract final class EventNames {');
  for (final event in events) {
    out.writeln("  static const ${event['symbol']} = '${event['name']}';");
  }
  out
    ..writeln('}')
    ..writeln()
    ..writeln('const routeDescriptors = <Map<String, Object?>>[');
  for (final route in routes) {
    final result = Map<String, dynamic>.from(route['result'] as Map);
    out.writeln('  ${jsonEncode({
      'name': route['name'],
      'direction': route['direction'],
      'resultMode': result['mode'],
    })},');
  }
  out
    ..writeln('];')
    ..writeln()
    ..writeln('const eventDescriptors = <Map<String, Object?>>[');
  for (final event in events) {
    out.writeln('  ${jsonEncode({
      'name': event['name'],
      'direction': event['direction'],
    })},');
  }
  out.writeln('];');
  return out.toString();
}

String _kotlin(Map<String, dynamic> source) {
  final routes = _entries(source, 'routes');
  final events = _entries(source, 'events');
  final version = source['contractVersion'] as String;
  final major = ContractVersion.parse(version).major;
  final out = StringBuffer()
    ..writeln('// GENERATED CODE. Source: $_sourceName')
    ..writeln('package com.example.hybrid.contract')
    ..writeln()
    ..writeln('object FusionContract {')
    ..writeln('    const val VERSION = "$version"')
    ..writeln('    const val MAJOR_VERSION = $major')
    ..writeln('    object Routes {');
  for (final route in routes) {
    out.writeln('        const val ${_snake(route['symbol'] as String)} = "${route['name']}"');
  }
  out
    ..writeln('    }')
    ..writeln('    object Events {');
  for (final event in events) {
    out.writeln('        const val ${_snake(event['symbol'] as String)} = "${event['name']}"');
  }
  out
    ..writeln('    }')
    ..writeln('}');
  return out.toString();
}

String _swift(Map<String, dynamic> source) {
  final routes = _entries(source, 'routes');
  final events = _entries(source, 'events');
  final version = source['contractVersion'] as String;
  final major = ContractVersion.parse(version).major;
  final out = StringBuffer()
    ..writeln('// GENERATED CODE. Source: $_sourceName')
    ..writeln('import Foundation')
    ..writeln()
    ..writeln('public enum FusionContract {')
    ..writeln('    public static let version = "$version"')
    ..writeln('    public static let majorVersion = $major')
    ..writeln('    public enum Routes {');
  for (final route in routes) {
    out.writeln('        public static let ${route['symbol']} = "${route['name']}"');
  }
  out
    ..writeln('    }')
    ..writeln('    public enum Events {');
  for (final event in events) {
    out.writeln('        public static let ${event['symbol']} = "${event['name']}"');
  }
  out
    ..writeln('    }')
    ..writeln('}');
  return out.toString();
}

String _fixtures(Map<String, dynamic> source) {
  var request = 0;
  final routes = <Map<String, Object?>>[];
  for (final route in _entries(source, 'routes')) {
    final result = Map<String, dynamic>.from(route['result'] as Map);
    final mode = result['mode'] as String;
    final envelope = <String, Object?>{
      'contractVersion': source['contractVersion'],
      'routeName': route['name'],
      'args': _sample(Map<String, dynamic>.from(route['arguments'] as Map)),
    };
    if (mode != 'none') envelope['requestId'] = 'request-${++request}';
    routes.add({
      'symbol': route['symbol'],
      'direction': route['direction'],
      'resultMode': mode,
      'envelope': envelope,
    });
  }
  final events = [
    for (final event in _entries(source, 'events'))
      {
        'symbol': event['symbol'],
        'direction': event['direction'],
        'eventName': event['name'],
        'payload': _sample(Map<String, dynamic>.from(event['payload'] as Map)),
      }
  ];
  return '${const JsonEncoder.withIndent('  ').convert({
    'registryFormatVersion': source['registryFormatVersion'],
    'contractVersion': source['contractVersion'],
    'routeFixtures': routes,
    'eventFixtures': events,
  })}\n';
}

Object? _sample(Map<String, dynamic> schema) {
  switch (schema['type']) {
    case 'null':
      return null;
    case 'string':
      return 'example';
    case 'integer':
      return schema['minimum'] ?? 1;
    case 'number':
      return 1.0;
    case 'serializableValue':
      return {'value': 'example'};
    case 'object':
      final properties = Map<String, dynamic>.from(schema['properties'] as Map? ?? const {});
      final required = (schema['required'] as List<Object?>? ?? const []).cast<String>();
      return {
        for (final key in required)
          key: _sample(Map<String, dynamic>.from(properties[key] as Map)),
      };
    default:
      throw FormatException('Unsupported schema type: ${schema['type']}');
  }
}

String _snake(String value) => value
    .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]}_${m[2]}')
    .toUpperCase();
