import 'package:flutter/material.dart';

/// Mức độ ưu tiên / tính chất nghiêm trọng của tổn thương do Rule Engine đánh giá
enum RuleSeverityLevel {
  normal, // Nhẹ - Có thể tự sơ cứu và theo dõi tại nhà
  warning, // Cần chú ý - Cần sơ cứu cẩn thận, theo dõi sát hoặc khám bác sĩ
  emergency, // Khẩn cấp / Nguy kịch - Gọi 115 hoặc đến ngay bệnh viện cấp cứu
}

extension RuleSeverityLevelExt on RuleSeverityLevel {
  String get label {
    switch (this) {
      case RuleSeverityLevel.normal:
        return 'Nhẹ - Tự xử lý tại nhà';
      case RuleSeverityLevel.warning:
        return 'Cần chú ý - Theo dõi sát';
      case RuleSeverityLevel.emergency:
        return 'Cấp cứu khẩn cấp (115)';
    }
  }

  Color get color {
    switch (this) {
      case RuleSeverityLevel.normal:
        return const Color(0xFF16A34A); // Xanh lá
      case RuleSeverityLevel.warning:
        return const Color(0xFFD97706); // Vàng hổ phách
      case RuleSeverityLevel.emergency:
        return const Color(0xFFDC2626); // Đỏ khẩn cấp
    }
  }

  Color get backgroundColor {
    switch (this) {
      case RuleSeverityLevel.normal:
        return const Color(0xFFF0FDF4);
      case RuleSeverityLevel.warning:
        return const Color(0xFFFFFBEB);
      case RuleSeverityLevel.emergency:
        return const Color(0xFFFEF2F2);
    }
  }

  Color get borderColor {
    switch (this) {
      case RuleSeverityLevel.normal:
        return const Color(0xFFBBF7D0);
      case RuleSeverityLevel.warning:
        return const Color(0xFFFDE68A);
      case RuleSeverityLevel.emergency:
        return const Color(0xFFFECACA);
    }
  }

  IconData get icon {
    switch (this) {
      case RuleSeverityLevel.normal:
        return Icons.check_circle_outline_rounded;
      case RuleSeverityLevel.warning:
        return Icons.warning_amber_rounded;
      case RuleSeverityLevel.emergency:
        return Icons.emergency_rounded;
    }
  }
}

/// Nguồn trích xuất y khoa có link tham chiếu chi tiết
class MedicalSourceLink {
  final String title;
  final String organization; // 'Hội Chữ Thập Đỏ Việt Nam', 'Bộ Y Tế', 'WHO', 'Mayo Clinic'
  final String url;
  final String publishYear;

  const MedicalSourceLink({
    required this.title,
    required this.organization,
    required this.url,
    this.publishYear = '2025',
  });
}

/// Ngữ cảnh đánh giá tổn thương đưa vào Rule Engine
class InjuryContext {
  final String injuryTypeId; // 'abrasion', 'cut_laceration', 'burn', 'bruise', 'none'
  final String injuryTypeName;
  final String locationId; // 'head', 'arm', 'leg', 'back', 'other'
  final int confidencePercent;

  // Các dấu hiệu cảnh báo do người dùng cung cấp hoặc chọn trực tiếp
  final bool isBleedingHeavy; // Chảy máu nhiều / không cầm sau 10-15 phút
  final bool hasDeepWoundOrForeignBody; // Vết thương sâu, hở miệng lớn hoặc có dị vật đâm vào
  final bool isLargeAreaBurnOrChemical; // Bỏng diện rộng, bỏng bọng nước to hoặc do hóa chất / điện
  final bool isSeverePainOrFractureSuspected; // Đau nhức dữ dội, biến dạng khớp nghi ngờ gãy xương
  final bool hasSignsOfInfection; // Vết thương sưng mủ, sốt cao, đỏ tấy lan rộng
  final bool isChildOrElderly; // Đối tượng dễ tổn thương: trẻ nhỏ hoặc người già

  const InjuryContext({
    required this.injuryTypeId,
    required this.injuryTypeName,
    this.locationId = 'arm',
    this.confidencePercent = 100,
    this.isBleedingHeavy = false,
    this.hasDeepWoundOrForeignBody = false,
    this.isLargeAreaBurnOrChemical = false,
    this.isSeverePainOrFractureSuspected = false,
    this.hasSignsOfInfection = false,
    this.isChildOrElderly = false,
  });

  InjuryContext copyWith({
    String? injuryTypeId,
    String? injuryTypeName,
    String? locationId,
    int? confidencePercent,
    bool? isBleedingHeavy,
    bool? hasDeepWoundOrForeignBody,
    bool? isLargeAreaBurnOrChemical,
    bool? isSeverePainOrFractureSuspected,
    bool? hasSignsOfInfection,
    bool? isChildOrElderly,
  }) {
    return InjuryContext(
      injuryTypeId: injuryTypeId ?? this.injuryTypeId,
      injuryTypeName: injuryTypeName ?? this.injuryTypeName,
      locationId: locationId ?? this.locationId,
      confidencePercent: confidencePercent ?? this.confidencePercent,
      isBleedingHeavy: isBleedingHeavy ?? this.isBleedingHeavy,
      hasDeepWoundOrForeignBody:
          hasDeepWoundOrForeignBody ?? this.hasDeepWoundOrForeignBody,
      isLargeAreaBurnOrChemical:
          isLargeAreaBurnOrChemical ?? this.isLargeAreaBurnOrChemical,
      isSeverePainOrFractureSuspected:
          isSeverePainOrFractureSuspected ?? this.isSeverePainOrFractureSuspected,
      hasSignsOfInfection: hasSignsOfInfection ?? this.hasSignsOfInfection,
      isChildOrElderly: isChildOrElderly ?? this.isChildOrElderly,
    );
  }
}

/// Một Quy tắc (Rule) trong Rule Engine sơ cứu
class FirstAidRule {
  final String id;
  final String code; // Ví dụ: 'RULE-BLEED-01'
  final String name;
  final String description;
  final RuleSeverityLevel severity;
  final String targetInjuryTypeId; // 'abrasion', 'cut_laceration', 'burn', 'bruise', 'all'
  final bool isEnabled;

  // Cờ điều kiện lâm sàng kích hoạt (để Admin tùy biến sâu trực tiếp bằng Checkbox trên UI)
  final bool requireBleedingHeavy; // Chảy máu nhiều / khó cầm
  final bool requireForeignBody; // Dị vật đâm vào / vết thương sâu
  final bool requireLargeBurnOrChemical; // Bỏng diện rộng / hóa chất / bọng nước lớn
  final bool requireSeverePainOrFracture; // Đau nhức dữ dội / nghi ngờ biến dạng, gãy xương
  final bool requireInfection; // Dấu hiệu sưng đỏ, chảy mủ, sốt

  // Điều kiện kích hoạt luật (hàm logic)
  final bool Function(InjuryContext context) condition;

  // Các hướng dẫn hành động tương ứng khi luật kích hoạt
  final List<String> primaryActions;
  final List<String> contraindications; // Những điều TUYỆT ĐỐI KHÔNG ĐƯỢC LÀM
  final String emergencyRecommendation; // Khuyến nghị đi viện / Gọi 115

  const FirstAidRule({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.severity,
    this.targetInjuryTypeId = 'all',
    this.isEnabled = true,
    this.requireBleedingHeavy = false,
    this.requireForeignBody = false,
    this.requireLargeBurnOrChemical = false,
    this.requireSeverePainOrFracture = false,
    this.requireInfection = false,
    required this.condition,
    required this.primaryActions,
    required this.contraindications,
    required this.emergencyRecommendation,
  });

  /// Kiểm tra xem ngữ cảnh có khớp với quy tắc này hay không
  bool matches(InjuryContext context) {
    if (!isEnabled) return false;
    if (targetInjuryTypeId != 'all' &&
        targetInjuryTypeId != context.injuryTypeId) {
      return false;
    }

    final bool hasSpecificFlag = requireBleedingHeavy ||
        requireForeignBody ||
        requireLargeBurnOrChemical ||
        requireSeverePainOrFracture ||
        requireInfection;

    if (hasSpecificFlag) {
      if (requireBleedingHeavy && !context.isBleedingHeavy) return false;
      if (requireForeignBody && !context.hasDeepWoundOrForeignBody) return false;
      if (requireLargeBurnOrChemical && !context.isLargeAreaBurnOrChemical) {
        return false;
      }
      if (requireSeverePainOrFracture &&
          !context.isSeverePainOrFractureSuspected) {
        return false;
      }
      if (requireInfection && !context.hasSignsOfInfection) return false;
      return true;
    }

    return condition(context);
  }

  FirstAidRule copyWith({
    String? id,
    String? code,
    String? name,
    String? description,
    RuleSeverityLevel? severity,
    String? targetInjuryTypeId,
    bool? isEnabled,
    bool? requireBleedingHeavy,
    bool? requireForeignBody,
    bool? requireLargeBurnOrChemical,
    bool? requireSeverePainOrFracture,
    bool? requireInfection,
    bool Function(InjuryContext context)? condition,
    List<String>? primaryActions,
    List<String>? contraindications,
    String? emergencyRecommendation,
  }) {
    return FirstAidRule(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      description: description ?? this.description,
      severity: severity ?? this.severity,
      targetInjuryTypeId: targetInjuryTypeId ?? this.targetInjuryTypeId,
      isEnabled: isEnabled ?? this.isEnabled,
      requireBleedingHeavy: requireBleedingHeavy ?? this.requireBleedingHeavy,
      requireForeignBody: requireForeignBody ?? this.requireForeignBody,
      requireLargeBurnOrChemical:
          requireLargeBurnOrChemical ?? this.requireLargeBurnOrChemical,
      requireSeverePainOrFracture:
          requireSeverePainOrFracture ?? this.requireSeverePainOrFracture,
      requireInfection: requireInfection ?? this.requireInfection,
      condition: condition ?? this.condition,
      primaryActions: primaryActions ?? this.primaryActions,
      contraindications: contraindications ?? this.contraindications,
      emergencyRecommendation:
          emergencyRecommendation ?? this.emergencyRecommendation,
    );
  }
}

/// Kết quả đầu ra sau khi Rule Engine đánh giá ngữ cảnh tổn thương
class RuleEvaluationResult {
  final RuleSeverityLevel finalSeverity;
  final String summaryTitle;
  final String statusDescription;
  final List<FirstAidRule> triggeredRules;
  final List<String> priorityActions;
  final List<String> contraindications; // Việc cấm kỵ
  final List<String> warningSymptoms; // Dấu hiệu nguy hiểm cần đi viện
  final String emergencyHospitalAdvice;
  final List<MedicalSourceLink> sourceLinks;
  final bool shouldCallEmergency115;

  const RuleEvaluationResult({
    required this.finalSeverity,
    required this.summaryTitle,
    required this.statusDescription,
    required this.triggeredRules,
    required this.priorityActions,
    required this.contraindications,
    required this.warningSymptoms,
    required this.emergencyHospitalAdvice,
    required this.sourceLinks,
    this.shouldCallEmergency115 = false,
  });
}
