/// Error types and Result type for Anything v2.
///
/// Provides a type-safe way to handle errors without exceptions.
library;

/// A result that is either success ([Ok]) or failure ([Err]).
sealed class Result<T> {
  const Result();

  /// Whether this result is a success.
  bool get isOk => this is Ok<T>;

  /// Whether this result is a failure.
  bool get isErr => this is Err<T>;

  /// Unwrap the value, throwing if this is an [Err].
  T get unwrap {
    if (this is Ok<T>) {
      return (this as Ok<T>).value;
    }
    final err = this as Err;
    throw err.error;
  }

  /// Unwrap the value, returning [defaultValue] if this is an [Err].
  T unwrapOr(T defaultValue) {
    if (this is Ok<T>) {
      return (this as Ok<T>).value;
    }
    return defaultValue;
  }

  /// Map the success value.
  Result<R> map<R>(R Function(T value) transform) {
    if (this is Ok<T>) {
      return Ok(transform((this as Ok<T>).value));
    }
    return Err((this as Err).error);
  }

  /// FlatMap the success value.
  Result<R> flatMap<R>(Result<R> Function(T value) transform) {
    if (this is Ok<T>) {
      return transform((this as Ok<T>).value);
    }
    return Err((this as Err).error);
  }
}

/// A successful result.
class Ok<T> extends Result<T> {
  final T value;

  const Ok(this.value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Ok<T> && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// A failed result.
class Err<T> extends Result<T> {
  final AnythingError error;

  const Err(this.error);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Err<T> && error == other.error;

  @override
  int get hashCode => error.hashCode;
}

/// Base error type for Anything.
///
/// All domain errors extend this class for type-safe error handling.
sealed class AnythingError {
  final String message;
  final Object? cause;

  const AnythingError({required this.message, this.cause});
}

/// Intent analysis failed.
class IntentError extends AnythingError {
  final IntentErrorType type;

  const IntentError({
    required super.message,
    this.type = IntentErrorType.unknown,
    super.cause,
  });
}

enum IntentErrorType { noInput, analysisFailed, invalidFormat, unknown }

/// Execution plan failed.
class ExecutionError extends AnythingError {
  final String? planId;
  final String? stepId;

  const ExecutionError({
    required super.message,
    this.planId,
    this.stepId,
    super.cause,
  });
}

/// Model provider error.
class ProviderError extends AnythingError {
  final String providerId;
  final ProviderErrorType type;

  const ProviderError({
    required super.message,
    required this.providerId,
    this.type = ProviderErrorType.unknown,
    super.cause,
  });
}

enum ProviderErrorType {
  notConfigured,
  invalidApiKey,
  rateLimited,
  modelNotFound,
  timeout,
  networkError,
  unknown,
}

/// Storage error.
class StorageError extends AnythingError {
  final StorageErrorType type;

  const StorageError({
    required super.message,
    this.type = StorageErrorType.unknown,
    super.cause,
  });
}

enum StorageErrorType { notFound, corrupted, permissionDenied, unknown }

/// Protection/encryption error.
class ProtectionError extends AnythingError {
  const ProtectionError({required super.message, super.cause});
}

/// Capability execution error.
class CapabilityError extends AnythingError {
  final String capabilityId;

  const CapabilityError({
    required super.message,
    required this.capabilityId,
    super.cause,
  });
}
