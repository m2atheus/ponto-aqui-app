class AppFailure implements Exception {
  const AppFailure(this.message, {this.code = 'FALHA_LOCAL', this.status});
  final String message;
  final String code;
  final int? status;
  bool get authorizationDenied => status == 401 || status == 403;
  bool get retryable =>
      status == null || status == 408 || status == 429 || status! >= 500;
  @override
  String toString() => message;
}
