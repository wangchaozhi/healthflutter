enum ActivityTag {
  auto,
  manual;

  String get wire => this == ActivityTag.auto ? 'auto' : 'manual';

  static ActivityTag fromWire(String? raw) {
    return raw == 'auto' ? ActivityTag.auto : ActivityTag.manual;
  }
}

class Activity {
  final int id;
  final int userId;
  final String recordDate;
  final String recordTime;
  final String weekDay;
  final int duration;
  final String remark;
  final ActivityTag tag;
  final String createdAt;

  const Activity({
    required this.id,
    required this.userId,
    required this.recordDate,
    required this.recordTime,
    required this.weekDay,
    required this.duration,
    required this.remark,
    required this.tag,
    required this.createdAt,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as int? ?? 0,
      userId: json['user_id'] as int? ?? 0,
      recordDate: json['record_date'] as String? ?? '',
      recordTime: json['record_time'] as String? ?? '',
      weekDay: json['week_day'] as String? ?? '',
      duration: json['duration'] as int? ?? 0,
      remark: json['remark'] as String? ?? '',
      tag: ActivityTag.fromWire(json['tag'] as String?),
      createdAt: json['created_at'] as String? ?? '',
    );
  }

  bool get isAuto => tag == ActivityTag.auto;
}
