/// Data Query Engine — typed, safe data queries for Experience runtime.
///
/// Supports filtering, sorting, searching, and pagination.
/// No raw SQL strings — all operations are schema-validated.
library;

import 'dart:math';

/// A typed filter operation.
enum FilterOperator {
  equals,
  notEquals,
  contains,
  startsWith,
  greaterThan,
  greaterOrEqual,
  lessThan,
  lessOrEqual,
  isTrue,
  isFalse,
  isNull,
  isNotNull,
  inList,
}

/// A single filter condition.
class FilterCondition {
  final String fieldId;
  final FilterOperator operator;
  final dynamic value;

  const FilterCondition({
    required this.fieldId,
    required this.operator,
    this.value,
  });

  /// Evaluate this condition against a record.
  bool evaluate(Map<String, dynamic> record) {
    final fieldValue = record[fieldId];

    switch (operator) {
      case FilterOperator.equals:
        return _compare(fieldValue, value) == 0;
      case FilterOperator.notEquals:
        return _compare(fieldValue, value) != 0;
      case FilterOperator.contains:
        if (fieldValue is String && value is String) {
          return fieldValue.toLowerCase().contains(value.toLowerCase());
        }
        return false;
      case FilterOperator.startsWith:
        if (fieldValue is String && value is String) {
          return fieldValue.toLowerCase().startsWith(value.toLowerCase());
        }
        return false;
      case FilterOperator.greaterThan:
        return _compare(fieldValue, value) > 0;
      case FilterOperator.greaterOrEqual:
        return _compare(fieldValue, value) >= 0;
      case FilterOperator.lessThan:
        return _compare(fieldValue, value) < 0;
      case FilterOperator.lessOrEqual:
        return _compare(fieldValue, value) <= 0;
      case FilterOperator.isTrue:
        return fieldValue == true;
      case FilterOperator.isFalse:
        return fieldValue == false;
      case FilterOperator.isNull:
        return fieldValue == null;
      case FilterOperator.isNotNull:
        return fieldValue != null;
      case FilterOperator.inList:
        if (value is List) {
          return value.any((v) => _compare(fieldValue, v) == 0);
        }
        return false;
    }
  }

  int _compare(dynamic a, dynamic b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    if (a is num && b is num) return a.compareTo(b);
    if (a is String && b is String) return a.compareTo(b);
    return a.toString().compareTo(b.toString());
  }
}

/// Sort direction.
enum SortDirection { ascending, descending }

/// A sort specification.
class SortSpec {
  final String fieldId;
  final SortDirection direction;

  const SortSpec({
    required this.fieldId,
    this.direction = SortDirection.ascending,
  });
}

/// A complete data query.
class DataQuery {
  final String entityId;
  final List<FilterCondition> filters;
  final List<SortSpec> sorts;
  final int? limit;
  final int? offset;
  final String? search;
  final List<String>? searchFields;

  const DataQuery({
    required this.entityId,
    this.filters = const [],
    this.sorts = const [],
    this.limit,
    this.offset,
    this.search,
    this.searchFields,
  });

  /// Maximum allowed result count (security budget).
  static const int maxResultLimit = 1000;

  /// Maximum allowed filters.
  static const int maxFilters = 20;

  /// Maximum allowed sort keys.
  static const int maxSorts = 5;

  /// Validate query constraints.
  List<String> validate() {
    final errors = <String>[];
    if (filters.length > maxFilters) {
      errors.add('Too many filters: ${filters.length} (max $maxFilters)');
    }
    if (sorts.length > maxSorts) {
      errors.add('Too many sort keys: ${sorts.length} (max $maxSorts)');
    }
    if (limit != null && limit! > maxResultLimit) {
      errors.add('Limit too high: $limit (max $maxResultLimit)');
    }
    if (limit != null && limit! < 0) {
      errors.add('Limit cannot be negative');
    }
    if (offset != null && offset! < 0) {
      errors.add('Offset cannot be negative');
    }
    return errors;
  }

  /// Execute this query against a list of records.
  List<Map<String, dynamic>> execute(List<Map<String, dynamic>> records) {
    var result = List<Map<String, dynamic>>.from(records);

    // Apply filters
    for (final filter in filters) {
      result = result.where((r) => filter.evaluate(r)).toList();
    }

    // Apply search
    if (search != null && search!.isNotEmpty) {
      final query = search!.toLowerCase();
      final fields = searchFields ?? _inferSearchFields(result);
      result = result.where((record) {
        return fields.any((field) {
          final value = record[field];
          if (value is String) {
            return value.toLowerCase().contains(query);
          }
          if (value != null) {
            return value.toString().toLowerCase().contains(query);
          }
          return false;
        });
      }).toList();
    }

    // Apply sorts
    if (sorts.isNotEmpty) {
      result.sort((a, b) {
        for (final sort in sorts) {
          final aVal = a[sort.fieldId];
          final bVal = b[sort.fieldId];
          int cmp;
          if (aVal == null && bVal == null) {
            cmp = 0;
          } else if (aVal == null) {
            cmp = -1;
          } else if (bVal == null) {
            cmp = 1;
          } else if (aVal is num && bVal is num) {
            cmp = aVal.compareTo(bVal);
          } else {
            cmp = aVal.toString().compareTo(bVal.toString());
          }
          if (cmp != 0) {
            return sort.direction == SortDirection.ascending ? cmp : -cmp;
          }
        }
        return 0;
      });
    }

    // Apply offset + limit
    final start = offset ?? 0;
    if (start > 0 && start >= result.length) return [];
    final end = limit != null
        ? min(start + limit!, result.length)
        : result.length;
    result = result.sublist(start, end);

    return result;
  }

  /// Infer search fields from record structure (string fields).
  List<String> _inferSearchFields(List<Map<String, dynamic>> records) {
    if (records.isEmpty) return [];
    final fields = <String>{};
    for (final field in records.first.keys) {
      final sample = records.first[field];
      if (sample is String) {
        fields.add(field);
      }
    }
    return fields.toList();
  }
}

/// Data Query Engine — executes queries against ExperienceDataRuntime.
class DataQueryEngine {
  /// Execute a query against in-memory records.
  List<Map<String, dynamic>> query(
    DataQuery dataQuery,
    List<Map<String, dynamic>> allRecords,
  ) {
    final errors = dataQuery.validate();
    if (errors.isNotEmpty) {
      throw DataQueryException('Invalid query: ${errors.join('; ')}');
    }
    return dataQuery.execute(allRecords);
  }

  /// Compute aggregate values from records.
  dynamic aggregate(
    String operation,
    List<Map<String, dynamic>> records,
    String? fieldId,
  ) {
    if (records.isEmpty) {
      switch (operation) {
        case 'count':
          return 0;
        case 'sum':
        case 'average':
        case 'min':
        case 'max':
          return null;
      }
    }

    switch (operation) {
      case 'count':
        return records.length;
      case 'sum':
        if (fieldId == null) return null;
        num sum = 0;
        for (final r in records) {
          final v = r[fieldId];
          if (v is num) sum += v;
        }
        return sum;
      case 'average':
        if (fieldId == null) return null;
        num sum = 0;
        int count = 0;
        for (final r in records) {
          final v = r[fieldId];
          if (v is num) {
            sum += v;
            count++;
          }
        }
        return count > 0 ? sum / count : null;
      case 'min':
        if (fieldId == null) return null;
        dynamic min;
        for (final r in records) {
          final v = r[fieldId];
          if (v != null && (min == null || _compareValues(v, min) < 0)) {
            min = v;
          }
        }
        return min;
      case 'max':
        if (fieldId == null) return null;
        dynamic max;
        for (final r in records) {
          final v = r[fieldId];
          if (v != null && (max == null || _compareValues(v, max) > 0)) {
            max = v;
          }
        }
        return max;
      default:
        return null;
    }
  }

  int _compareValues(dynamic a, dynamic b) {
    if (a is num && b is num) return a.compareTo(b);
    return a.toString().compareTo(b.toString());
  }
}

/// Exception for invalid data queries.
class DataQueryException implements Exception {
  final String message;
  const DataQueryException(this.message);

  @override
  String toString() => 'DataQueryException: $message';
}
