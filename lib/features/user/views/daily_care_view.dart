import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_service.dart';
import '../../../core/url_launcher_helper.dart';
import '../models/daily_care_lesson.dart';

Future<List<DailyCareLesson>> _loadPublishedLessons() async {
  final client = SupabaseService.instance.client;
  if (client == null) throw StateError('Supabase chưa sẵn sàng.');

  final rows = await client
      .from('daily_care_lessons')
      .select('slug,frequency,topic,title,summary,steps,source_name,source_url')
      .eq('is_published', true)
      .order('sort_order', ascending: true)
      .order('slug', ascending: true)
      .timeout(const Duration(seconds: 10));
  return rows.map(DailyCareLesson.fromRow).toList();
}

class DailyCareView extends StatefulWidget {
  const DailyCareView({super.key, this.loadLessons = _loadPublishedLessons});

  final Future<List<DailyCareLesson>> Function() loadLessons;

  @override
  State<DailyCareView> createState() => _DailyCareViewState();
}

class _DailyCareViewState extends State<DailyCareView> {
  static const _ink = Color(0xFF124A38);
  static const _accent = Color(0xFF047857);
  static const _border = Color(0xFFDCECE4);

  late Future<List<DailyCareLesson>> _lessons;
  DailyCareFrequency _frequency = DailyCareFrequency.daily;

  @override
  void initState() {
    super.initState();
    _lessons = widget.loadLessons();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 768;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 36,
        vertical: isMobile ? 16 : 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FAF5),
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMobile) ...[
                  Text(
                    'Chăm sóc sức khỏe hằng ngày',
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(color: _ink, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                ],
                const Text(
                  'Các bài thực hành dành cho người trưởng thành về vận động, uống nước, ăn uống và giấc ngủ.',
                  style: TextStyle(color: _ink, height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final frequency in DailyCareFrequency.values)
                ChoiceChip(
                  label: Text(frequency.label),
                  selected: _frequency == frequency,
                  selectedColor: const Color(0xFFDDF5E8),
                  onSelected: (_) => setState(() => _frequency = frequency),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<List<DailyCareLesson>>(
            future: _lessons,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: CircularProgressIndicator(
                      semanticsLabel: 'Đang tải bài học',
                    ),
                  ),
                );
              }
              if (snapshot.hasError) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Chưa tải được bài học. Vui lòng thử lại.'),
                    TextButton.icon(
                      onPressed: () {
                        final lessons = widget.loadLessons();
                        setState(() {
                          _lessons = lessons;
                        });
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Thử lại'),
                    ),
                  ],
                );
              }
              final lessons = snapshot.requireData
                  .where((lesson) => lesson.frequency == _frequency)
                  .toList();
              if (lessons.isEmpty) {
                return const Text(
                  'Chưa có bài học được xuất bản trong mục này.',
                );
              }
              return Column(
                children: [for (final lesson in lessons) _lessonTile(lesson)],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _lessonTile(DailyCareLesson lesson) {
    final source = lesson.sourceUri;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: _border),
    );
    return Padding(
      key: ValueKey(lesson.slug),
      padding: const EdgeInsets.only(bottom: 10),
      child: ExpansionTile(
        key: PageStorageKey(lesson.slug),
        shape: shape,
        collapsedShape: shape,
        backgroundColor: const Color(0xFFFAFDFB),
        collapsedBackgroundColor: const Color(0xFFFAFDFB),
        textColor: _ink,
        collapsedTextColor: _ink,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFFE4F5EB),
          foregroundColor: _accent,
          child: Icon(lesson.topic.icon, semanticLabel: lesson.topic.label),
        ),
        title: Text(
          lesson.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(lesson.summary, style: const TextStyle(height: 1.4)),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        childrenPadding: const EdgeInsets.fromLTRB(18, 8, 18, 14),
        children: [
          for (final (index, step) in lesson.steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '${index + 1}. $step',
                style: const TextStyle(height: 1.5),
              ),
            ),
          if (source != null)
            TextButton.icon(
              onPressed: () =>
                  UrlLauncherHelper.launchWebUrl(context, source.toString()),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text('Nguồn: ${lesson.sourceName}'),
            ),
        ],
      ),
    );
  }
}
