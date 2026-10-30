import 'package:intl/intl.dart';

String formatBytes(int? bytes) {
  if (bytes == null || bytes < 0) return '—';
  if (bytes < 1024) return '$bytes B';
  const units = ['KB', 'MB', 'GB', 'TB', 'PB'];
  var value = bytes.toDouble();
  var index = -1;
  do {
    value /= 1024;
    index++;
  } while (value >= 1024 && index < units.length - 1);
  final decimals = value >= 100 ? 0 : (value >= 10 ? 1 : 2);
  return '${value.toStringAsFixed(decimals)} ${units[index]}';
}

String formatSpeed(double bytesPerSecond) {
  if (bytesPerSecond <= 0) return '';
  return '${formatBytes(bytesPerSecond.round())}/s';
}

String formatDateTime(DateTime? value, {bool withTime = true}) {
  if (value == null) return '—';
  final local = value.toLocal();
  final pattern = withTime ? 'yyyy-MM-dd HH:mm' : 'yyyy-MM-dd';
  return DateFormat(pattern).format(local);
}

DateTime? parseServerDate(dynamic value) {
  if (value == null) return null;
  if (value is num) {
    if (value <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch((value * 1000).round());
  }
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final numeric = double.tryParse(trimmed);
    if (numeric != null) {
      return DateTime.fromMillisecondsSinceEpoch((numeric * 1000).round());
    }
    return DateTime.tryParse(trimmed);
  }
  return null;
}

String normalizeRepoPath(String? value) {
  if (value == null || value.trim().isEmpty) return '/';
  var path = value.trim();
  if (!path.startsWith('/')) path = '/$path';
  final segments = <String>[];
  for (final segment in path.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (segments.isNotEmpty) segments.removeLast();
      continue;
    }
    segments.add(segment);
  }
  if (segments.isEmpty) return '/';
  return '/${segments.join('/')}';
}

String joinRepoPath(String parent, String name) {
  final base = normalizeRepoPath(parent);
  return base == '/' ? '/$name' : '$base/$name';
}

String parentRepoPath(String path) {
  final normalized = normalizeRepoPath(path);
  if (normalized == '/') return '/';
  final index = normalized.lastIndexOf('/');
  if (index <= 0) return '/';
  return normalized.substring(0, index);
}

String baseName(String path) {
  final normalized = normalizeRepoPath(path);
  if (normalized == '/') return '/';
  return normalized.substring(normalized.lastIndexOf('/') + 1);
}

/// Encodes each path segment for use in a URL while keeping the separators.
String encodeRepoPath(String path) {
  return path
      .split('/')
      .map((segment) => Uri.encodeComponent(segment))
      .join('/');
}

String sanitizeFileName(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[/\\\x00-\x1f]'), '_')
      .replaceAll(RegExp(r'^\.+$'), '_');
  return cleaned.isEmpty ? 'download' : cleaned;
}

int compareNatural(String a, String b) {
  final left = _chunks(a);
  final right = _chunks(b);
  final length = left.length < right.length ? left.length : right.length;
  for (var i = 0; i < length; i++) {
    final l = left[i];
    final r = right[i];
    int result;
    if (l is int && r is int) {
      result = l.compareTo(r);
    } else if (l is int) {
      result = -1;
    } else if (r is int) {
      result = 1;
    } else {
      result = (l as String).compareTo(r as String);
    }
    if (result != 0) return result;
  }
  return left.length.compareTo(right.length);
}

List<Object> _chunks(String value) {
  final result = <Object>[];
  final buffer = StringBuffer();
  bool? digit;
  for (final rune in value.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final isDigit = RegExp(r'[0-9]').hasMatch(char);
    if (digit == null || digit == isDigit) {
      buffer.write(char);
      digit = isDigit;
    } else {
      result.add(digit ? int.parse(buffer.toString()) : buffer.toString());
      buffer
        ..clear()
        ..write(char);
      digit = isDigit;
    }
  }
  if (buffer.isNotEmpty) {
    result.add(digit == true ? int.parse(buffer.toString()) : buffer.toString());
  }
  return result;
}

String greetingForHour(int hour) => hour < 12 ? '上午好' : (hour < 18 ? '下午好' : '晚上好');

String formatRelative(DateTime? value, {bool zh = true}) {
  if (value == null) return '—';
  final now = DateTime.now();
  final difference = now.difference(value.toLocal());
  if (difference.isNegative) return formatDateTime(value);
  if (difference.inSeconds < 60) return zh ? '几秒前' : 'seconds ago';
  if (difference.inMinutes < 60) return zh ? '${difference.inMinutes} 分钟前' : '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return zh ? '${difference.inHours} 小时前' : '${difference.inHours} h ago';
  if (difference.inDays < 30) return zh ? '${difference.inDays} 天前' : '${difference.inDays} d ago';
  return formatDateTime(value, withTime: false);
}
