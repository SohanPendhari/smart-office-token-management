int asInt(dynamic v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) ?? 0 : 0);
double asDouble(dynamic v) => v is num ? v.toDouble() : 0;
String asStr(dynamic v) => v?.toString() ?? '';
bool asBool(dynamic v) => v is bool ? v : false;
DateTime? asDate(dynamic v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
List<Map<String, dynamic>> asList(dynamic v) =>
    v is List ? v.whereType<Map<String, dynamic>>().toList() : <Map<String, dynamic>>[];
List<String> asStrList(dynamic v) => v is List ? v.map((e) => e.toString()).toList() : <String>[];
