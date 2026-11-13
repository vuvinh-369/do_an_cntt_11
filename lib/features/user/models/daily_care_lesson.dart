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
