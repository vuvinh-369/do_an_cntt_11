import 'dart:math' as math;

/// Mục tiêu thể trạng của người dùng
enum HealthGoal {
  weightLoss('Giảm cân / Giảm mỡ', 'weight_loss'),
  maintenance('Duy trì sức khỏe', 'maintenance'),
  muscleGain('Tăng cơ / Tăng cân', 'muscle_gain');

  const HealthGoal(this.label, this.value);
  final String label;
  final String value;

  static HealthGoal fromString(String? val) {
    return HealthGoal.values.firstWhere(
      (g) => g.value == val,
      orElse: () => HealthGoal.maintenance,
    );
  }
}

/// Mức độ vận động thể chất hàng ngày
enum ActivityLevel {
  sedentary('Ít vận động (Dân văn phòng, ngồi nhiều)', 1.2),
  light('Vận động nhẹ (Đi bộ nhẹ, tập 1-3 ngày/tuần)', 1.375),
  moderate('Vận động vừa phải (Tập thể thao 3-5 ngày/tuần)', 1.55),
  veryActive('Vận động nhiều (Tập nặng 6-7 ngày/tuần)', 1.725);

  const ActivityLevel(this.label, this.multiplier);
  final String label;
  final double multiplier;

  static ActivityLevel fromString(String? val) {
    if (val == 'sedentary') return ActivityLevel.sedentary;
    if (val == 'light') return ActivityLevel.light;
    if (val == 'veryActive') return ActivityLevel.veryActive;
    return ActivityLevel.moderate;
  }
}

/// Khung thời gian xem chỉ số
enum TimeHorizon {
  day('Hôm nay (Ngày)'),
  week('Tuần này'),
  month('Tháng này'),
  year('Năm nay');

  const TimeHorizon(this.label);
  final String label;
}

/// Hồ sơ chỉ số thể trạng và mục tiêu sức khỏe người dùng
class UserProfileHealthMetric {
  final double heightCm;
  final double weightKg;
  final int age;
  final String gender; // 'male' hoặc 'female'
  final ActivityLevel activityLevel;
  final HealthGoal healthGoal;

  const UserProfileHealthMetric({
    this.heightCm = 170.0,
    this.weightKg = 65.0,
    this.age = 26,
    this.gender = 'male',
    this.activityLevel = ActivityLevel.moderate,
    this.healthGoal = HealthGoal.maintenance,
  });

  /// Tính chỉ số BMI (Body Mass Index)
  double get bmi {
    if (heightCm <= 0) return 0;
    final heightM = heightCm / 100.0;
    return double.parse((weightKg / (heightM * heightM)).toStringAsFixed(1));
  }

  /// Phân loại chỉ số BMI theo chuẩn y tế châu Á
  String get bmiCategory {
    final b = bmi;
    if (b < 18.5) return 'Gầy (Thiếu cân)';
    if (b < 23.0) return 'Bình thường (Lý tưởng)';
    if (b < 25.0) return 'Tiền béo phì (Thừa cân nhẹ)';
    if (b < 30.0) return 'Béo phì độ 1';
    return 'Béo phì độ 2';
  }

  /// Tính BMR (Tỷ lệ trao đổi chất cơ bản) theo công thức Mifflin-St Jeor
  double get bmr {
    if (gender == 'female') {
      return (10 * weightKg) + (6.25 * heightCm) - (5 * age) - 161;
    }
    return (10 * weightKg) + (6.25 * heightCm) - (5 * age) + 5;
  }

  /// Tính TDEE (Tổng năng lượng tiêu hao hàng ngày)
  double get tdee => bmr * activityLevel.multiplier;

  /// Nhu cầu Calo mục tiêu chuẩn mỗi ngày theo mục tiêu thể trạng (kcal)
  int get targetCalories {
    switch (healthGoal) {
      case HealthGoal.weightLoss:
        // Thâm hụt 400 kcal an toàn
        return math.max(1200, (tdee - 400).round());
      case HealthGoal.muscleGain:
        // Dư thừa 300 kcal để phát triển cơ
        return (tdee + 300).round();
      case HealthGoal.maintenance:
        return tdee.round();
    }
  }

  /// Nhu cầu nước uống mục tiêu chuẩn mỗi ngày (ml) ~ 35ml/kg cân nặng
  int get targetWaterMl => (weightKg * 35).round();

  /// Thời gian ngủ mục tiêu mỗi đêm (giờ)
  double get targetSleepHours => 7.5;

  /// Thời lượng tập thể dục mục tiêu mỗi ngày (phút)
  int get targetExerciseMinutes => 30;

  UserProfileHealthMetric copyWith({
    double? heightCm,
    double? weightKg,
    int? age,
    String? gender,
    ActivityLevel? activityLevel,
    HealthGoal? healthGoal,
  }) {
    return UserProfileHealthMetric(
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      activityLevel: activityLevel ?? this.activityLevel,
      healthGoal: healthGoal ?? this.healthGoal,
    );
  }

  Map<String, dynamic> toJson() => {
        'heightCm': heightCm,
        'weightKg': weightKg,
        'age': age,
        'gender': gender,
        'activityLevel': activityLevel.name,
        'healthGoal': healthGoal.value,
      };

  Map<String, dynamic> toSupabaseRow(String userId) => {
        'user_id': userId,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'age': age,
        'gender': gender,
        'activity_level': activityLevel.name,
        'health_goal': healthGoal.value,
        'target_calories': targetCalories,
        'target_water_ml': targetWaterMl,
        'target_sleep_hours': targetSleepHours,
        'target_exercise_minutes': targetExerciseMinutes,
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory UserProfileHealthMetric.fromJson(Map<String, dynamic> json) {
    return UserProfileHealthMetric(
      heightCm: (json['heightCm'] as num?)?.toDouble() ?? 170.0,
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 65.0,
      age: json['age'] as int? ?? 26,
      gender: json['gender'] as String? ?? 'male',
      activityLevel: ActivityLevel.fromString(json['activityLevel'] as String?),
      healthGoal: HealthGoal.fromString(json['healthGoal'] as String?),
    );
  }

  factory UserProfileHealthMetric.fromSupabaseRow(Map<String, dynamic> row) {
    return UserProfileHealthMetric(
      heightCm: (row['height_cm'] as num?)?.toDouble() ?? 170.0,
      weightKg: (row['weight_kg'] as num?)?.toDouble() ?? 65.0,
      age: (row['age'] as num?)?.toInt() ?? 26,
      gender: row['gender'] as String? ?? 'male',
      activityLevel: ActivityLevel.fromString(row['activity_level'] as String?),
      healthGoal: HealthGoal.fromString(row['health_goal'] as String?),
    );
  }
}

/// Nhật ký ghi nhận chỉ số sức khỏe hàng ngày của người dùng
class DailyHealthLog {
  final DateTime date;
  final double caloriesIn; // Calo nạp vào qua ăn uống (kcal)
  final double caloriesBurned; // Calo tiêu hao qua vận động (kcal)
  final int waterMl; // Nước đã uống (ml)
  final double sleepHours; // Giờ ngủ (giờ)
  final int exerciseMinutes; // Phút tập luyện
  final double? weightKg; // Cân nặng ghi nhận ngày hôm đó
  final String? notes; // Ghi chú thể trạng, cảm nhận

  const DailyHealthLog({
    required this.date,
    this.caloriesIn = 0.0,
    this.caloriesBurned = 0.0,
    this.waterMl = 0,
    this.sleepHours = 0.0,
    this.exerciseMinutes = 0,
    this.weightKg,
    this.notes,
  });

  /// Calo ròng = Calo nạp vào - Calo đốt cháy
  double get netCalories => caloriesIn - caloriesBurned;

  DailyHealthLog copyWith({
    DateTime? date,
    double? caloriesIn,
    double? caloriesBurned,
    int? waterMl,
    double? sleepHours,
    int? exerciseMinutes,
    double? weightKg,
    String? notes,
  }) {
    return DailyHealthLog(
      date: date ?? this.date,
      caloriesIn: caloriesIn ?? this.caloriesIn,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      waterMl: waterMl ?? this.waterMl,
      sleepHours: sleepHours ?? this.sleepHours,
      exerciseMinutes: exerciseMinutes ?? this.exerciseMinutes,
      weightKg: weightKg ?? this.weightKg,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'caloriesIn': caloriesIn,
        'caloriesBurned': caloriesBurned,
        'waterMl': waterMl,
        'sleepHours': sleepHours,
        'exerciseMinutes': exerciseMinutes,
        'weightKg': weightKg,
        'notes': notes,
      };

  Map<String, dynamic> toSupabaseRow(String userId) => {
        'user_id': userId,
        'log_date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'calories_in': caloriesIn,
        'calories_burned': caloriesBurned,
        'water_ml': waterMl,
        'sleep_hours': sleepHours,
        'exercise_minutes': exerciseMinutes,
        'weight_kg': weightKg,
        'notes': notes,
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory DailyHealthLog.fromJson(Map<String, dynamic> json) {
    return DailyHealthLog(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      caloriesIn: (json['caloriesIn'] as num?)?.toDouble() ?? 0.0,
      caloriesBurned: (json['caloriesBurned'] as num?)?.toDouble() ?? 0.0,
      waterMl: (json['waterMl'] as num?)?.toInt() ?? 0,
      sleepHours: (json['sleepHours'] as num?)?.toDouble() ?? 0.0,
      exerciseMinutes: (json['exerciseMinutes'] as num?)?.toInt() ?? 0,
      weightKg: (json['weightKg'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
    );
  }

  factory DailyHealthLog.fromSupabaseRow(Map<String, dynamic> row) {
    return DailyHealthLog(
      date: DateTime.tryParse(row['log_date'] as String? ?? '') ?? DateTime.now(),
      caloriesIn: (row['calories_in'] as num?)?.toDouble() ?? 0.0,
      caloriesBurned: (row['calories_burned'] as num?)?.toDouble() ?? 0.0,
      waterMl: (row['water_ml'] as num?)?.toInt() ?? 0,
      sleepHours: (row['sleep_hours'] as num?)?.toDouble() ?? 0.0,
      exerciseMinutes: (row['exercise_minutes'] as num?)?.toInt() ?? 0,
      weightKg: (row['weight_kg'] as num?)?.toDouble(),
      notes: row['notes'] as String?,
    );
  }
}

/// Đánh giá, khuyến nghị thích ứng và dự báo thông minh của Trợ lý AI
class SmartHealthRecommendation {
  final int healthScore; // 0 - 100
  final String statusHeadline;
  final String caloriesAssessment;
  final String waterAssessment;
  final String sleepAssessment;
  final String exerciseAssessment;
  final String tomorrowAdaptiveAdjustment; // Bù trừ thích ứng cho ngày mai
  final String nextWeekStrategy; // Chiến lược cho tuần tới
  final String monthlyForecast; // Dự báo xu hướng cho tháng tới
  final List<String> actionableTips;

  const SmartHealthRecommendation({
    required this.healthScore,
    required this.statusHeadline,
    required this.caloriesAssessment,
    required this.waterAssessment,
    required this.sleepAssessment,
    required this.exerciseAssessment,
    required this.tomorrowAdaptiveAdjustment,
    required this.nextWeekStrategy,
    required this.monthlyForecast,
    required this.actionableTips,
  });
}

/// Món ăn gợi ý trong thực đơn
class MealItem {
  final String mealType; // 'Bữa sáng', 'Bữa trưa', 'Bữa tối', 'Bữa phụ'
  final String name;
  final int calories;
  final String description;
  final String macros; // Ví dụ: '25g Protein • 45g Carb • 10g Fat'

  const MealItem({
    required this.mealType,
    required this.name,
    required this.calories,
    required this.description,
    required this.macros,
  });
}

/// Bài tập thể dục gợi ý trong ngày
class WorkoutItem {
  final String title;
  final int durationMinutes;
  final int estimatedBurnKcal;
  final String level; // 'Nhẹ', 'Vừa sức', 'Nâng cao'
  final String category; // 'Cardio', 'Kháng lực', 'Giãn cơ / Phục hồi'
  final List<String> steps;

  const WorkoutItem({
    required this.title,
    required this.durationMinutes,
    required this.estimatedBurnKcal,
    required this.level,
    required this.category,
    required this.steps,
  });
}

/// Lịch trình ăn uống & tập luyện cá nhân hóa theo ngày
class HealthSchedulePlan {
  final DateTime date;
  final List<MealItem> meals;
  final WorkoutItem primaryWorkout;
  final String dayFocus; // Trọng tâm trong ngày

  const HealthSchedulePlan({
    required this.date,
    required this.meals,
    required this.primaryWorkout,
    required this.dayFocus,
  });
}

/// Cấu hình quản trị Admin cho chức năng Chăm sóc sức khỏe
class AdminHealthConfig {
  final int defaultWaterMultiplierMlPerKg;
  final int defaultDailyExerciseMin;
  final double defaultSleepStandardHours;
  final int weightLossDeficitKcal;
  final int muscleGainSurplusKcal;
  final bool autoAdaptiveAdjustmentEnabled;
  final String systemHealthNotice;

  const AdminHealthConfig({
    this.defaultWaterMultiplierMlPerKg = 35,
    this.defaultDailyExerciseMin = 30,
    this.defaultSleepStandardHours = 7.5,
    this.weightLossDeficitKcal = 400,
    this.muscleGainSurplusKcal = 300,
    this.autoAdaptiveAdjustmentEnabled = true,
    this.systemHealthNotice =
        'Hệ thống khuyến nghị tuân thủ tiêu chuẩn WHO & Viện Dinh Dưỡng Quốc Gia.',
  });

  Map<String, dynamic> toJson() => {
        'defaultWaterMultiplierMlPerKg': defaultWaterMultiplierMlPerKg,
        'defaultDailyExerciseMin': defaultDailyExerciseMin,
        'defaultSleepStandardHours': defaultSleepStandardHours,
        'weightLossDeficitKcal': weightLossDeficitKcal,
        'muscleGainSurplusKcal': muscleGainSurplusKcal,
        'autoAdaptiveAdjustmentEnabled': autoAdaptiveAdjustmentEnabled,
        'systemHealthNotice': systemHealthNotice,
      };

  factory AdminHealthConfig.fromJson(Map<String, dynamic> json) {
    return AdminHealthConfig(
      defaultWaterMultiplierMlPerKg:
          json['defaultWaterMultiplierMlPerKg'] as int? ?? 35,
      defaultDailyExerciseMin: json['defaultDailyExerciseMin'] as int? ?? 30,
      defaultSleepStandardHours:
          (json['defaultSleepStandardHours'] as num?)?.toDouble() ?? 7.5,
      weightLossDeficitKcal: json['weightLossDeficitKcal'] as int? ?? 400,
      muscleGainSurplusKcal: json['muscleGainSurplusKcal'] as int? ?? 300,
      autoAdaptiveAdjustmentEnabled:
          json['autoAdaptiveAdjustmentEnabled'] as bool? ?? true,
      systemHealthNotice: json['systemHealthNotice'] as String? ??
          'Hệ thống khuyến nghị tuân thủ tiêu chuẩn WHO & Viện Dinh Dưỡng Quốc Gia.',
    );
  }

  Map<String, dynamic> toSupabaseRow() => {
        'id': 'default_config',
        'default_water_multiplier_ml_per_kg': defaultWaterMultiplierMlPerKg,
        'default_daily_exercise_min': defaultDailyExerciseMin,
        'default_sleep_standard_hours': defaultSleepStandardHours,
        'weight_loss_deficit_kcal': weightLossDeficitKcal,
        'muscle_gain_surplus_kcal': muscleGainSurplusKcal,
        'auto_adaptive_adjustment_enabled': autoAdaptiveAdjustmentEnabled,
        'system_health_notice': systemHealthNotice,
        'updated_at': DateTime.now().toIso8601String(),
      };

  factory AdminHealthConfig.fromSupabaseRow(Map<String, dynamic> row) {
    return AdminHealthConfig(
      defaultWaterMultiplierMlPerKg:
          (row['default_water_multiplier_ml_per_kg'] as num?)?.toInt() ?? 35,
      defaultDailyExerciseMin:
          (row['default_daily_exercise_min'] as num?)?.toInt() ?? 30,
      defaultSleepStandardHours:
          (row['default_sleep_standard_hours'] as num?)?.toDouble() ?? 7.5,
      weightLossDeficitKcal:
          (row['weight_loss_deficit_kcal'] as num?)?.toInt() ?? 400,
      muscleGainSurplusKcal:
          (row['muscle_gain_surplus_kcal'] as num?)?.toInt() ?? 300,
      autoAdaptiveAdjustmentEnabled:
          row['auto_adaptive_adjustment_enabled'] as bool? ?? true,
      systemHealthNotice: row['system_health_notice'] as String? ??
          'Hệ thống khuyến nghị tuân thủ tiêu chuẩn WHO & Viện Dinh Dưỡng Quốc Gia.',
    );
  }

  AdminHealthConfig copyWith({
    int? defaultWaterMultiplierMlPerKg,
    int? defaultDailyExerciseMin,
    double? defaultSleepStandardHours,
    int? weightLossDeficitKcal,
    int? muscleGainSurplusKcal,
    bool? autoAdaptiveAdjustmentEnabled,
    String? systemHealthNotice,
  }) {
    return AdminHealthConfig(
      defaultWaterMultiplierMlPerKg:
          defaultWaterMultiplierMlPerKg ?? this.defaultWaterMultiplierMlPerKg,
      defaultDailyExerciseMin:
          defaultDailyExerciseMin ?? this.defaultDailyExerciseMin,
      defaultSleepStandardHours:
          defaultSleepStandardHours ?? this.defaultSleepStandardHours,
      weightLossDeficitKcal:
          weightLossDeficitKcal ?? this.weightLossDeficitKcal,
      muscleGainSurplusKcal:
          muscleGainSurplusKcal ?? this.muscleGainSurplusKcal,
      autoAdaptiveAdjustmentEnabled:
          autoAdaptiveAdjustmentEnabled ?? this.autoAdaptiveAdjustmentEnabled,
      systemHealthNotice: systemHealthNotice ?? this.systemHealthNotice,
    );
  }
}
