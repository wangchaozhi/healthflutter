class ActivityStats {
  final int totalAuto;
  final int totalManual;
  final int yearAuto;
  final int yearManual;
  final int monthAuto;
  final int monthManual;
  final double autoFrequencyPerDay;
  final double manualFrequencyPerDay;
  final double totalFrequencyPerDay;
  final double autoPeriodDays;
  final double manualPeriodDays;
  final double totalPeriodDays;
  final String earliestDate;
  final int lastTwoInterval;
  final int lastTwoAutoInterval;
  final int lastTwoManualInterval;
  final double? lastIntervalDays;
  final double? lastAutoIntervalDays;
  final double? lastManualIntervalDays;
  final double? lastToNowDays;

  const ActivityStats({
    required this.totalAuto,
    required this.totalManual,
    required this.yearAuto,
    required this.yearManual,
    required this.monthAuto,
    required this.monthManual,
    this.autoFrequencyPerDay = 0,
    this.manualFrequencyPerDay = 0,
    this.totalFrequencyPerDay = 0,
    this.autoPeriodDays = 0,
    this.manualPeriodDays = 0,
    this.totalPeriodDays = 0,
    required this.earliestDate,
    required this.lastTwoInterval,
    required this.lastTwoAutoInterval,
    required this.lastTwoManualInterval,
    this.lastIntervalDays,
    this.lastAutoIntervalDays,
    this.lastManualIntervalDays,
    this.lastToNowDays,
  });

  factory ActivityStats.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v, [int fallback = 0]) {
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    double asDouble(dynamic v, [double fallback = 0]) {
      if (v is double) return v;
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? fallback;
      return fallback;
    }

    double? asNullableDouble(dynamic v) {
      if (v == null) return null;
      return asDouble(v);
    }

    return ActivityStats(
      totalAuto: asInt(json['total_auto']),
      totalManual: asInt(json['total_manual']),
      yearAuto: asInt(json['year_auto']),
      yearManual: asInt(json['year_manual']),
      monthAuto: asInt(json['month_auto']),
      monthManual: asInt(json['month_manual']),
      autoFrequencyPerDay: asDouble(json['auto_frequency_per_day']),
      manualFrequencyPerDay: asDouble(json['manual_frequency_per_day']),
      totalFrequencyPerDay: asDouble(json['total_frequency_per_day']),
      autoPeriodDays: asDouble(json['auto_period_days']),
      manualPeriodDays: asDouble(json['manual_period_days']),
      totalPeriodDays: asDouble(json['total_period_days']),
      earliestDate: json['earliest_date'] as String? ?? '',
      lastTwoInterval: asInt(json['last_two_interval'], -1),
      lastTwoAutoInterval: asInt(json['last_two_auto_interval'], -1),
      lastTwoManualInterval: asInt(json['last_two_manual_interval'], -1),
      lastIntervalDays: asNullableDouble(json['last_interval_days']),
      lastAutoIntervalDays: asNullableDouble(json['last_auto_interval_days']),
      lastManualIntervalDays: asNullableDouble(json['last_manual_interval_days']),
      lastToNowDays: asNullableDouble(json['last_to_now_days']),
    );
  }
}
