import 'package:flutter/material.dart';

enum DailyCareFrequency {
  daily('Hằng ngày', 'daily'),
  weekly('Theo tuần', 'weekly');

  const DailyCareFrequency(this.label, this.value);
  final String label;
  final String value;
}

enum DailyCareTopic {
  movement('Vận động', Icons.directions_walk_rounded),
  hydration('Uống nước', Icons.water_drop_outlined),
  nutrition('Ăn uống', Icons.restaurant_outlined),
  sleep('Giấc ngủ', Icons.bedtime_outlined);

  const DailyCareTopic(this.label, this.icon);
  final String label;
  final IconData icon;
}

class DailyCareLesson {
  const DailyCareLesson({
    required this.slug,
    required this.frequency,
    required this.topic,
    required this.title,
    required this.summary,
    required this.steps,
    required this.sourceName,
    required this.sourceUrl,
    this.sortOrder = 0,
    this.isPublished = true,
  });

  factory DailyCareLesson.fromRow(Map<String, dynamic> row) {
    return DailyCareLesson(
      slug: row['slug'] as String,
      frequency: DailyCareFrequency.values.firstWhere(
        (frequency) => frequency.value == row['frequency'],
      ),
      topic: DailyCareTopic.values.byName(row['topic'] as String),
      title: row['title'] as String,
      summary: row['summary'] as String,
      steps: List<String>.unmodifiable(row['steps'] as List<dynamic>),
      sourceName: row['source_name'] as String,
      sourceUrl: row['source_url'] as String,
      sortOrder: (row['sort_order'] as num?)?.toInt() ?? 0,
      isPublished: row['is_published'] as bool? ?? true,
    );
  }

  final String slug;
  final DailyCareFrequency frequency;
  final DailyCareTopic topic;
  final String title;
  final String summary;
  final List<String> steps;
  final String sourceName;
  final String sourceUrl;
  final int sortOrder;
  final bool isPublished;

  DailyCareLesson copyWith({
    String? slug,
    DailyCareFrequency? frequency,
    DailyCareTopic? topic,
    String? title,
    String? summary,
    List<String>? steps,
    String? sourceName,
    String? sourceUrl,
    int? sortOrder,
    bool? isPublished,
  }) {
    return DailyCareLesson(
      slug: slug ?? this.slug,
      frequency: frequency ?? this.frequency,
      topic: topic ?? this.topic,
      title: title ?? this.title,
      summary: summary ?? this.summary,
      steps: steps ?? this.steps,
      sourceName: sourceName ?? this.sourceName,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      sortOrder: sortOrder ?? this.sortOrder,
      isPublished: isPublished ?? this.isPublished,
    );
  }

  Map<String, dynamic> toJson() => {
        'slug': slug,
        'frequency': frequency.value,
        'topic': topic.name,
        'title': title,
        'summary': summary,
        'steps': steps,
        'source_name': sourceName,
        'source_url': sourceUrl,
        'sort_order': sortOrder,
        'is_published': isPublished,
      };

  Map<String, dynamic> toSupabaseRow() => {
        'slug': slug,
        'frequency': frequency.value,
        'topic': topic.name,
        'title': title,
        'summary': summary,
        'steps': steps,
        'source_name': sourceName,
        'source_url': sourceUrl,
        'sort_order': sortOrder,
        'is_published': isPublished,
        'updated_at': DateTime.now().toIso8601String(),
      };

  Uri? get sourceUri {
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }
}
