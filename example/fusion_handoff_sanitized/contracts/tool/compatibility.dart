/// Compatibility rules for the versioned cross-platform route contract.
///
/// Optional fields may be added within a major version. Removing or renaming
/// routes/events/fields, adding required fields, or changing types/direction/
/// result mode requires a major version increment.
final class ContractVersion implements Comparable<ContractVersion> {
  const ContractVersion(this.major, this.minor, this.patch);

  factory ContractVersion.parse(String value) {
    final match = RegExp(
      r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$',
    ).firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid contract version: $value');
    }
    return ContractVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  final int major;
  final int minor;
  final int patch;

  @override
  int compareTo(ContractVersion other) {
    final majorOrder = major.compareTo(other.major);
    if (majorOrder != 0) return majorOrder;
    final minorOrder = minor.compareTo(other.minor);
    if (minorOrder != 0) return minorOrder;
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}

final class ContractCompatibilityReport {
  const ContractCompatibilityReport({
    required this.previousVersion,
    required this.currentVersion,
    required this.breakingChanges,
  });

  final ContractVersion previousVersion;
  final ContractVersion currentVersion;
  final List<String> breakingChanges;

  bool get hasBreakingChanges => breakingChanges.isNotEmpty;
  bool get hasRequiredMajorUpgrade =>
      hasBreakingChanges && currentVersion.major <= previousVersion.major;
  bool get isCompatible =>
      currentVersion.compareTo(previousVersion) >= 0 &&
      !hasRequiredMajorUpgrade;
}

final class RouteContractCompatibility {
  const RouteContractCompatibility._();

  static ContractCompatibilityReport compare(
    Map<String, dynamic> previous,
    Map<String, dynamic> current,
  ) {
    final previousVersion = ContractVersion.parse(
      previous['contractVersion'] as String,
    );
    final currentVersion = ContractVersion.parse(
      current['contractVersion'] as String,
    );
    final changes = <String>[];

    _compareEntries(
      kind: 'route',
      previousEntries: _maps(previous['routes']),
      currentEntries: _maps(current['routes']),
      changes: changes,
      compareEntry: (before, after, path) {
        _compareValue(before, after, 'direction', path, changes);
        final beforeResult = _map(before['result']);
        final afterResult = _map(after['result']);
        _compareValue(
          beforeResult,
          afterResult,
          'mode',
          '$path.result',
          changes,
        );
        _compareSchema(
          _map(before['arguments']),
          _map(after['arguments']),
          '$path.arguments',
          changes,
        );
        _compareSchema(
          _map(beforeResult['schema']),
          _map(afterResult['schema']),
          '$path.result.schema',
          changes,
        );
      },
    );
    _compareEntries(
      kind: 'event',
      previousEntries: _maps(previous['events']),
      currentEntries: _maps(current['events']),
      changes: changes,
      compareEntry: (before, after, path) {
        _compareValue(before, after, 'direction', path, changes);
        _compareSchema(
          _map(before['payload']),
          _map(after['payload']),
          '$path.payload',
          changes,
        );
      },
    );

    return ContractCompatibilityReport(
      previousVersion: previousVersion,
      currentVersion: currentVersion,
      breakingChanges: List.unmodifiable(changes),
    );
  }

  static void requireCompatible(
    Map<String, dynamic> previous,
    Map<String, dynamic> current,
  ) {
    final report = compare(previous, current);
    if (report.currentVersion.compareTo(report.previousVersion) < 0) {
      throw StateError(
        'Contract version moved backwards from '
        '${report.previousVersion} to ${report.currentVersion}.',
      );
    }
    if (report.hasRequiredMajorUpgrade) {
      throw StateError(
        'Breaking Route_Contract changes require a major version upgrade: '
        '${report.breakingChanges.join('; ')}',
      );
    }
  }

  static void _compareEntries({
    required String kind,
    required List<Map<String, dynamic>> previousEntries,
    required List<Map<String, dynamic>> currentEntries,
    required List<String> changes,
    required void Function(
      Map<String, dynamic> before,
      Map<String, dynamic> after,
      String path,
    )
    compareEntry,
  }) {
    final currentByName = {
      for (final entry in currentEntries) entry['name'] as String: entry,
    };
    for (final before in previousEntries) {
      final name = before['name'] as String;
      final after = currentByName[name];
      if (after == null) {
        changes.add('$kind $name was removed or renamed');
      } else {
        compareEntry(before, after, '$kind[$name]');
      }
    }
  }

  static void _compareSchema(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
    String path,
    List<String> changes,
  ) {
    _compareValue(before, after, 'type', path, changes);
    _compareValue(before, after, 'nullable', path, changes, absentValue: false);

    final beforeProperties = _map(before['properties']);
    final afterProperties = _map(after['properties']);
    final beforeRequired = _strings(before['required']).toSet();
    final afterRequired = _strings(after['required']).toSet();

    for (final requiredName in afterRequired.difference(beforeRequired)) {
      changes.add('$path.$requiredName became required');
    }
    for (final entry in beforeProperties.entries) {
      final afterProperty = afterProperties[entry.key];
      if (afterProperty == null) {
        changes.add('$path.${entry.key} was removed or renamed');
        continue;
      }
      _compareSchema(
        _map(entry.value),
        _map(afterProperty),
        '$path.${entry.key}',
        changes,
      );
    }
  }

  static void _compareValue(
    Map<String, dynamic> before,
    Map<String, dynamic> after,
    String key,
    String path,
    List<String> changes, {
    Object? absentValue,
  }) {
    final beforeValue = before.containsKey(key) ? before[key] : absentValue;
    final afterValue = after.containsKey(key) ? after[key] : absentValue;
    if (beforeValue != afterValue) {
      changes.add('$path.$key changed from $beforeValue to $afterValue');
    }
  }

  static Map<String, dynamic> _map(Object? value) {
    if (value == null) return const <String, dynamic>{};
    return Map<String, dynamic>.from(value as Map);
  }

  static List<Map<String, dynamic>> _maps(Object? value) =>
      (value as List<Object?>? ?? const <Object?>[])
          .map((entry) => _map(entry))
          .toList(growable: false);

  static List<String> _strings(Object? value) =>
      (value as List<Object?>? ?? const <Object?>[]).cast<String>().toList(
        growable: false,
      );
}

final class RouteContractRegistryValidator {
  const RouteContractRegistryValidator._();

  static void validate(Map<String, dynamic> registry) {
    if (registry['registryFormatVersion'] != 1) {
      throw const FormatException('Unsupported registryFormatVersion.');
    }
    ContractVersion.parse(registry['contractVersion'] as String);
    _validateUniqueEntries('route', registry['routes']);
    _validateUniqueEntries('event', registry['events']);

    for (final route in RouteContractCompatibility._maps(registry['routes'])) {
      final direction = route['direction'];
      if (direction != 'nativeToFlutter' && direction != 'flutterToNative') {
        throw FormatException('Invalid route direction for ${route['name']}.');
      }
      final result = RouteContractCompatibility._map(route['result']);
      if (result['mode'] != 'none' && result['mode'] != 'nullableValue') {
        throw FormatException('Invalid result mode for ${route['name']}.');
      }
      if (route['arguments'] is! Map || result['schema'] is! Map) {
        throw FormatException('Route ${route['name']} is missing schemas.');
      }
    }
    for (final event in RouteContractCompatibility._maps(registry['events'])) {
      if (event['direction'] != 'nativeToFlutter' || event['payload'] is! Map) {
        throw FormatException('Invalid event ${event['name']}.');
      }
    }
  }

  static void _validateUniqueEntries(String kind, Object? value) {
    final names = <String>{};
    final symbols = <String>{};
    for (final entry in RouteContractCompatibility._maps(value)) {
      final name = entry['name'];
      final symbol = entry['symbol'];
      if (name is! String || name.isEmpty || !names.add(name)) {
        throw FormatException('Duplicate or invalid $kind name: $name.');
      }
      if (symbol is! String ||
          !RegExp(r'^[A-Za-z][A-Za-z0-9]*$').hasMatch(symbol) ||
          !symbols.add(symbol)) {
        throw FormatException('Duplicate or invalid $kind symbol: $symbol.');
      }
    }
  }
}
