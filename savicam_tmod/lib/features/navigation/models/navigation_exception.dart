class NavigationException implements Exception {
  final String code;
  final String? message;

  NavigationException(this.code, [this.message]);

  @override
  String toString() => 'NavigationException: $code ${message != null ? '($message)' : ''}';
}
