class ApiResult<T> {
  final bool success;
  final String message;
  final T? data;

  const ApiResult({
    required this.success,
    this.message = '',
    this.data,
  });

  const ApiResult.ok(T value, [this.message = ''])
      : success = true,
        data = value;

  const ApiResult.fail(this.message)
      : success = false,
        data = null;

  bool get isOk => success;
  bool get isError => !success;
}
