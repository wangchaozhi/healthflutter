import 'package:flutter/foundation.dart';

import '../models/activity.dart';
import '../models/activity_stats.dart';
import 'activity_repository.dart';

class ActivityStore extends ChangeNotifier {
  ActivityStore._();
  static final ActivityStore instance = ActivityStore._();

  final ActivityRepository _repo = ActivityRepository.instance;

  List<Activity> _activities = const [];
  ActivityStats? _stats;
  bool _isLoading = false;
  String? _listError;
  String? _statsError;
  int _refreshGeneration = 0;

  List<Activity> get activities => _activities;
  ActivityStats? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get lastError => _listError ?? _statsError;

  Future<void> refresh() async {
    final generation = ++_refreshGeneration;
    _isLoading = true;
    notifyListeners();
    await Future.wait([_loadList(generation), _loadStats(generation)]);
    if (generation == _refreshGeneration) {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> create({
    required String recordDate,
    required String recordTime,
    required int duration,
    String remark = '',
    ActivityTag tag = ActivityTag.manual,
  }) async {
    final result = await _repo.create(
      recordDate: recordDate,
      recordTime: recordTime,
      duration: duration,
      remark: remark,
      tag: tag,
    );
    if (result.isOk) {
      await refresh();
      return null;
    }
    return result.message.isEmpty ? '记录失败' : result.message;
  }

  Future<String?> delete(int id) async {
    final result = await _repo.delete(id);
    if (result.isOk) {
      await refresh();
      return null;
    }
    return result.message.isEmpty ? '删除失败' : result.message;
  }

  Future<void> _loadList(int generation) async {
    final result = await _repo.list();
    if (generation != _refreshGeneration) return;
    if (result.isOk) {
      _activities = result.data ?? const [];
      _listError = null;
    } else {
      _listError = result.message;
    }
  }

  Future<void> _loadStats(int generation) async {
    final result = await _repo.stats();
    if (generation != _refreshGeneration) return;
    if (result.isOk) {
      _stats = result.data;
      _statsError = null;
    } else {
      _statsError = result.message;
    }
  }

  void clear() {
    _refreshGeneration++;
    _activities = const [];
    _stats = null;
    _isLoading = false;
    _listError = null;
    _statsError = null;
    notifyListeners();
  }
}
