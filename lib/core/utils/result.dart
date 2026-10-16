/// Lightweight outcome object returned by local state mutations.
/// Mirrors the shape a real repository would return later.
class Result {
  const Result._(this.ok, this.message);

  final bool ok;
  final String message;

  factory Result.success([String message = 'Saved']) => Result._(true, message);

  factory Result.failure(String message) => Result._(false, message);
}
