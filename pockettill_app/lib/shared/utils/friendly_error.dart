/// Turns a raw exception/error into a short, plain-language message safe to
/// show a cashier - never a Postgres/Dart exception string. Detects the
/// common "you're offline" case first since that's genuinely useful to call
/// out; [fallback] covers everything else, so each call site can phrase the
/// generic case for its own action ("Could not complete the sale...").
String friendlyErrorMessage(
  Object error, {
  String fallback = 'Something went wrong. Please try again or contact support.',
}) {
  final message = error.toString();
  if (message.contains('SocketException') ||
      message.contains('TimeoutException') ||
      message.contains('Failed host lookup') ||
      message.contains('ClientException') ||
      message.contains('Network')) {
    return 'Connection failed. Please check your internet and try again.';
  }
  return fallback;
}
