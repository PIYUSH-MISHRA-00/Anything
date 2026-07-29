/// Experience Query Controller — manages query state for data-driven views.
///
/// Binds DataQuery to ExperienceDataRuntime with reactivity.
/// No domain-specific logic.
library;

import 'dart:async';
import 'data_query.dart';
import 'data_runtime.dart';

/// Loading state for query results.
enum QueryStatus { idle, loading, loaded, error }

/// A reactive query controller for a single entity.
class ExperienceQueryController {
  final String entityId;
  final ExperienceDataRuntime _dataRuntime;
  final DataQueryEngine _queryEngine;

  DataQuery _currentQuery;
  QueryStatus _status = QueryStatus.idle;
  List<Map<String, dynamic>> _results = [];
  String? _errorMessage;
  String _searchTerm = '';
  List<FilterCondition> _filters = [];
  List<SortSpec> _sorts = [];

  final StreamController<QueryState> _stateController =
      StreamController<QueryState>.broadcast();

  Stream<QueryState> get stateStream => _stateController.stream;
  QueryStatus get status => _status;
  List<Map<String, dynamic>> get results => _results;
  String? get errorMessage => _errorMessage;
  DataQuery get currentQuery => _currentQuery;
  String get searchTerm => _searchTerm;
  List<FilterCondition> get filters => _filters;
  List<SortSpec> get sorts => _sorts;

  ExperienceQueryController({
    required this.entityId,
    required ExperienceDataRuntime dataRuntime,
    DataQuery? initialQuery,
  }) : _dataRuntime = dataRuntime,
       _queryEngine = DataQueryEngine(),
       _currentQuery = initialQuery ?? DataQuery(entityId: entityId);

  /// Refresh query results.
  Future<void> refresh() async {
    _status = QueryStatus.loading;
    _notifyState();

    try {
      final allRecords = await _dataRuntime.query(entityId);
      _results = _queryEngine.query(_currentQuery, allRecords);
      _status = QueryStatus.loaded;
      _errorMessage = null;
    } catch (e) {
      _status = QueryStatus.error;
      _errorMessage = 'Failed to load data';
      _results = [];
    }

    _notifyState();
  }

  /// Set search term and refresh.
  Future<void> setSearch(String term) async {
    _searchTerm = term;
    _currentQuery = DataQuery(
      entityId: entityId,
      filters: _filters,
      sorts: _sorts,
      search: term.isEmpty ? null : term,
      limit: _currentQuery.limit,
      offset: _currentQuery.offset,
    );
    await refresh();
  }

  /// Add a filter and refresh.
  Future<void> addFilter(FilterCondition filter) async {
    _filters.add(filter);
    _rebuildQuery();
    await refresh();
  }

  /// Remove all filters for a field and refresh.
  Future<void> removeFilter(String fieldId) async {
    _filters.removeWhere((f) => f.fieldId == fieldId);
    _rebuildQuery();
    await refresh();
  }

  /// Clear all filters and refresh.
  Future<void> clearFilters() async {
    _filters.clear();
    _rebuildQuery();
    await refresh();
  }

  /// Set sort order and refresh.
  Future<void> setSort(SortSpec sort) async {
    _sorts = [sort];
    _rebuildQuery();
    await refresh();
  }

  /// Clear sorts and refresh.
  Future<void> clearSorts() async {
    _sorts.clear();
    _rebuildQuery();
    await refresh();
  }

  /// Set pagination limit.
  Future<void> setLimit(int? limit) async {
    _currentQuery = DataQuery(
      entityId: entityId,
      filters: _filters,
      sorts: _sorts,
      search: _searchTerm.isEmpty ? null : _searchTerm,
      limit: limit,
      offset: _currentQuery.offset,
    );
    await refresh();
  }

  /// Set page offset.
  Future<void> setOffset(int? offset) async {
    _currentQuery = DataQuery(
      entityId: entityId,
      filters: _filters,
      sorts: _sorts,
      search: _searchTerm.isEmpty ? null : _searchTerm,
      limit: _currentQuery.limit,
      offset: offset,
    );
    await refresh();
  }

  /// Replace all filters and refresh.
  Future<void> setFilters(List<FilterCondition> filters) async {
    _filters = List.from(filters);
    _rebuildQuery();
    await refresh();
  }

  /// Replace all sorts and refresh.
  Future<void> setSorts(List<SortSpec> sorts) async {
    _sorts = List.from(sorts);
    _rebuildQuery();
    await refresh();
  }

  /// Compute aggregate value from current results.
  dynamic aggregate(String operation, {String? fieldId}) {
    return _queryEngine.aggregate(operation, _results, fieldId);
  }

  /// Count of current results.
  int get count => _results.length;

  void _rebuildQuery() {
    _currentQuery = DataQuery(
      entityId: entityId,
      filters: _filters,
      sorts: _sorts,
      search: _searchTerm.isEmpty ? null : _searchTerm,
      limit: _currentQuery.limit,
      offset: _currentQuery.offset,
    );
  }

  void _notifyState() {
    if (!_stateController.isClosed) {
      _stateController.add(
        QueryState(
          status: _status,
          results: _results,
          errorMessage: _errorMessage,
          count: _results.length,
        ),
      );
    }
  }

  /// Dispose resources.
  void dispose() {
    _stateController.close();
  }
}

/// Query state snapshot.
class QueryState {
  final QueryStatus status;
  final List<Map<String, dynamic>> results;
  final String? errorMessage;
  final int count;

  const QueryState({
    required this.status,
    required this.results,
    this.errorMessage,
    required this.count,
  });
}
