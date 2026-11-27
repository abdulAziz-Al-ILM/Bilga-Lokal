import 'dart:developer' as developer;

/// Report an operation and exception type without logging private payloads.
void logFailure(String operation, Object error) {
  developer.log('$operation (${error.runtimeType})', name: 'bilga', level: 900);
}
