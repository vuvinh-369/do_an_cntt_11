import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/browser_location_stub.dart'
    if (dart.library.js_interop) '../../../../core/browser_location_web.dart';
import '../../../../core/browser_position.dart';
import '../../../../core/nearby_places_api.dart';
import '../../../../core/url_launcher_helper.dart';

typedef NearbyPlacesFetcher =
    Future<NearbyPlacesResult> Function(
      NearbyLocation location, {
      required int radiusKm,
    });
typedef NearbyLocationsFetcher =
    Future<List<NearbyLocation>> Function(String address);

class NearbyPlacesDialog extends StatefulWidget {
  const NearbyPlacesDialog({
    super.key,
    this.fetchPlaces,
    this.fetchLocations,
  });

  final NearbyPlacesFetcher? fetchPlaces;
  final NearbyLocationsFetcher? fetchLocations;

  @override
  State<NearbyPlacesDialog> createState() => _NearbyPlacesDialogState();
}

class _NearbyPlacesDialogState extends State<NearbyPlacesDialog> {
  final _address = TextEditingController();
  final _addressFocus = FocusNode();
  List<NearbyLocation> _locations = const [];
  NearbyPlacesResult? _result;
  NearbyLocation? _searchedLocation;
  int _radiusKm = 5;
  HealthFacilityType? _filter;
  String? _loading;
  String? _message;

  NearbyPlacesFetcher get _fetchPlaces =>
      widget.fetchPlaces ?? findNearbyPlaces;
  NearbyLocationsFetcher get _fetchLocations =>
      widget.fetchLocations ?? findNearbyLocations;

  @override
  void initState() {
    super.initState();
    if (canUseBrowserLocation) _useLocation();
  }

  @override
  void dispose() {
    _address.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  Future<void> _useLocation() async {
    if (_loading != null) return;
    if (!canUseBrowserLocation) {
      _addressFocus.requestFocus();
      return;
    }
    setState(() {
      _loading = 'Đang lấy vị trí thiết bị…';
      _message = null;
    });
    final BrowserPosition position;
    try {
      position = await getBrowserLocation();
    } on BrowserLocationFailure catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = null;
        _message = switch (error) {
          BrowserLocationFailure.denied =>
            'Trình duyệt chưa có quyền vị trí. Hãy cho phép Vị trí trong '
                'cài đặt trang và bấm lại.',
          BrowserLocationFailure.timedOut =>
            'Thiết bị lấy vị trí quá lâu. Hãy thử lại hoặc nhập địa chỉ.',
          BrowserLocationFailure.unavailable =>
            'Thiết bị chưa lấy được vị trí. Hãy bật dịch vụ vị trí hoặc '
                'nhập địa chỉ.',
        };
      });
      return;
    }
    if (!mounted) return;
    final accuracy = position.accuracyMeters;
    if (!accuracy.isFinite || accuracy >= 5000) {
      setState(() {
        _loading = null;
        _message =
            'Vị trí thiết bị quá rộng để tìm quanh bạn. Hãy nhập địa chỉ '
            'hoặc dán tọa độ từ Google Maps.';
      });
      return;
    }
    final accuracyText = accuracy < 1000
        ? '${accuracy.round()} m'
        : '${(accuracy / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
    await _search(
      NearbyLocation(
        label: 'Vị trí thiết bị (sai số khoảng $accuracyText)',
        coordinates: {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      ),
    );
  }

  Future<void> _searchAddress() async {
    if (_loading != null) return;
    final address = _address.text.trim();
    if (address.length < 3) return;
    FocusScope.of(context).unfocus();

    final parsedCoords = parseCoordinatesInput(address);
    if (parsedCoords != null) {
      await _search(
        NearbyLocation(
          label: parsedCoords.fromMapsLink
              ? 'Tọa độ từ liên kết Google Maps'
              : 'Tọa độ đã nhập',
          coordinates: {
            'latitude': parsedCoords.latitude,
            'longitude': parsedCoords.longitude,
          },
        ),
      );
      return;
    }
    if (isPlainCoordinateText(address)) {
      setState(() => _message = 'Tọa độ chưa hợp lệ. Hãy kiểm tra lại.');
      return;
    }

    setState(() {
      _loading = 'Đang tìm địa chỉ…';
      _message = null;
      _result = null;
      _locations = const [];
    });
    NearbyLocation? autoTarget;
    try {
      final locations = await _fetchLocations(address);
      if (!mounted) return;
      if (locations.length == 1) {
        autoTarget = locations.single;
      } else {
        setState(() {
          _locations = locations;
          if (locations.isEmpty) {
            _message =
                'Chưa tìm thấy địa chỉ. Hãy thêm phường và tỉnh/thành phố.';
          }
        });
      }
    } on NearbyPlacesException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted && autoTarget == null) setState(() => _loading = null);
    }
    if (autoTarget != null && mounted) {
      await _search(autoTarget);
    }
  }

  Future<void> _search(NearbyLocation location, {int? radiusKm}) async {
    setState(() {
      if (radiusKm != null) _radiusKm = radiusKm;
      _loading = 'Đang tìm cơ sở y tế…';
      _result = null;
      _message = null;
    });
    try {
      final result = await _fetchPlaces(location, radiusKm: _radiusKm);
      if (mounted) {
        setState(() {
          _result = result;
          _searchedLocation = location;
          _locations = const [];
        });
      }
    } on NearbyPlacesException catch (error) {
      if (mounted) setState(() => _message = error.message);
    } finally {
      if (mounted) setState(() => _loading = null);
    }
  }

  Future<void> _call(NearbyPlace place) async {
    try {
      if (await launchUrl(
        Uri(scheme: 'tel', path: place.dialNumber),
        webOnlyWindowName: '_top',
      )) {
        return;
      }
    } catch (_) {
      // Show the number when the device cannot open a dialer.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gọi ${place.phone} bằng điện thoại.')),
    );
  }

  void _openMaps(NearbyLocation location, NearbyPlace place) {
    final coordinates = location.coordinates;
    final params = <String, String>{
      'api': '1',
      'origin': '${coordinates['latitude']},${coordinates['longitude']}',
      'destination': '${place.latitude},${place.longitude}',
      if (place.placeId != null && place.placeId!.isNotEmpty)
        'destination_place_id': place.placeId!,
    };
    final uri = Uri.https('www.google.com', '/maps/dir/', params);
    UrlLauncherHelper.launchWebUrl(context, uri.toString());
  }

  void _searchInMaps() {
    final category = _filter?.label ?? 'Cơ sở y tế';
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': '$category gần tôi',
    });
    UrlLauncherHelper.launchWebUrl(context, uri.toString());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    final location = _searchedLocation;
    final loading = _loading;
    final message = _message;
    final places = result?.places
        .where((place) => _filter == null || place.type == _filter)
        .toList();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      child: SizedBox(
        width: 600,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cơ sở y tế gần đây',
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Đóng',
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                children: [
                  if (!canUseBrowserLocation) ...[
                    const Text(
                      kIsWeb
                          ? 'Địa chỉ LAN đang dùng HTTP. Hãy nhập địa chỉ, tọa độ '
                                'hoặc dán link Google Maps. Định vị tự động có trên bản HTTPS.'
                          : 'Nhập địa chỉ, tọa độ hoặc dán link Google Maps để tìm '
                                'cơ sở y tế và nhà thuốc gần đó.',
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: _address,
                    focusNode: _addressFocus,
                    enabled: loading == null,
                    maxLength: 500,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchAddress(),
                    decoration: const InputDecoration(
                      labelText: 'Địa chỉ, tọa độ hoặc link Google Maps',
                      hintText:
                          'Ví dụ: Chợ Bến Thành, TP.HCM hoặc dán link Google Maps',
                      border: OutlineInputBorder(),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _address,
                        builder: (context, value, child) => FilledButton(
                          onPressed:
                              loading == null && value.text.trim().length >= 3
                              ? _searchAddress
                              : null,
                          child: child,
                        ),
                        child: const Text('Tìm theo địa chỉ'),
                      ),
                      TextButton.icon(
                        onPressed: loading == null ? _useLocation : null,
                        icon: const Icon(Icons.my_location, size: 18),
                        label: Text(
                          canUseBrowserLocation
                              ? 'Dùng vị trí của tôi'
                              : 'Nhập vị trí của tôi',
                        ),
                      ),
                    ],
                  ),
                  if (loading != null) ...[
                    const SizedBox(height: 12),
                    const LinearProgressIndicator(),
                    const SizedBox(height: 8),
                    Text(loading),
                  ],
                  if (message != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  if (loading == null && _locations.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Chọn địa chỉ tìm được',
                      style: theme.textTheme.titleSmall,
                    ),
                    for (final match in _locations)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.location_on_outlined),
                        title: Text(match.label),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _search(match),
                      ),
                  ],
                  if (result != null && places != null && location != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      '${location.label} • Bán kính ${result.radiusKm.toStringAsFixed(0)} km',
                      style: theme.textTheme.titleSmall,
                    ),
                    const Text('Khoảng cách theo đường chim bay'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (final type in [null, ...HealthFacilityType.values])
                          ChoiceChip(
                            label: Text(type?.label ?? 'Tất cả'),
                            selected: _filter == type,
                            onSelected: (_) => setState(() => _filter = type),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (places.isEmpty) ...[
                      const Text(
                        'Nguồn dữ liệu hiện chưa trả về địa điểm phù hợp.',
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _searchInMaps,
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('Tra thêm trên Google Maps'),
                        ),
                      ),
                    ],
                    if (places.isEmpty && result.radiusKm < 15)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: loading == null
                              ? () => _search(location, radiusKm: 15)
                              : null,
                          child: const Text('Mở rộng tìm kiếm đến 15 km'),
                        ),
                      ),
                    if (result.radiusKm == 15)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: loading == null
                              ? () => _search(location, radiusKm: 5)
                              : null,
                          child: const Text('Thu về bán kính 5 km'),
                        ),
                      ),
                    if (result.places.isEmpty)
                      const Text(
                        'Kiểm tra lại vị trí hoặc thử địa chỉ cụ thể.',
                      ),
                    for (final place in places) _buildPlace(location, place),
                  ],
                ],
              ),
            ),
            if (result != null && result.isGoogleMaps)
              Padding(
                padding: const EdgeInsets.only(bottom: 10, top: 2),
                child: Text(
                  'Dữ liệu Google Maps (qua Serper)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else if (result != null || _locations.isNotEmpty)
              TextButton(
                onPressed: () => UrlLauncherHelper.launchWebUrl(
                  context,
                  'https://www.openstreetmap.org/copyright',
                ),
                child: const Text('© OpenStreetMap contributors'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlace(NearbyLocation location, NearbyPlace place) {
    final theme = Theme.of(context);
    final distance = place.distanceKm.toStringAsFixed(2).replaceAll('.', ',');
    final ratingText = place.rating != null
        ? ' • ★ ${place.rating!.toStringAsFixed(1).replaceAll('.', ',')}'
              '${place.ratingCount != null ? ' (${place.ratingCount})' : ''}'
        : '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(place.name, style: theme.textTheme.titleSmall),
            const SizedBox(height: 3),
            Text('${place.type.label} • $distance km$ratingText'),
            if (place.address.isNotEmpty) Text(place.address),
            if (place.hours != null && place.hours!.isNotEmpty)
              Text(
                'Hôm nay: ${place.hours}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF047857),
                ),
              ),
            if (place.phone == null) const Text('Chưa có số điện thoại'),
            Wrap(
              spacing: 8,
              children: [
                if (place.phone != null && place.dialNumber != null)
                  TextButton.icon(
                    onPressed: () => _call(place),
                    icon: const Icon(Icons.call_outlined, size: 18),
                    label: Text(place.phone!),
                  ),
                TextButton.icon(
                  onPressed: () => _openMaps(location, place),
                  icon: const Icon(Icons.directions_outlined, size: 18),
                  label: const Text('Chỉ đường trên Google Maps'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
