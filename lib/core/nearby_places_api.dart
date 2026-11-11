import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'local_api_probe_stub.dart'
    if (dart.library.io) 'local_api_probe_io.dart';
import 'medgemma_chat_api.dart';
import 'serper/serper_config_service.dart';

enum HealthFacilityType {
  hospital('Bệnh viện'),
  clinic('Trung tâm y tế'),
  pharmacy('Nhà thuốc');

  const HealthFacilityType(this.label);

  final String label;
}

class NearbyPlace {
  NearbyPlace.fromJson(Map<String, dynamic> json)
    : type = HealthFacilityType.values.byName(json['kind'] as String),
      name = json['name'] as String,
      address = json['address'] as String,
      latitude = (json['latitude'] as num).toDouble(),
      longitude = (json['longitude'] as num).toDouble(),
      distanceKm = (json['distance_km'] as num).toDouble(),
      phone = json['phone'] as String?,
      dialNumber = json['dial_number'] as String?,
      rating = (json['rating'] as num?)?.toDouble(),
      ratingCount = (json['rating_count'] as num?)?.toInt(),
      hours = json['hours'] as String?,
      placeId = json['place_id'] as String?;

  final HealthFacilityType type;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String? phone;
  final String? dialNumber;
  final double? rating;
  final int? ratingCount;
  final String? hours;
  final String? placeId;
}

class NearbyPlacesResult {
  NearbyPlacesResult.fromJson(Map<String, dynamic> json)
    : radiusKm = (json['radius_km'] as num).toDouble(),
      source = json['source'] as String? ?? 'openstreetmap',
      places = (json['places'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(NearbyPlace.fromJson)
          .toList(growable: false);

  final double radiusKm;
  final String source;
  final List<NearbyPlace> places;

  bool get isGoogleMaps => source.startsWith('google_maps');
}

class NearbyLocation {
  const NearbyLocation({required this.label, required this.coordinates});

  NearbyLocation.fromJson(Map<String, dynamic> json)
    : label = json['label'] as String,
      coordinates = {
        'latitude': json['latitude'] as num,
        'longitude': json['longitude'] as num,
      };

  final String label;
  final Map<String, Object> coordinates;
}

class NearbyPlacesException implements Exception {
  const NearbyPlacesException(this.message);

  final String message;
}

final _plainCoordinatePattern = RegExp(
  r'^\s*([+-]?\d{1,3}(?:\.\d+)?)\s*,\s*([+-]?\d{1,3}(?:\.\d+)?)\s*$',
);
final _googleMapsCoordinatePatterns = [
  _plainCoordinatePattern,
  RegExp(r'!3d([+-]?\d{1,3}(?:\.\d+)?)!4d([+-]?\d{1,3}(?:\.\d+)?)'),
  RegExp(r'@([+-]?\d{1,3}(?:\.\d+)?)\s*,\s*([+-]?\d{1,3}(?:\.\d+)?)'),
  RegExp(
    r'[?&](?:q|query|ll)=([+-]?\d{1,3}(?:\.\d+)?)\s*,\s*([+-]?\d{1,3}(?:\.\d+)?)',
  ),
];

bool isPlainCoordinateText(String input) =>
    _plainCoordinatePattern.hasMatch(input);

({double latitude, double longitude, bool fromMapsLink})? parseCoordinatesInput(
  String input,
) {
  for (var i = 0; i < _googleMapsCoordinatePatterns.length; i++) {
    final match = _googleMapsCoordinatePatterns[i].firstMatch(input);
    if (match == null) continue;
    final latitude = double.tryParse(match[1]!);
    final longitude = double.tryParse(match[2]!);
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude.abs() > 90 ||
        longitude.abs() > 180) {
      continue;
    }
    return (latitude: latitude, longitude: longitude, fromMapsLink: i > 0);
  }
  return null;
}

final Uri _serperMapsUri = Uri.parse('https://google.serper.dev/maps');
final Uri _photonSearchUri = Uri.parse('https://photon.komoot.io/api/');
const Duration _directPlacesCacheTtl = Duration(minutes: 30);
const Duration _directGeocodeCacheTtl = Duration(hours: 6);
const int _directCacheMaxEntries = 64;

class _CachedValue<T> {
  _CachedValue(this.value, this.expiresAt);

  final T value;
  final DateTime expiresAt;

  bool get isFresh => DateTime.now().isBefore(expiresAt);
}

final Map<String, _CachedValue<Map<String, dynamic>>> _directPlacesCache = {};
final Map<String, _CachedValue<List<NearbyLocation>>> _directGeocodeCache = {};
int _lastSyncedConfigVersion = -1;

void _syncCacheWithConfigVersion() {
  final current = SerperConfigService.instance.configVersion;
  if (_lastSyncedConfigVersion != current) {
    _lastSyncedConfigVersion = current;
    _directPlacesCache.clear();
    _directGeocodeCache.clear();
  }
}

@visibleForTesting
void clearDirectSerperCache() {
  _directPlacesCache.clear();
  _directGeocodeCache.clear();
}

Future<NearbyPlacesResult> findNearbyPlaces(
  NearbyLocation location, {
  required int radiusKm,
  http.Client? client,
  Uri? baseUrl,
}) async {
  final resolvedBase = baseUrl ?? MedGemmaChatApi.defaultBaseUrl();
  if (client == null && !kIsWeb) {
    final reachable = await isLocalApiReachable(resolvedBase);
    if (!reachable) {
      await SerperConfigService.instance.refreshIfStale();
      return findNearbyPlacesDirect(
        location,
        radiusKm: radiusKm,
        apiKey: SerperConfigService.instance.apiKey,
      );
    }
    try {
      return await _requestNearby(
        {...location.coordinates, 'radius_km': radiusKm},
        NearbyPlacesResult.fromJson,
        baseUrl: resolvedBase,
      );
    } on Object {
      await SerperConfigService.instance.refreshIfStale();
      return findNearbyPlacesDirect(
        location,
        radiusKm: radiusKm,
        apiKey: SerperConfigService.instance.apiKey,
      );
    }
  }
  return _requestNearby(
    {...location.coordinates, 'radius_km': radiusKm},
    NearbyPlacesResult.fromJson,
    client: client,
    baseUrl: baseUrl,
  );
}

Future<List<NearbyLocation>> findNearbyLocations(
  String address, {
  http.Client? client,
  Uri? baseUrl,
}) async {
  final resolvedBase = baseUrl ?? MedGemmaChatApi.defaultBaseUrl();
  if (client == null && !kIsWeb) {
    final reachable = await isLocalApiReachable(resolvedBase);
    if (!reachable) {
      await SerperConfigService.instance.refreshIfStale();
      return findNearbyLocationsDirect(
        address,
        apiKey: SerperConfigService.instance.apiKey,
      );
    }
    try {
      return await _requestNearby(
        {'address': address},
        _parseLocationsJson,
        baseUrl: resolvedBase,
      );
    } on Object {
      await SerperConfigService.instance.refreshIfStale();
      return findNearbyLocationsDirect(
        address,
        apiKey: SerperConfigService.instance.apiKey,
      );
    }
  }
  return _requestNearby(
    {'address': address},
    _parseLocationsJson,
    client: client,
    baseUrl: baseUrl,
  );
}

List<NearbyLocation> _parseLocationsJson(Map<String, dynamic> json) {
  return (json['locations'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .map(NearbyLocation.fromJson)
      .toList(growable: false);
}

@visibleForTesting
Future<NearbyPlacesResult> findNearbyPlacesDirect(
  NearbyLocation location, {
  required int radiusKm,
  http.Client? client,
  String? apiKey,
}) async {
  _syncCacheWithConfigVersion();
  final lat = (location.coordinates['latitude'] as num?)?.toDouble();
  final lon = (location.coordinates['longitude'] as num?)?.toDouble();
  if (lat == null || lon == null || !lat.isFinite || !lon.isFinite) {
    throw const FormatException('Tọa độ tìm kiếm không hợp lệ.');
  }

  final effectiveKey = (apiKey ?? SerperConfigService.instance.apiKey).trim();
  final cacheKey =
      'places:${lat.toStringAsFixed(4)}:${lon.toStringAsFixed(4)}:$radiusKm:${effectiveKey.hashCode}';
  final cached = _directPlacesCache[cacheKey];
  if (cached != null && cached.isFresh) {
    return NearbyPlacesResult.fromJson({...cached.value, 'cached': true});
  }

  final httpClient = client ?? http.Client();
  try {
    if (effectiveKey.isNotEmpty) {
      try {
        final payload = await _searchSerperNearbyPlaces(
          httpClient,
          apiKey: effectiveKey,
          latitude: lat,
          longitude: lon,
          radiusKm: radiusKm,
        );
        _storeCache(
          _directPlacesCache,
          cacheKey,
          payload,
          _directPlacesCacheTtl,
        );
        return NearbyPlacesResult.fromJson(payload);
      } on Object {
        // Fall back to Photon keyword search near coordinates if Serper fails.
      }
    }

    final fallbackPayload = await _searchPhotonNearbyPlaces(
      httpClient,
      latitude: lat,
      longitude: lon,
      radiusKm: radiusKm,
    );
    return NearbyPlacesResult.fromJson(fallbackPayload);
  } finally {
    if (client == null) {
      httpClient.close();
    }
  }
}

@visibleForTesting
Future<List<NearbyLocation>> findNearbyLocationsDirect(
  String address, {
  http.Client? client,
  String? apiKey,
}) async {
  _syncCacheWithConfigVersion();
  final trimmed = address.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('Vui lòng nhập địa chỉ cần tìm.');
  }

  final effectiveKey = (apiKey ?? SerperConfigService.instance.apiKey).trim();
  final cacheKey = 'geo:${trimmed.toLowerCase()}:${effectiveKey.hashCode}';
  final cached = _directGeocodeCache[cacheKey];
  if (cached != null && cached.isFresh) {
    return cached.value;
  }

  final httpClient = client ?? http.Client();
  try {
    if (effectiveKey.isNotEmpty) {
      try {
        final serperLocations = await _geocodeSerperLocations(
          httpClient,
          apiKey: effectiveKey,
          address: trimmed,
        );
        if (serperLocations.isNotEmpty) {
          _storeCache(
            _directGeocodeCache,
            cacheKey,
            serperLocations,
            _directGeocodeCacheTtl,
          );
          return serperLocations;
        }
      } on Object {
        // Fall back to Photon geocoding if Serper fails.
      }
    }

    final photonLocations = await _geocodePhotonLocations(
      httpClient,
      address: trimmed,
    );
    if (photonLocations.isNotEmpty) {
      _storeCache(
        _directGeocodeCache,
        cacheKey,
        photonLocations,
        _directGeocodeCacheTtl,
      );
    }
    return photonLocations;
  } finally {
    if (client == null) {
      httpClient.close();
    }
  }
}

void _storeCache<T>(
  Map<String, _CachedValue<T>> cache,
  String key,
  T value,
  Duration ttl,
) {
  cache.removeWhere((_, entry) => !entry.isFresh);
  while (cache.length >= _directCacheMaxEntries) {
    cache.remove(cache.keys.first);
  }
  cache[key] = _CachedValue<T>(value, DateTime.now().add(ttl));
}

Future<Map<String, dynamic>> _postSerperMaps(
  http.Client client, {
  required String apiKey,
  required Map<String, Object> body,
}) async {
  final response = await client
      .post(
        _serperMapsUri,
        headers: {
          'X-API-KEY': apiKey,
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 12));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw http.ClientException(
      'Serper HTTP ${response.statusCode}',
      _serperMapsUri,
    );
  }
  final decoded = jsonDecode(utf8.decode(response.bodyBytes));
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Phản hồi Serper không hợp lệ.');
  }
  return decoded;
}

Future<Map<String, dynamic>> _searchSerperNearbyPlaces(
  http.Client client, {
  required String apiKey,
  required double latitude,
  required double longitude,
  required int radiusKm,
}) async {
  final latStr = latitude.toStringAsFixed(6);
  final lonStr = longitude.toStringAsFixed(6);
  final hospitalZoom = radiusKm <= 5 ? '14z' : '13z';
  final pharmacyZoom = radiusKm <= 5 ? '15z' : '13z';
  final specs = [
    (query: 'bệnh viện', defaultKind: 'hospital', zoom: hospitalZoom),
    (query: 'phòng khám', defaultKind: 'hospital', zoom: hospitalZoom),
    (query: 'nhà thuốc', defaultKind: 'pharmacy', zoom: pharmacyZoom),
  ];

  final results = await Future.wait(
    specs.map((spec) async {
      try {
        final data = await _postSerperMaps(
          client,
          apiKey: apiKey,
          body: {
            'q': spec.query,
            'll': '@$latStr,$lonStr,${spec.zoom}',
            'gl': 'vn',
            'hl': 'vi',
          },
        );
        return (spec: spec, data: data, error: null as Object?);
      } on Object catch (error) {
        return (spec: spec, data: null as Map<String, dynamic>?, error: error);
      }
    }),
  );

  final succeeded = results.where((entry) => entry.data != null).toList();
  if (succeeded.isEmpty) {
    throw results.first.error ??
        http.ClientException('Không thể truy vấn Serper Maps.', _serperMapsUri);
  }

  final deduped = <String, Map<String, dynamic>>{};
  for (final entry in succeeded) {
    final rawPlaces = entry.data?['places'];
    if (rawPlaces is! List) {
      continue;
    }
    for (final raw in rawPlaces) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final placeLat = (raw['latitude'] as num?)?.toDouble();
      final placeLon = (raw['longitude'] as num?)?.toDouble();
      final name = (raw['title'] as String?)?.trim() ?? '';
      if (name.isEmpty ||
          placeLat == null ||
          placeLon == null ||
          !placeLat.isFinite ||
          !placeLon.isFinite) {
        continue;
      }
      final kind = _classifySerperKind(
        name: name,
        type: raw['type'] as String?,
        types: raw['types'] as List<dynamic>?,
        defaultKind: entry.spec.defaultKind,
      );
      if (kind == null) {
        continue;
      }
      final distanceKm = _haversineKm(latitude, longitude, placeLat, placeLon);
      if (distanceKm > radiusKm) {
        continue;
      }
      final dedupKey = _serperPlaceKey(raw, name, placeLat, placeLon);
      final phone = (raw['phoneNumber'] as String?)?.trim();
      final cleanPhone = (phone != null && phone.isNotEmpty) ? phone : null;
      final dialNumber = _sanitizeDialNumber(cleanPhone);
      final address = (raw['address'] as String?)?.trim() ?? '';
      final hours = _extractTodayHours(raw['openingHours']);
      final rating = (raw['rating'] as num?)?.toDouble();
      final ratingCount = (raw['ratingCount'] as num?)?.toInt();
      final placeId = (raw['placeId'] as String?)?.trim();

      deduped.putIfAbsent(dedupKey, () => {
        'kind': kind,
        'name': name,
        'address': address,
        'latitude': placeLat,
        'longitude': placeLon,
        'distance_km': double.parse(distanceKm.toStringAsFixed(2)),
        'phone': cleanPhone,
        'dial_number': dialNumber,
        'rating': rating,
        'rating_count': ratingCount,
        'hours': hours,
        'place_id': (placeId != null && placeId.isNotEmpty) ? placeId : null,
      });
    }
  }

  final places = deduped.values.toList()
    ..sort((a, b) {
      final distCmp = (a['distance_km'] as double).compareTo(
        b['distance_km'] as double,
      );
      if (distCmp != 0) {
        return distCmp;
      }
      return (a['name'] as String).compareTo(b['name'] as String);
    });

  return {
    'radius_km': radiusKm,
    'source': 'google_maps_serper',
    'cached': false,
    'places': places,
  };
}

String _serperPlaceKey(
  Map<String, dynamic> raw,
  String name,
  double lat,
  double lon,
) {
  for (final field in const ['placeId', 'cid', 'fid']) {
    final value = (raw[field] as String?)?.trim();
    if (value != null && value.isNotEmpty) {
      return '$field:$value';
    }
  }
  return '${name.toLowerCase()}:${lat.toStringAsFixed(4)}:${lon.toStringAsFixed(4)}';
}

String? _classifySerperKind({
  required String name,
  required String? type,
  required List<dynamic>? types,
  required String defaultKind,
}) {
  final nameLower = name.toLowerCase();
  final typeParts = <String>[
    ?type,
    if (types != null) ...types.whereType<String>(),
  ];
  final typesLower = typeParts.join(' ').toLowerCase();
  final combined = '$nameLower $typesLower';

  const animalExcludedTokens = [
    'thú y',
    'bệnh viện thú',
    'phòng khám thú',
    'veterinary',
    'animal hospital',
    'pet shop',
    'pet care',
    'grooming',
  ];
  if (animalExcludedTokens.any(combined.contains)) {
    return null;
  }

  const ignoredTokens = [
    'trường học',
    'school',
    'university',
    'nhà hàng',
    'restaurant',
    'cafe',
    'khách sạn',
    'hotel',
  ];
  const pharmacyTokens = [
    'nhà thuốc',
    'hiệu thuốc',
    'quầy thuốc',
    'pharmacy',
    'drugstore',
    'pharmacity',
    'long châu',
    'an khang',
  ];
  const hospitalTokens = [
    'bệnh viện',
    'phòng khám',
    'trung tâm y tế',
    'trạm y tế',
    'hospital',
    'clinic',
    'medical center',
    'emergency room',
    'đa khoa',
    'cấp cứu',
  ];

  final hasMedicalSignal =
      pharmacyTokens.any(combined.contains) ||
      hospitalTokens.any(combined.contains);
  if (ignoredTokens.any(combined.contains) && !hasMedicalSignal) {
    return null;
  }
  if (hospitalTokens.any(nameLower.contains) &&
      !nameLower.contains('nhà thuốc')) {
    return 'hospital';
  }
  if (pharmacyTokens.any(combined.contains)) {
    return 'pharmacy';
  }
  if (hospitalTokens.any(combined.contains)) {
    return 'hospital';
  }
  return defaultKind;
}

String? _extractTodayHours(dynamic openingHours) {
  if (openingHours is! Map) {
    return null;
  }
  const viDays = {
    DateTime.monday: ['Thứ Hai', 'Monday'],
    DateTime.tuesday: ['Thứ Ba', 'Tuesday'],
    DateTime.wednesday: ['Thứ Tư', 'Wednesday'],
    DateTime.thursday: ['Thứ Năm', 'Thursday'],
    DateTime.friday: ['Thứ Sáu', 'Friday'],
    DateTime.saturday: ['Thứ Bảy', 'Saturday'],
    DateTime.sunday: ['Chủ Nhật', 'Sunday'],
  };
  final candidates = viDays[DateTime.now().weekday] ?? const <String>[];
  for (final key in candidates) {
    final value = openingHours[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  for (final entry in openingHours.entries) {
    final value = entry.value;
    if (value is String && value.trim().isNotEmpty) {
      return '${entry.key}: ${value.trim()}';
    }
  }
  return null;
}

String? _sanitizeDialNumber(String? phone) {
  if (phone == null || phone.trim().isEmpty) {
    return null;
  }
  final trimmed = phone.trim();
  final buffer = StringBuffer();
  for (var i = 0; i < trimmed.length; i++) {
    final char = trimmed[i];
    if (char == '+' && buffer.isEmpty) {
      buffer.write(char);
    } else if (char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57) {
      buffer.write(char);
    }
  }
  final result = buffer.toString();
  return result.length >= 6 ? result : null;
}

Future<List<NearbyLocation>> _geocodeSerperLocations(
  http.Client client, {
  required String apiKey,
  required String address,
}) async {
  final data = await _postSerperMaps(
    client,
    apiKey: apiKey,
    body: {'q': address, 'gl': 'vn', 'hl': 'vi'},
  );
  final rawPlaces = data['places'];
  if (rawPlaces is! List) {
    return const [];
  }
  final seen = <String>{};
  final locations = <NearbyLocation>[];
  for (final raw in rawPlaces) {
    if (raw is! Map<String, dynamic>) {
      continue;
    }
    final lat = (raw['latitude'] as num?)?.toDouble();
    final lon = (raw['longitude'] as num?)?.toDouble();
    if (lat == null || lon == null || !lat.isFinite || !lon.isFinite) {
      continue;
    }
    final title = (raw['title'] as String?)?.trim() ?? '';
    final placeAddress = (raw['address'] as String?)?.trim() ?? '';
    final label = _composeLocationLabel(title, placeAddress);
    if (label.isEmpty) {
      continue;
    }
    final key = '${lat.toStringAsFixed(5)}:${lon.toStringAsFixed(5)}';
    if (!seen.add(key)) {
      continue;
    }
    locations.add(
      NearbyLocation(
        label: label,
        coordinates: {'latitude': lat, 'longitude': lon},
      ),
    );
    if (locations.length >= 5) {
      break;
    }
  }
  return locations;
}

Future<List<NearbyLocation>> _geocodePhotonLocations(
  http.Client client, {
  required String address,
}) async {
  final uri = _photonSearchUri.replace(
    queryParameters: {'q': address, 'limit': '5'},
  );
  final response = await client.get(uri).timeout(const Duration(seconds: 10));
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw http.ClientException(
      'Không thể tìm tọa độ từ địa chỉ (HTTP ${response.statusCode}).',
      uri,
    );
  }
  final decoded = jsonDecode(utf8.decode(response.bodyBytes));
  if (decoded is! Map<String, dynamic>) {
    return const [];
  }
  final features = decoded['features'];
  if (features is! List) {
    return const [];
  }
  final seen = <String>{};
  final locations = <NearbyLocation>[];
  for (final feature in features) {
    if (feature is! Map<String, dynamic>) {
      continue;
    }
    final geometry = feature['geometry'];
    final props = feature['properties'];
    if (geometry is! Map<String, dynamic> || props is! Map<String, dynamic>) {
      continue;
    }
    final coords = geometry['coordinates'];
    if (coords is! List || coords.length < 2) {
      continue;
    }
    final lon = (coords[0] as num?)?.toDouble();
    final lat = (coords[1] as num?)?.toDouble();
    if (lat == null || lon == null || !lat.isFinite || !lon.isFinite) {
      continue;
    }
    final label = _formatPhotonAddress(props);
    if (label.isEmpty) {
      continue;
    }
    final key = '${lat.toStringAsFixed(5)}:${lon.toStringAsFixed(5)}';
    if (!seen.add(key)) {
      continue;
    }
    locations.add(
      NearbyLocation(
        label: label,
        coordinates: {'latitude': lat, 'longitude': lon},
      ),
    );
  }
  return locations;
}

Future<Map<String, dynamic>> _searchPhotonNearbyPlaces(
  http.Client client, {
  required double latitude,
  required double longitude,
  required int radiusKm,
}) async {
  final queries = [
    (term: 'bệnh viện', kind: 'hospital'),
    (term: 'nhà thuốc', kind: 'pharmacy'),
  ];
  final responses = await Future.wait(
    queries.map((spec) async {
      try {
        final uri = _photonSearchUri.replace(
          queryParameters: {
            'q': spec.term,
            'lat': latitude.toStringAsFixed(6),
            'lon': longitude.toStringAsFixed(6),
            'limit': '15',
          },
        );
        final response = await client
            .get(uri)
            .timeout(const Duration(seconds: 10));
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return (
            spec: spec,
            ok: false,
            features: const <dynamic>[],
            error: http.ClientException(
              'Photon HTTP ${response.statusCode}',
              uri,
            ),
          );
        }
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final features =
            decoded is Map<String, dynamic> && decoded['features'] is List
            ? decoded['features'] as List<dynamic>
            : const <dynamic>[];
        return (
          spec: spec,
          ok: true,
          features: features,
          error: null as Object?,
        );
      } on Object catch (error) {
        return (
          spec: spec,
          ok: false,
          features: const <dynamic>[],
          error: error,
        );
      }
    }),
  );

  if (!responses.any((entry) => entry.ok)) {
    throw responses.first.error ??
        http.ClientException('Không thể kết nối dịch vụ tìm địa điểm.');
  }

  final deduped = <String, Map<String, dynamic>>{};
  for (final group in responses) {
    for (final feature in group.features) {
      if (feature is! Map<String, dynamic>) {
        continue;
      }
      final geometry = feature['geometry'];
      final props = feature['properties'];
      if (geometry is! Map<String, dynamic> ||
          props is! Map<String, dynamic>) {
        continue;
      }
      final coords = geometry['coordinates'];
      if (coords is! List || coords.length < 2) {
        continue;
      }
      final lon = (coords[0] as num?)?.toDouble();
      final lat = (coords[1] as num?)?.toDouble();
      final name = (props['name'] as String?)?.trim() ?? '';
      if (name.isEmpty ||
          lat == null ||
          lon == null ||
          !lat.isFinite ||
          !lon.isFinite) {
        continue;
      }
      final distanceKm = _haversineKm(latitude, longitude, lat, lon);
      if (distanceKm > radiusKm) {
        continue;
      }
      final key =
          '${name.toLowerCase()}:${lat.toStringAsFixed(4)}:${lon.toStringAsFixed(4)}';
      deduped.putIfAbsent(key, () => {
        'kind': group.spec.kind,
        'name': name,
        'address': _formatPhotonAddress(props, skipName: true),
        'latitude': lat,
        'longitude': lon,
        'distance_km': double.parse(distanceKm.toStringAsFixed(2)),
        'phone': null,
        'dial_number': null,
      });
    }
  }

  final places = deduped.values.toList()
    ..sort(
      (a, b) =>
          (a['distance_km'] as double).compareTo(b['distance_km'] as double),
    );
  return {
    'radius_km': radiusKm,
    'source': 'osm_photon',
    'cached': false,
    'places': places,
  };
}

String _composeLocationLabel(String title, String address) {
  if (title.isEmpty) {
    return address;
  }
  if (address.isEmpty || address.toLowerCase() == title.toLowerCase()) {
    return title;
  }
  if (address.toLowerCase().startsWith(title.toLowerCase())) {
    return address;
  }
  return '$title — $address';
}

String _formatPhotonAddress(
  Map<String, dynamic> props, {
  bool skipName = false,
}) {
  final parts = <String>[];
  final name = (props['name'] as String?)?.trim() ?? '';
  if (!skipName && name.isNotEmpty) {
    parts.add(name);
  }
  final house = (props['housenumber'] as String?)?.trim() ?? '';
  final street = (props['street'] as String?)?.trim() ?? '';
  final streetLine = [house, street].where((part) => part.isNotEmpty).join(' ');
  if (streetLine.isNotEmpty) {
    parts.add(streetLine);
  }
  for (final key in const ['district', 'suburb', 'city', 'county', 'state']) {
    final val = (props[key] as String?)?.trim() ?? '';
    if (val.isNotEmpty && !parts.contains(val)) {
      parts.add(val);
    }
  }
  return parts.join(', ');
}

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusKm = 6371.0;
  final dLat = _degToRad(lat2 - lat1);
  final dLon = _degToRad(lon2 - lon1);
  final a =
      math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_degToRad(lat1)) *
          math.cos(_degToRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return earthRadiusKm * c;
}

double _degToRad(double deg) => deg * (math.pi / 180.0);

Future<T> _requestNearby<T>(
  Map<String, Object> location,
  T Function(Map<String, dynamic>) parse, {
  http.Client? client,
  Uri? baseUrl,
}) async {
  final httpClient = client ?? http.Client();
  final target = (baseUrl ?? MedGemmaChatApi.defaultBaseUrl()).resolve(
    'api/nearby-places',
  );
  try {
    final response = await httpClient
        .post(
          target,
          headers: {'Content-Type': 'application/json; charset=utf-8'},
          body: jsonEncode(location),
        )
        .timeout(const Duration(seconds: 25));
    final json = jsonDecode(utf8.decode(response.bodyBytes));
    if (json is! Map<String, dynamic>) throw const FormatException();
    if (response.statusCode != 200) {
      throw NearbyPlacesException(
        json['error'] as String? ?? 'Chưa tìm được cơ sở y tế. Hãy thử lại.',
      );
    }
    return parse(json);
  } on TimeoutException {
    throw const NearbyPlacesException('Tìm kiếm quá lâu. Hãy thử lại.');
  } on http.ClientException {
    throw const NearbyPlacesException(
      'Chưa kết nối được máy chủ tra cứu (cổng 8765). Hãy khởi động backend Python rồi thử lại.',
    );
  } on FormatException {
    throw const NearbyPlacesException(
      'Máy chủ chưa trả về dữ liệu cơ sở y tế.',
    );
  } on ArgumentError {
    throw const NearbyPlacesException('Dữ liệu cơ sở y tế chưa hợp lệ.');
  } on TypeError {
    throw const NearbyPlacesException('Dữ liệu cơ sở y tế chưa hợp lệ.');
  } finally {
    if (client == null) {
      httpClient.close();
    }
  }
}
