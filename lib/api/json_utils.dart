import '../core/format.dart';

String? asString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is num || value is bool) return value.toString();
  return null;
}

int? asInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.toInt();
  return null;
}

double? asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool asBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase();
    return lower == 'true' || lower == '1' || lower == 'yes';
  }
  return fallback;
}

DateTime? asDate(dynamic value) => parseServerDate(value);

List<Map<String, dynamic>> asMapList(dynamic value, [String? key]) {
  dynamic raw = value;
  if (key != null && value is Map) raw = value[key];
  if (raw is List) {
    return raw.whereType<Map>().map((item) => item.cast<String, dynamic>()).toList();
  }
  return const [];
}

List<String> asStringList(dynamic value) {
  if (value is List) return value.whereType<String>().where((item) => item.isNotEmpty).toList();
  return const [];
}

Map<String, dynamic> asMap(dynamic value) {
  if (value is Map) return value.cast<String, dynamic>();
  return const {};
}

String? firstString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = asString(json[key]);
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

int? firstInt(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = asInt(json[key]);
    if (value != null) return value;
  }
  return null;
}

DateTime? firstDate(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = asDate(json[key]);
    if (value != null) return value;
  }
  return null;
}
