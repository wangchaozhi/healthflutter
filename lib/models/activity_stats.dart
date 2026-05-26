class ActivityStats {
  final int totalAuto;
  final int totalManual;
  final int yearAuto;
  final int yearManual;
  final int monthAuto;
  final int monthManual;
  final String earliestDate;
  final int lastTwoInterval;
  final int lastTwoAutoInterval;
  final int lastTwoManualInterval;

  const ActivityStats({
    required this.totalAuto,
    required this.totalManual,
    required this.yearAuto,
    required this.yearManual,
    required this.monthAuto,
    required this.monthManual,
    required this.earliestDate,
    required this.lastTwoInterval,
    required this.lastTwoAutoInterval,
    required this.lastTwoManualInterval,
  });

  factory ActivityStats.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v, [int fallback = 0]) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    return ActivityStats(
      totalAuto: asInt(json['total_auto']),
      totalManual: asInt(json['total_manual']),
      yearAuto: asInt(json['year_auto']),
      yearManual: asInt(json['year_manual']),
      monthAuto: asInt(json['month_auto']),
      monthManual: asInt(json['month_manual']),
      earliestDate: json['earliest_date'] as String? ?? '',
      lastTwoInterval: asInt(json['last_two_interval'], -1),
      lastTwoAutoInterval: asInt(json['last_two_auto_interval'], -1),
      lastTwoManualInterval: asInt(json['last_two_manual_interval'], -1),
    );
  }
}
