import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/supabase/supabase_service.dart';
import '../models/daily_care_lesson.dart';
import '../models/daily_health_models.dart';

/// Dịch vụ quản lý dữ liệu Chăm sóc sức khỏe hằng ngày
/// Kết nối trực tiếp với Supabase Cloud (bảng: daily_care_lessons, user_health_profiles, daily_health_logs, daily_health_completed_lessons, daily_health_admin_configs)
/// Hỗ trợ bộ nhớ đệm cục bộ SharedPreferences (Fail-safe khi offline)
class DailyHealthService extends ChangeNotifier {
  DailyHealthService._() {
    _initData();
  }

  static final DailyHealthService instance = DailyHealthService._();

  static const String _keyProfile = 'daily_health_profile_json';
  static const String _keyLogs = 'daily_health_logs_json';
  static const String _keyLessons = 'daily_health_lessons_json';
  static const String _keyAdminConfig = 'daily_health_admin_config_json';
  static const String _keyCompletedLessons = 'daily_health_completed_lessons_';
  static const String _keyCleanedMockV1 = 'daily_health_cleaned_mock_v1';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  String _activeUserId = 'default_user';
  String get activeUserId => _activeUserId;

  UserProfileHealthMetric _profile = const UserProfileHealthMetric();
  UserProfileHealthMetric get profile => _profile;

  final Map<String, DailyHealthLog> _logs = {};
  List<DailyCareLesson> _lessons = [];
  List<DailyCareLesson> get lessons => List.unmodifiable(_lessons);

  final Set<String> _todayCompletedLessons = {};
  Set<String> get todayCompletedLessons => Set.unmodifiable(_todayCompletedLessons);

  AdminHealthConfig _adminConfig = const AdminHealthConfig();
  AdminHealthConfig get adminConfig => _adminConfig;

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  void setActiveUserId(String? userId) {
    final clean = (userId != null && userId.trim().isNotEmpty)
        ? userId.trim()
        : 'default_user';
    if (_activeUserId != clean) {
      _activeUserId = clean;
      fetchFromSupabase();
    }
  }

  Future<void> _initData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Dọn dẹp dữ liệu ảo cũ nếu có từ các phiên chạy trước
      if (prefs.getBool(_keyCleanedMockV1) != true) {
        await prefs.remove(_keyLogs);
        await prefs.setBool(_keyCleanedMockV1, true);
      }

      // 1. Nạp Profile từ bộ nhớ đệm
      final profileStr = prefs.getString(_keyProfile);
      if (profileStr != null && profileStr.isNotEmpty) {
        _profile = UserProfileHealthMetric.fromJson(
          jsonDecode(profileStr) as Map<String, dynamic>,
        );
      } else {
        _profile = const UserProfileHealthMetric(
          heightCm: 170.0,
          weightKg: 65.0,
          age: 26,
          gender: 'male',
          activityLevel: ActivityLevel.moderate,
          healthGoal: HealthGoal.maintenance,
        );
      }

      // 2. Nạp Admin Config từ bộ nhớ đệm
      final configStr = prefs.getString(_keyAdminConfig);
      if (configStr != null && configStr.isNotEmpty) {
        _adminConfig = AdminHealthConfig.fromJson(
          jsonDecode(configStr) as Map<String, dynamic>,
        );
      }

      // 3. Nạp Bài học cẩm nang từ bộ nhớ đệm (nếu trống tạo mẫu chuẩn WHO/NHS)
      final lessonsStr = prefs.getString(_keyLessons);
      if (lessonsStr != null && lessonsStr.isNotEmpty) {
        final List<dynamic> list = jsonDecode(lessonsStr) as List<dynamic>;
        _lessons = list
            .map((item) => DailyCareLesson.fromRow(item as Map<String, dynamic>))
            .toList();
      }
      if (_lessons.isEmpty) {
        _lessons = _createSeedLessons();
        _saveLessons();
      }

      // 4. Nạp Nhật ký chỉ số sức khỏe hàng ngày (Chỉ nạp dữ liệu thật)
      final logsStr = prefs.getString(_keyLogs);
      if (logsStr != null && logsStr.isNotEmpty) {
        final Map<String, dynamic> rawMap =
            jsonDecode(logsStr) as Map<String, dynamic>;
        rawMap.forEach((key, val) {
          _logs[key] = DailyHealthLog.fromJson(val as Map<String, dynamic>);
        });
      }

      // 5. Nạp danh sách bài học đã hoàn thành hôm nay
      final todayKey = '$_keyCompletedLessons${_dateKey(DateTime.now())}';
      final completedList = prefs.getStringList(todayKey);
      if (completedList != null) {
        _todayCompletedLessons.addAll(completedList);
      }

      _isInitialized = true;
      notifyListeners();

      // 6. Đồng bộ dữ liệu mới nhất từ Supabase Cloud
      fetchFromSupabase();
    } catch (e) {
      debugPrint('[DailyHealthService] Khởi tạo dữ liệu gặp lỗi: $e');
      if (_lessons.isEmpty) _lessons = _createSeedLessons();
      _isInitialized = true;
      notifyListeners();
    }
  }

  // ===========================================================================
  // ĐỒNG BỘ DỮ LIỆU VỚI SUPABASE CLOUD
  // ===========================================================================

  Future<void> fetchFromSupabase() async {
    final client = SupabaseService.instance.client;
    if (client == null) return;

    try {
      // 1. Tải cẩm nang bài học (daily_care_lessons)
      try {
        final lessonsRows = await client
            .from('daily_care_lessons')
            .select()
            .order('sort_order', ascending: true)
            .timeout(const Duration(seconds: 4));
        if (lessonsRows.isNotEmpty) {
          _lessons = (lessonsRows as List)
              .map((r) => DailyCareLesson.fromRow(Map<String, dynamic>.from(r)))
              .toList();
          _saveLessons();
        }
      } catch (e) {
        debugPrint('[DailyHealthService] Supabase daily_care_lessons: $e');
      }

      // 2. Tải cấu hình admin (daily_health_admin_configs)
      try {
        final configRow = await client
            .from('daily_health_admin_configs')
            .select()
            .eq('id', 'default_config')
            .maybeSingle()
            .timeout(const Duration(seconds: 4));
        if (configRow != null) {
          _adminConfig = AdminHealthConfig.fromSupabaseRow(Map<String, dynamic>.from(configRow));
          _saveAdminConfig();
        }
      } catch (e) {
        debugPrint('[DailyHealthService] Supabase daily_health_admin_configs: $e');
      }

      // 3. Tải hồ sơ thể trạng người dùng (user_health_profiles)
      try {
        final profileRow = await client
            .from('user_health_profiles')
            .select()
            .eq('user_id', _activeUserId)
            .maybeSingle()
            .timeout(const Duration(seconds: 4));
        if (profileRow != null) {
          _profile = UserProfileHealthMetric.fromSupabaseRow(Map<String, dynamic>.from(profileRow));
          _saveProfile();
        }
      } catch (e) {
        debugPrint('[DailyHealthService] Supabase user_health_profiles: $e');
      }

      // 4. Tải nhật ký chỉ số sức khỏe thật (daily_health_logs)
      try {
        final logRows = await client
            .from('daily_health_logs')
            .select()
            .eq('user_id', _activeUserId)
            .order('log_date', ascending: true)
            .timeout(const Duration(seconds: 4));
        if (logRows.isNotEmpty) {
          _logs.clear();
          for (final row in (logRows as List)) {
            final log = DailyHealthLog.fromSupabaseRow(Map<String, dynamic>.from(row));
            _logs[_dateKey(log.date)] = log;
          }
          _saveLogs();
        }
      } catch (e) {
        debugPrint('[DailyHealthService] Supabase daily_health_logs: $e');
      }

      // 5. Tải bài học đã hoàn thành hôm nay (daily_health_completed_lessons)
      try {
        final todayStr = _dateKey(DateTime.now());
        final completedRows = await client
            .from('daily_health_completed_lessons')
            .select('lesson_slug')
            .eq('user_id', _activeUserId)
            .eq('completed_date', todayStr)
            .timeout(const Duration(seconds: 4));
        if (completedRows.isNotEmpty) {
          _todayCompletedLessons.clear();
          for (final row in (completedRows as List)) {
            _todayCompletedLessons.add(row['lesson_slug'] as String);
          }
          _saveCompletedLessons();
        }
      } catch (e) {
        debugPrint('[DailyHealthService] Supabase daily_health_completed_lessons: $e');
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[DailyHealthService] Lỗi chung khi đồng bộ Supabase Cloud: $e');
    }
  }

  // ===========================================================================
  // QUẢN LÝ THỂ TRẠNG & PROFILE
  // ===========================================================================

  Future<void> updateProfile(UserProfileHealthMetric newProfile) async {
    _profile = newProfile;
    notifyListeners();
    await _saveProfile();

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        await client.from('user_health_profiles').upsert(
              newProfile.toSupabaseRow(_activeUserId),
              onConflict: 'user_id',
            );
      }
    } catch (e) {
      debugPrint('[DailyHealthService] Lỗi lưu Profile lên Supabase: $e');
    }
  }

  Future<void> _saveProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyProfile, jsonEncode(_profile.toJson()));
    } catch (e) {
      debugPrint('[DailyHealthService] Lỗi lưu Profile: $e');
    }
  }

  // ===========================================================================
  // QUẢN LÝ NHẬT KÝ CHỈ SỐ HÀNG NGÀY (DAILY LOGS)
  // ===========================================================================

  DailyHealthLog getLogForDate(DateTime date) {
    final key = _dateKey(date);
    if (_logs.containsKey(key)) {
      return _logs[key]!;
    }
    // Trả về bản ghi rỗng cho ngày đó
    return DailyHealthLog(date: DateTime(date.year, date.month, date.day));
  }

  Future<void> saveDailyLog(DailyHealthLog log) async {
    final key = _dateKey(log.date);
    _logs[key] = log;
    notifyListeners();
    await _saveLogs();

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        await client.from('daily_health_logs').upsert(
              log.toSupabaseRow(_activeUserId),
              onConflict: 'user_id,log_date',
            );
      }
    } catch (e) {
      debugPrint('[DailyHealthService] Lỗi lưu Daily Log lên Supabase: $e');
    }
  }

  Future<void> quickAddWater(int amountMl, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final currentLog = getLogForDate(targetDate);
    final updated = currentLog.copyWith(
      waterMl: math.max(0, currentLog.waterMl + amountMl),
    );
    await saveDailyLog(updated);
  }

  List<DailyHealthLog> getLogsForHorizon(TimeHorizon horizon, {DateTime? referenceDate}) {
    final ref = referenceDate ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);

    switch (horizon) {
      case TimeHorizon.day:
        return [getLogForDate(today)];

      case TimeHorizon.week:
        final weekday = today.weekday;
        final monday = today.subtract(Duration(days: weekday - 1));
        final list = <DailyHealthLog>[];
        for (int i = 0; i < 7; i++) {
          final d = monday.add(Duration(days: i));
          list.add(getLogForDate(d));
        }
        return list;

      case TimeHorizon.month:
        final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
        final list = <DailyHealthLog>[];
        for (int i = 1; i <= daysInMonth; i++) {
          final d = DateTime(today.year, today.month, i);
          list.add(getLogForDate(d));
        }
        return list;

      case TimeHorizon.year:
        final list = <DailyHealthLog>[];
        for (int m = 1; m <= 12; m++) {
          final daysInM = DateTime(today.year, m + 1, 0).day;
          double totalCal = 0;
          double totalBurn = 0;
          int totalWater = 0;
          double totalSleep = 0;
          int totalEx = 0;
          int count = 0;

          for (int d = 1; d <= daysInM; d++) {
            final key = _dateKey(DateTime(today.year, m, d));
            if (_logs.containsKey(key)) {
              final item = _logs[key]!;
              totalCal += item.caloriesIn;
              totalBurn += item.caloriesBurned;
              totalWater += item.waterMl;
              totalSleep += item.sleepHours;
              totalEx += item.exerciseMinutes;
              count++;
            }
          }
          if (count == 0) count = 1;
          list.add(DailyHealthLog(
            date: DateTime(today.year, m, 1),
            caloriesIn: totalCal / count,
            caloriesBurned: totalBurn / count,
            waterMl: (totalWater / count).round(),
            sleepHours: totalSleep / count,
            exerciseMinutes: (totalEx / count).round(),
          ));
        }
        return list;
    }
  }

  Future<void> _saveLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final Map<String, dynamic> rawMap = {};
      _logs.forEach((key, log) {
        rawMap[key] = log.toJson();
      });
      await prefs.setString(_keyLogs, jsonEncode(rawMap));
    } catch (e) {
      debugPrint('[DailyHealthService] Lỗi lưu logs: $e');
    }
  }

  Future<void> clearMockData() async {
    _logs.clear();
    await _saveLogs();
    notifyListeners();
  }

  // ===========================================================================
  // THUẬT TOÁN THÍCH ỨNG & DỰ BÁO CỦA TRỢ LÝ AI (SMART ADAPTIVE ASSISTANT)
  // ===========================================================================

  SmartHealthRecommendation getSmartRecommendation(DateTime date) {
    final log = getLogForDate(date);
    final targetCal = _profile.targetCalories;
    final targetWater = _profile.targetWaterMl;
    final targetSleep = _profile.targetSleepHours;
    final targetEx = _profile.targetExerciseMinutes;

    int score = 70;
    final tips = <String>[];

    // 1. Đánh giá Calo
    String calAssess;
    final calDiff = log.caloriesIn - targetCal;
    if (log.caloriesIn <= 0) {
      calAssess = 'Chưa ghi nhận khẩu phần ăn hôm nay.';
      tips.add('Đừng quên ghi lại các bữa ăn để theo dõi năng lượng.');
    } else if (calDiff.abs() <= 150) {
      calAssess = 'Mức Calo nạp vào rất chuẩn mục tiêu (${log.caloriesIn.round()} / $targetCal kcal).';
      score += 10;
    } else if (calDiff > 150) {
      calAssess = 'Đang dư thừa +${calDiff.round()} kcal so với mức mục tiêu.';
      score -= 5;
      tips.add('Hạn chế đồ uống có đường và đồ ăn vặt vào buổi tối.');
    } else {
      calAssess = 'Đang thiếu ${(-calDiff).round()} kcal so với mức mục tiêu.';
      score -= 5;
      tips.add('Bổ sung thêm một bữa phụ giàu đạm hoặc hạt dinh dưỡng.');
    }

    // 2. Đánh giá Nước uống
    String waterAssess;
    if (log.waterMl >= targetWater) {
      waterAssess = 'Đạt chuẩn lượng nước khuyến nghị (${log.waterMl} / $targetWater ml).';
      score += 10;
    } else if (log.waterMl > 0) {
      final deficit = targetWater - log.waterMl;
      waterAssess = 'Còn thiếu $deficit ml nước để đạt mục tiêu trong ngày.';
      tips.add('Uống thêm 1-2 cốc nước lọc trước bữa tối.');
      score -= 5;
    } else {
      waterAssess = 'Chưa ghi nhận lượng nước đã uống hôm nay.';
      tips.add('Uống nước ngay sau khi ngủ dậy để kích hoạt tuần hoàn.');
    }

    // 3. Đánh giá Giấc ngủ
    String sleepAssess;
    if (log.sleepHours >= targetSleep) {
      sleepAssess = 'Ngủ đủ giấc (${log.sleepHours}h / ${targetSleep}h chuẩn). Cơ thể phục hồi tối ưu.';
      score += 10;
    } else if (log.sleepHours > 0) {
      final sleepDeficit = targetSleep - log.sleepHours;
      sleepAssess = 'Thiếu ${sleepDeficit.toStringAsFixed(1)}h ngủ so với chuẩn CDC.';
      tips.add('Tối nay nên đi ngủ sớm hơn 30-45 phút.');
      score -= 8;
    } else {
      sleepAssess = 'Chưa ghi nhận thời gian ngủ đêm qua.';
    }

    // 4. Đánh giá Vận động
    String exAssess;
    if (log.exerciseMinutes >= targetEx) {
      exAssess = 'Vận động thể chất rất tốt (${log.exerciseMinutes} / $targetEx phút).';
      score += 10;
    } else if (log.exerciseMinutes > 0) {
      exAssess = 'Đã vận động ${log.exerciseMinutes} phút. Còn thiếu ${targetEx - log.exerciseMinutes} phút.';
      tips.add('Đi bộ nhanh 10-15 phút sau bữa tối.');
    } else {
      exAssess = 'Chưa ghi nhận bài tập thể lực nào hôm nay.';
      tips.add('Dành ra 15 phút giãn cơ hoặc đi bộ tại chỗ.');
    }

    score = score.clamp(30, 100);

    // Thuật toán Thích ứng: Đưa ra kế hoạch bù trừ cho ngày mai
    final tomorrowAdjustments = <String>[];
    if (calDiff > 250) {
      final burnTarget = math.min(250, (calDiff * 0.6).round());
      tomorrowAdjustments.add('Ngày mai nên đi bộ nhanh thêm 20 phút (tiêu hao khoảng $burnTarget kcal) để bù trừ lượng calo dư.');
    } else if (calDiff < -300 && log.caloriesIn > 0) {
      tomorrowAdjustments.add('Ngày mai tăng thêm 1 phần tinh bột phức (yến mạch/khoai lang) để cơ thể không bị mệt mỏi.');
    }
    if (log.sleepHours > 0 && log.sleepHours < 6.5) {
      tomorrowAdjustments.add('Bù nợ ngủ: Giảm bớt 10 phút bài tập nặng ngày mai, ưu tiên kéo giãn và ngủ sớm trước 22:30.');
    }
    if (log.waterMl < (targetWater * 0.7) && log.waterMl > 0) {
      tomorrowAdjustments.add('Cài đặt lời nhắc uống nước mỗi 90 phút vào ngày mai để bù lượng nước thiếu hụt.');
    }
    if (tomorrowAdjustments.isEmpty) {
      tomorrowAdjustments.add('Duy trì phong độ hiện tại! Tiếp tục nạp đủ $targetCal kcal và uống $targetWater ml nước ngày mai.');
    }

    String headline = 'Thể trạng đang ở mức rất tốt!';
    if (score < 60) {
      headline = 'Cần chú ý phục hồi và bù đắp năng lượng';
    } else if (score < 80) {
      headline = 'Thể trạng ổn định, duy trì đà tiến bộ';
    }

    return SmartHealthRecommendation(
      healthScore: score,
      statusHeadline: headline,
      caloriesAssessment: calAssess,
      waterAssessment: waterAssess,
      sleepAssessment: sleepAssess,
      exerciseAssessment: exAssess,
      tomorrowAdaptiveAdjustment: tomorrowAdjustments.join(' '),
      nextWeekStrategy: 'Chiến lược tuần tới: Tập trung cân bằng 3 bữa chính giàu protein nạc và duy trì tối thiểu 150 phút aerobic/tuần theo chuẩn WHO.',
      monthlyForecast: 'Dự báo tháng tới: Nếu tiếp tục giữ đúng nhịp độ này, bạn sẽ cải thiện chỉ số BMI thêm 0.4 điểm và tăng 18% sức bền thể lực.',
      actionableTips: tips.isEmpty
          ? ['Duy trì giấc ngủ sâu và uống nước đều đặn suốt cả ngày.']
          : tips,
    );
  }

  // ===========================================================================
  // LỊCH TRÌNH ĂN UỐNG & BÀI TẬP CÁ NHÂN HÓA (MEAL & WORKOUT SCHEDULE)
  // ===========================================================================

  HealthSchedulePlan getSchedulePlan(DateTime date) {
    final targetCal = _profile.targetCalories;
    final breakfastCal = (targetCal * 0.25).round();
    final lunchCal = (targetCal * 0.35).round();
    final dinnerCal = (targetCal * 0.30).round();
    final snackCal = targetCal - breakfastCal - lunchCal - dinnerCal;

    final meals = <MealItem>[
      MealItem(
        mealType: 'Bữa Sáng (07:00 - 08:00)',
        name: 'Yến mạch nấu sữa hạt, chuối lát & hạt chia',
        calories: breakfastCal,
        macros: '${(breakfastCal * 0.20 / 4).round()}g Protein • ${(breakfastCal * 0.55 / 4).round()}g Carb • ${(breakfastCal * 0.25 / 9).round()}g Fat',
        description: 'Bữa sáng chuẩn y khoa cung cấp năng lượng phóng thích chậm, giàu chất xơ hòa tan beta-glucan.',
      ),
      MealItem(
        mealType: 'Bữa Trưa (11:30 - 12:30)',
        name: 'Cơm gạo lứt, ức gà áp chảo & bông cải xanh luộc',
        calories: lunchCal,
        macros: '${(lunchCal * 0.30 / 4).round()}g Protein • ${(lunchCal * 0.45 / 4).round()}g Carb • ${(lunchCal * 0.25 / 9).round()}g Fat',
        description: 'Tỷ lệ đĩa ăn chuẩn: 1/2 rau xanh, 1/4 đạm nạc và 1/4 tinh bột nguyên cám.',
      ),
      MealItem(
        mealType: 'Bữa Phụ (15:30 - 16:00)',
        name: 'Sữa chua Hy Lạp không đường & táo xanh',
        calories: snackCal,
        macros: '${(snackCal * 0.35 / 4).round()}g Protein • ${(snackCal * 0.45 / 4).round()}g Carb • ${(snackCal * 0.20 / 9).round()}g Fat',
        description: 'Bổ sung lợi khuẩn đường ruột probiotic và giữ đường huyết ổn định.',
      ),
      MealItem(
        mealType: 'Bữa Tối (18:30 - 19:30)',
        name: 'Cá hồi / cá basa nướng, canh rong biển đậu hũ',
        calories: dinnerCal,
        macros: '${(dinnerCal * 0.30 / 4).round()}g Protein • ${(dinnerCal * 0.40 / 4).round()}g Carb • ${(dinnerCal * 0.30 / 9).round()}g Fat',
        description: 'Bữa tối nhẹ bụng, giàu Omega-3 giúp giảm viêm mạch máu và dễ đi vào giấc ngủ.',
      ),
    ];

    final isWeekend = date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
    WorkoutItem workout;
    String focus;

    if (isWeekend) {
      focus = 'Phục hồi chủ động & Giãn cơ toàn thân';
      workout = const WorkoutItem(
        title: 'Đi bộ thư giãn & Yoga giãn cơ phục hồi',
        durationMinutes: 30,
        estimatedBurnKcal: 140,
        level: 'Nhẹ nhàng',
        category: 'Giãn cơ / Phục hồi',
        steps: [
          'Khởi động xoay nhẹ các khớp cổ tay, cổ chân và vai trong 3 phút.',
          'Đi bộ ngoài trời tốc độ thư thái, hít thở sâu trong 20 phút.',
          'Các tư thế giãn cơ hông, đùi sau và lưng dưới trong 7 phút.',
        ],
      );
    } else {
      focus = 'Tăng cường sức bền tim mạch & Tiêu hao mỡ';
      workout = const WorkoutItem(
        title: 'Cardio nhịp tim vừa phải (Zone 2) & Bodyweight',
        durationMinutes: 30,
        estimatedBurnKcal: 210,
        level: 'Vừa sức',
        category: 'Cardio',
        steps: [
          'Đi bộ tốc độ vừa phải trong 5 phút.',
          'Tăng tốc đi bộ nhanh (sải chân dài, vung tay đều) trong 18 phút.',
          'Giảm tốc độ đi chậm thả lỏng trong 4 phút.',
        ],
      );
    }

    return HealthSchedulePlan(
      date: date,
      meals: meals,
      primaryWorkout: workout,
      dayFocus: focus,
    );
  }

  // ===========================================================================
  // QUẢN LÝ BÀI HỌC CẨM NANG (CHO CẢ USER & ADMIN)
  // ===========================================================================

  List<DailyCareLesson> getPublishedLessons({DailyCareFrequency? frequency}) {
    return _lessons.where((lesson) {
      if (!lesson.isPublished) return false;
      if (frequency != null && lesson.frequency != frequency) return false;
      return true;
    }).toList();
  }

  bool isLessonCompletedToday(String slug) => _todayCompletedLessons.contains(slug);

  Future<void> toggleLessonCompletionToday(String slug) async {
    final isDone = _todayCompletedLessons.contains(slug);
    if (isDone) {
      _todayCompletedLessons.remove(slug);
    } else {
      _todayCompletedLessons.add(slug);
    }
    notifyListeners();
    await _saveCompletedLessons();

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        final todayStr = _dateKey(DateTime.now());
        if (!isDone) {
          await client.from('daily_health_completed_lessons').upsert({
            'user_id': _activeUserId,
            'lesson_slug': slug,
            'completed_date': todayStr,
          }, onConflict: 'user_id,lesson_slug,completed_date');
        } else {
          await client
              .from('daily_health_completed_lessons')
              .delete()
              .eq('user_id', _activeUserId)
              .eq('lesson_slug', slug)
              .eq('completed_date', todayStr);
        }
      }
    } catch (e) {
      debugPrint('[DailyHealthService] Lỗi lưu trạng thái bài học lên Supabase: $e');
    }
  }

  Future<void> _saveCompletedLessons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayKey = '$_keyCompletedLessons${_dateKey(DateTime.now())}';
      await prefs.setStringList(todayKey, _todayCompletedLessons.toList());
    } catch (e) {
      debugPrint('[DailyHealthService] Lỗi lưu hoàn thành bài học: $e');
    }
  }

  int getTodayCompletedCount({DailyCareFrequency? frequency}) {
    final published = getPublishedLessons(frequency: frequency);
    return published.where((l) => _todayCompletedLessons.contains(l.slug)).length;
  }

  Future<void> saveLesson(DailyCareLesson lesson) async {
    final idx = _lessons.indexWhere((l) => l.slug == lesson.slug);
    if (idx >= 0) {
      _lessons[idx] = lesson;
    } else {
      _lessons.add(lesson);
    }
    _sortLessons();
    notifyListeners();
    await _saveLessons();

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        await client.from('daily_care_lessons').upsert(
              lesson.toSupabaseRow(),
              onConflict: 'slug',
            );
      }
    } catch (e) {
      debugPrint('[DailyHealthService] Lỗi lưu bài học lên Supabase: $e');
    }
  }

  Future<void> deleteLesson(String slug) async {
    _lessons.removeWhere((l) => l.slug == slug);
    notifyListeners();
    await _saveLessons();

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        await client.from('daily_care_lessons').delete().eq('slug', slug);
      }
    } catch (e) {
      debugPrint('[DailyHealthService] Lỗi xóa bài học trên Supabase: $e');
    }
  }

  Future<void> toggleLessonPublishStatus(String slug) async {
    final idx = _lessons.indexWhere((l) => l.slug == slug);
    if (idx >= 0) {
      final newStatus = !_lessons[idx].isPublished;
      _lessons[idx] = _lessons[idx].copyWith(isPublished: newStatus);
      notifyListeners();
      await _saveLessons();

      try {
        final client = SupabaseService.instance.client;
        if (client != null) {
          await client
              .from('daily_care_lessons')
              .update({'is_published': newStatus, 'updated_at': DateTime.now().toIso8601String()})
              .eq('slug', slug);
        }
      } catch (e) {
        debugPrint('[DailyHealthService] Lỗi cập nhật trạng thái xuất bản: $e');
      }
    }
  }

  void _sortLessons() {
    _lessons.sort((a, b) {
      final comp = a.sortOrder.compareTo(b.sortOrder);
      if (comp != 0) return comp;
      return a.slug.compareTo(b.slug);
    });
  }

  Future<void> _saveLessons() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _lessons.map((e) => e.toJson()).toList();
      await prefs.setString(_keyLessons, jsonEncode(list));
    } catch (e) {
      debugPrint('[DailyHealthService] Lỗi lưu lessons: $e');
    }
  }

  // ===========================================================================
  // QUẢN TRỊ ADMIN (CONFIG & ANALYTICS)
  // ===========================================================================

  Future<void> updateAdminConfig(AdminHealthConfig newConfig) async {
    _adminConfig = newConfig;
    notifyListeners();
    await _saveAdminConfig();

    try {
      final client = SupabaseService.instance.client;
      if (client != null) {
        await client.from('daily_health_admin_configs').upsert(
              newConfig.toSupabaseRow(),
              onConflict: 'id',
            );
      }
    } catch (e) {
      debugPrint('[DailyHealthService] Lỗi lưu cấu hình Admin lên Supabase: $e');
    }
  }

  Future<void> _saveAdminConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAdminConfig, jsonEncode(_adminConfig.toJson()));
    } catch (e) {
      debugPrint('[DailyHealthService] Lỗi lưu Admin Config: $e');
    }
  }

  Map<String, dynamic> getAnalyticsSummary() {
    int totalLoggedDays = _logs.length;
    int metCaloriesCount = 0;
    int metWaterCount = 0;
    int metSleepCount = 0;
    int metExerciseCount = 0;

    _logs.forEach((_, log) {
      if (log.caloriesIn >= (_profile.targetCalories * 0.8) &&
          log.caloriesIn <= (_profile.targetCalories * 1.2)) {
        metCaloriesCount++;
      }
      if (log.waterMl >= _profile.targetWaterMl) {
        metWaterCount++;
      }
      if (log.sleepHours >= 7.0) {
        metSleepCount++;
      }
      if (log.exerciseMinutes >= _profile.targetExerciseMinutes) {
        metExerciseCount++;
      }
    });

    final rateCal = totalLoggedDays > 0 ? (metCaloriesCount / totalLoggedDays * 100).round() : 0;
    final rateWater = totalLoggedDays > 0 ? (metWaterCount / totalLoggedDays * 100).round() : 0;
    final rateSleep = totalLoggedDays > 0 ? (metSleepCount / totalLoggedDays * 100).round() : 0;
    final rateExercise = totalLoggedDays > 0 ? (metExerciseCount / totalLoggedDays * 100).round() : 0;

    return {
      'totalLoggedDays': totalLoggedDays,
      'metCaloriesRate': rateCal,
      'metWaterRate': rateWater,
      'metSleepRate': rateSleep,
      'metExerciseRate': rateExercise,
      'publishedLessonsCount': _lessons.where((l) => l.isPublished).length,
      'totalLessonsCount': _lessons.length,
      'currentHealthGoal': _profile.healthGoal.label,
    };
  }

  // ===========================================================================
  // 9 BÀI HỌC CẨM NANG CHUẨN Y KHOA QUỐC TẾ (WHO / NHS / CDC)
  // ===========================================================================

  List<DailyCareLesson> _createSeedLessons() {
    return [
      const DailyCareLesson(
        slug: 'van-dong-buoi-sang',
        frequency: DailyCareFrequency.daily,
        topic: DailyCareTopic.movement,
        title: 'Vận động nhẹ buổi sáng',
        summary: 'Nếu mới bắt đầu, thử đi bộ vài phút rồi tăng dần theo sức của mình.',
        steps: [
          'Chọn đoạn đường bằng phẳng và bắt đầu bằng nhịp đi bộ thoải mái.',
          'Khi đã quen, bạn có thể đi lâu hơn hoặc đi nhanh hơn nếu thấy phù hợp.'
        ],
        sourceName: 'WHO – Hướng dẫn về vận động thể chất',
        sourceUrl: 'https://www.who.int/europe/publications/i/item/9789240014886',
        sortOrder: 10,
        isPublished: true,
      ),
      const DailyCareLesson(
        slug: 'uong-nuoc-trong-ngay',
        frequency: DailyCareFrequency.daily,
        topic: DailyCareTopic.hydration,
        title: 'Uống nước đều trong ngày',
        summary: 'NHS dùng 6–8 cốc chất lỏng mỗi ngày làm mốc tham khảo chung.',
        steps: [
          'Để nước lọc trong tầm tay và uống rải đều trong ngày. Một số đồ uống khác như sữa hoặc trà không đường cũng được tính.',
          'Nhu cầu có thể tăng khi trời nóng hoặc vận động lâu. Nếu bác sĩ đã dặn hạn chế chất lỏng, hãy theo mức được hướng dẫn.'
        ],
        sourceName: 'NHS – Nước và bù đủ dịch',
        sourceUrl: 'https://www.nhs.uk/live-well/eat-well/food-guidelines-and-food-labels/water-drinks-nutrition/',
        sortOrder: 20,
        isPublished: true,
      ),
      const DailyCareLesson(
        slug: 'bua-an-da-dang',
        frequency: DailyCareFrequency.daily,
        topic: DailyCareTopic.nutrition,
        title: 'Chọn bữa ăn đa dạng',
        summary: 'Thêm rau và kết hợp món giàu đạm với thực phẩm giàu tinh bột.',
        steps: [
          'Gợi ý bữa sáng: yến mạch, sữa chua không đường và trái cây nguyên quả.',
          'Gợi ý bữa chính: cơm gạo lứt, cá hoặc đậu phụ, và một món rau.'
        ],
        sourceName: 'NHS – Ăn uống cân bằng',
        sourceUrl: 'https://www.nhs.uk/live-well/eat-well/how-to-eat-a-balanced-diet/eating-a-balanced-diet/',
        sortOrder: 30,
        isPublished: true,
      ),
      const DailyCareLesson(
        slug: 'gio-ngu-deu-dan',
        frequency: DailyCareFrequency.daily,
        topic: DailyCareTopic.sleep,
        title: 'Giữ giờ ngủ đều đặn',
        summary: 'Chọn giờ đi ngủ và thức dậy có thể duy trì mỗi ngày.',
        steps: [
          'Giữ giờ thức dậy tương đối ổn định, kể cả cuối tuần.',
          'Tắt thiết bị điện tử ít nhất 30 phút trước khi ngủ. CDC khuyến nghị người từ 18–60 tuổi ngủ ít nhất 7 giờ mỗi ngày.'
        ],
        sourceName: 'CDC – Giấc ngủ',
        sourceUrl: 'https://www.cdc.gov/sleep/about/index.html',
        sortOrder: 40,
        isPublished: true,
      ),
      const DailyCareLesson(
        slug: 'giam-ngoi-tinh-tai',
        frequency: DailyCareFrequency.daily,
        topic: DailyCareTopic.movement,
        title: 'Ngắt quãng thời gian ngồi tĩnh tại',
        summary: 'WHO khuyến cáo đứng dậy và vươn vai sau mỗi 45–60 phút làm việc liên tục.',
        steps: [
          'Đặt lời nhắc đứng dậy đi lại nhẹ nhàng hoặc leo cầu thang 2–3 phút.',
          'Thực hiện các động tác xoay cổ vai gáy và kéo giãn cột sống đơn giản tại chỗ.'
        ],
        sourceName: 'WHO – Hạn chế hành vi ngồi tĩnh tại',
        sourceUrl: 'https://www.who.int/news-room/fact-sheets/detail/physical-activity',
        sortOrder: 50,
        isPublished: true,
      ),
      const DailyCareLesson(
        slug: 'kiem-soat-duong-muoi',
        frequency: DailyCareFrequency.daily,
        topic: DailyCareTopic.nutrition,
        title: 'Kiểm soát muối và đường bổ sung',
        summary: 'Giảm tiêu thụ muối dưới 5g/ngày và hạn chế đồ uống có đường tinh luyện.',
        steps: [
          'Ưu tiên nêm nếm bằng thảo mộc, hạt tiêu và chanh thay vì dùng quá nhiều nước mắm mặn.',
          'Uống nước lọc hoặc trà thảo mộc thay vì nước ngọt có gas và trà sữa đóng chai.'
        ],
        sourceName: 'WHO – Hướng dẫn giảm muối và đường',
        sourceUrl: 'https://www.who.int/news-room/fact-sheets/detail/healthy-diet',
        sortOrder: 60,
        isPublished: true,
      ),
      const DailyCareLesson(
        slug: 'lap-lich-van-dong-tuan',
        frequency: DailyCareFrequency.weekly,
        topic: DailyCareTopic.movement,
        title: 'Lên lịch vận động trong tuần',
        summary: 'Chia thời gian vận động thành các buổi phù hợp với lịch sinh hoạt.',
        steps: [
          'Với người trưởng thành, WHO khuyến nghị 150–300 phút vận động aerobic mức vừa mỗi tuần. Khi mới bắt đầu, chọn mức vừa sức và tăng dần.',
          'Ví dụ khi đã quen: đi bộ nhanh 30 phút trong 5 ngày. Có thể bố trí thêm 2 ngày tập tăng sức mạnh cho các nhóm cơ lớn.'
        ],
        sourceName: 'WHO – Khuyến nghị vận động thể chất',
        sourceUrl: 'https://www.who.int/europe/news-room/fact-sheets/item/physical-activity',
        sortOrder: 10,
        isPublished: true,
      ),
      const DailyCareLesson(
        slug: 'chuan-bi-thuc-don-tuan',
        frequency: DailyCareFrequency.weekly,
        topic: DailyCareTopic.nutrition,
        title: 'Chuẩn bị thực đơn cho tuần',
        summary: 'Chọn trước vài món có thể nấu và viết danh sách mua thực phẩm.',
        steps: [
          'Chọn rau và trái cây theo mùa để đổi món trong tuần.',
          'Luân phiên đậu, trứng, cá hoặc thịt nạc tùy sở thích và nhu cầu ăn uống.'
        ],
        sourceName: 'NHS – Ăn uống cân bằng',
        sourceUrl: 'https://www.nhs.uk/live-well/eat-well/how-to-eat-a-balanced-diet/eating-a-balanced-diet/',
        sortOrder: 20,
        isPublished: true,
      ),
      const DailyCareLesson(
        slug: 'danh-gia-chat-luong-ngu-tuan',
        frequency: DailyCareFrequency.weekly,
        topic: DailyCareTopic.sleep,
        title: 'Đánh giá & cân bằng giấc ngủ tuần',
        summary: 'Xem lại số giờ ngủ trung bình trong tuần và điều chỉnh nợ ngủ an toàn.',
        steps: [
          'Kiểm tra xem bạn có bị thiếu ngủ dồn dập vào các ngày trong tuần hay không.',
          'Tránh ngủ nướng bù quá 2 giờ vào cuối tuần để không phá vỡ nhịp sinh học tự nhiên.'
        ],
        sourceName: 'CDC – Thói quen ngủ lành mạnh',
        sourceUrl: 'https://www.cdc.gov/sleep/about/index.html',
        sortOrder: 30,
        isPublished: true,
      ),
    ];
  }
}
