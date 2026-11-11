import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'nearby_places_dialog.dart';

class EmergencyActions extends StatelessWidget {
  const EmergencyActions({super.key});

  static Future<void> _call115(BuildContext context) async {
    try {
      final opened = await launchUrl(
        Uri(scheme: 'tel', path: '115'),
        webOnlyWindowName: '_top',
      );
      if (opened) return;
    } catch (_) {
      // Some devices do not have an app that handles telephone links.
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Hãy dùng điện thoại để gọi cấp cứu 115.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Gọi cấp cứu y tế 115',
          child: FilledButton.icon(
            onPressed: () => _call115(context),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB91C1C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            icon: const Icon(Icons.call_rounded, size: 18),
            label: const Text('SOS 115'),
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: FilledButton.tonalIcon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => const NearbyPlacesDialog(),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            icon: const Icon(Icons.location_on_outlined, size: 18),
            label: const Text(
              'Cơ sở y tế gần đây',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}
