sealed class Result<T> {
  const Result();

  factory Result.success(T data) = Success<T>;
  factory Result.failure(String message, [Object? error]) = Failure<T>;

  R when<R>({
    required R Function(T data) success,
    required R Function(String message, Object? error) failure,
  });

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
}

final class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(String message, Object? error) failure,
  }) =>
      success(data);
}

final class Failure<T> extends Result<T> {
  const Failure(this.message, [this.error]);
  final String message;
  final Object? error;

  @override
  R when<R>({
    required R Function(T data) success,
    required R Function(String message, Object? error) failure,
  }) =>
      failure(message, error);
}
