import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'medgemma_chat_api.dart';

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
      dialNumber = json['dial_number'] as String?;

  final HealthFacilityType type;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double distanceKm;
  final String? phone;
  final String? dialNumber;
}

class NearbyPlacesResult {
  NearbyPlacesResult.fromJson(Map<String, dynamic> json)
    : radiusKm = (json['radius_km'] as num).toDouble(),
      places = (json['places'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(NearbyPlace.fromJson)
          .toList(growable: false);

  final double radiusKm;
  final List<NearbyPlace> places;
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

Future<NearbyPlacesResult> findNearbyPlaces(
  NearbyLocation location, {
  required int radiusKm,
}) => _requestNearby({
  ...location.coordinates,
  'radius_km': radiusKm,
}, NearbyPlacesResult.fromJson);

Future<List<NearbyLocation>> findNearbyLocations(String address) =>
    _requestNearby({'address': address}, (json) {
      return (json['locations'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(NearbyLocation.fromJson)
          .toList(growable: false);
    });

Future<T> _requestNearby<T>(
  Map<String, Object> location,
  T Function(Map<String, dynamic>) parse,
) async {
  try {
    final response = await http
        .post(
          MedGemmaChatApi.defaultBaseUrl().resolve('api/nearby-places'),
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
    throw const NearbyPlacesException('Chưa kết nối được máy chủ tra cứu.');
  } on FormatException {
    throw const NearbyPlacesException(
      'Máy chủ chưa trả về dữ liệu cơ sở y tế.',
    );
  } on ArgumentError {
    throw const NearbyPlacesException('Dữ liệu cơ sở y tế chưa hợp lệ.');
  } on TypeError {
    throw const NearbyPlacesException('Dữ liệu cơ sở y tế chưa hợp lệ.');
  }
}
