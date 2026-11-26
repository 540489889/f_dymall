Map<String, dynamic>? castMapOrNull(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}
