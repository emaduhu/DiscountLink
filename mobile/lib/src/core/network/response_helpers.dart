part of '../../../main.dart';

List<dynamic> responseItems(dynamic value) {
  if (value is List) return value;
  if (value is Map && value['data'] is List) return value['data'] as List;
  return [];
}

int? responseTotal(dynamic value) {
  if (value is Map) return int.tryParse('${value['total'] ?? ''}');
  if (value is List) return value.length;
  return null;
}

bool responseHasMore(dynamic value) {
  if (value is! Map) return false;
  final current = int.tryParse('${value['current_page'] ?? ''}');
  final last = int.tryParse('${value['last_page'] ?? ''}');
  if (current == null || last == null) return false;
  return current < last;
}
