import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:do_an_cntt_11/core/nearby_places_api.dart';
import 'package:do_an_cntt_11/features/user/views/widgets/nearby_places_dialog.dart';

void main() {
  test('parseCoordinatesInput handles plain coordinates and Google Maps URLs', () {
    final plain = parseCoordinatesInput('10.7725, 106.6980');
    expect(plain, isNotNull);
    expect(plain!.latitude, closeTo(10.7725, 0.0001));
    expect(plain.longitude, closeTo(106.6980, 0.0001));
    expect(plain.fromMapsLink, isFalse);

    final atLink = parseCoordinatesInput(
      'https://www.google.com/maps/place/Cho+Ben+Thanh/@10.7725,106.6980,17z',
    );
    expect(atLink, isNotNull);
    expect(atLink!.fromMapsLink, isTrue);
    expect(atLink.latitude, closeTo(10.7725, 0.0001));

    final placeDataLink = parseCoordinatesInput(
      'https://www.google.com/maps/place/...!3d21.0285!4d105.8542',
    );
    expect(placeDataLink, isNotNull);
    expect(placeDataLink!.latitude, closeTo(21.0285, 0.0001));
    expect(placeDataLink.longitude, closeTo(105.8542, 0.0001));

    expect(parseCoordinatesInput('95.0, 106.7'), isNull);
    expect(isPlainCoordinateText('95.0, 106.7'), isTrue);
  });

  test('findNearbyPlaces parses Serper Google Maps metadata cleanly', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/nearby-places');
      return http.Response(
        jsonEncode({
          'radius_km': 5,
          'source': 'google_maps_serper',
          'cached': false,
          'places': [
            {
              'kind': 'pharmacy',
              'name': 'Nhà thuốc 24H',
              'address': '18B Nguyễn Thị Minh Khai, TP.HCM',
              'latitude': 10.7856,
              'longitude': 106.7005,
              'distance_km': 1.46,
              'phone': '+84 903 490 579',
              'dial_number': '+84903490579',
              'rating': 4.8,
              'rating_count': 102,
              'hours': 'Mở cửa cả ngày',
              'place_id': 'ChIJo6KcD0QvdTERPIeoLegkmoQ',
            },
          ],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });

    final result = await findNearbyPlaces(
      const NearbyLocation(
        label: 'Test',
        coordinates: {'latitude': 10.77, 'longitude': 106.70},
      ),
      radiusKm: 5,
      client: client,
      baseUrl: Uri.parse('http://127.0.0.1:8765/'),
    );

    expect(result.isGoogleMaps, isTrue);
    expect(result.places.single.type, HealthFacilityType.pharmacy);
    expect(result.places.single.rating, 4.8);
    expect(result.places.single.ratingCount, 102);
    expect(result.places.single.hours, 'Mở cửa cả ngày');
    expect(result.places.single.placeId, 'ChIJo6KcD0QvdTERPIeoLegkmoQ');
  });

  testWidgets('NearbyPlacesDialog auto-searches single location and renders Google Maps card', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NearbyPlacesDialog(
            fetchLocations: (address) async => const [
              NearbyLocation(
                label: 'Chợ Bến Thành, TP.HCM',
                coordinates: {'latitude': 10.7725, 'longitude': 106.6980},
              ),
            ],
            fetchPlaces: (location, {required radiusKm}) async =>
                NearbyPlacesResult.fromJson({
                  'radius_km': radiusKm,
                  'source': 'google_maps_serper',
                  'places': [
                    {
                      'kind': 'hospital',
                      'name': 'Bệnh viện Khánh Hội',
                      'address': '63 Bến Vân Đồn',
                      'latitude': 10.7653,
                      'longitude': 106.7021,
                      'distance_km': 0.92,
                      'phone': '+84 28 3826 1596',
                      'dial_number': '+842838261596',
                      'rating': 4.2,
                      'rating_count': 401,
                      'hours': 'Mở cửa cả ngày',
                    },
                    {
                      'kind': 'pharmacy',
                      'name': 'Nhà thuốc Minh Châu',
                      'address': '12 Lê Lợi',
                      'latitude': 10.7730,
                      'longitude': 106.6990,
                      'distance_km': 0.15,
                      'phone': null,
                      'dial_number': null,
                    },
                  ],
                }),
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Chợ Bến Thành');
    await tester.pump();
    await tester.tap(find.text('Tìm theo địa chỉ'));
    await tester.pumpAndSettle();

    expect(find.text('Bệnh viện Khánh Hội'), findsOneWidget);
    expect(find.text('Nhà thuốc Minh Châu'), findsOneWidget);
    expect(find.text('Hôm nay: Mở cửa cả ngày'), findsOneWidget);
    expect(find.text('Dữ liệu Google Maps (qua Serper)'), findsOneWidget);

    await tester.tap(find.text('Nhà thuốc'));
    await tester.pumpAndSettle();
    expect(find.text('Bệnh viện Khánh Hội'), findsNothing);
    expect(find.text('Nhà thuốc Minh Châu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test(
    'findNearbyPlacesDirect queries Serper in parallel, filters/dedups, and caches',
    () async {
      clearDirectSerperCache();
      addTearDown(clearDirectSerperCache);

      final queriesSeen = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        expect(request.url.toString(), 'https://google.serper.dev/maps');
        expect(request.headers['X-API-KEY'], 'test-serper-key');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        queriesSeen.add(body);
        final query = body['q'] as String;

        if (query == 'bệnh viện') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'places': [
                  {
                    'placeId': 'pid-hosp-1',
                    'title': 'Bệnh viện Chợ Rẫy',
                    'address': '201B Nguyễn Chí Thanh, TP.HCM',
                    'latitude': 10.7575,
                    'longitude': 106.6596,
                    'phoneNumber': '+84 28 3855 4137',
                    'rating': 4.1,
                    'ratingCount': 1200,
                    'openingHours': {
                      'Thứ Hai': 'Mở cửa cả ngày',
                      'Thứ Ba': 'Mở cửa cả ngày',
                      'Thứ Tư': 'Mở cửa cả ngày',
                      'Thứ Năm': 'Mở cửa cả ngày',
                      'Thứ Sáu': 'Mở cửa cả ngày',
                      'Thứ Bảy': 'Mở cửa cả ngày',
                      'Chủ Nhật': 'Mở cửa cả ngày',
                    },
                    'type': 'Bệnh viện',
                  },
                  {
                    'placeId': 'pid-vet',
                    'title': 'Phòng khám Thú y Pet Care',
                    'address': '100 Đường 3/2',
                    'latitude': 10.7701,
                    'longitude': 106.6901,
                    'type': 'Bác sĩ thú y',
                  },
                ],
              }),
            ),
            200,
          );
        }
        if (query == 'phòng khám') {
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'places': [
                  {
                    'placeId': 'pid-hosp-1',
                    'title': 'Bệnh viện Chợ Rẫy (trùng)',
                    'address': '201B Nguyễn Chí Thanh',
                    'latitude': 10.7575,
                    'longitude': 106.6596,
                  },
                  {
                    'placeId': 'pid-far',
                    'title': 'Bệnh viện Quá Xa',
                    'address': 'Xa hơn 10km',
                    'latitude': 10.9000,
                    'longitude': 106.9000,
                  },
                ],
              }),
            ),
            200,
          );
        }
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'places': [
                {
                  'placeId': 'pid-pharm-1',
                  'title': 'Nhà thuốc Bệnh viện Chợ Rẫy',
                  'address': '201B Nguyễn Chí Thanh',
                  'latitude': 10.7578,
                  'longitude': 106.6601,
                  'phoneNumber': '028 3855 0000',
                  'type': 'Hiệu thuốc',
                },
              ],
            }),
          ),
          200,
        );
      });

      const origin = NearbyLocation(
        label: 'Test origin',
        coordinates: {'latitude': 10.7580, 'longitude': 106.6600},
      );
      final first = await findNearbyPlacesDirect(
        origin,
        radiusKm: 5,
        client: client,
        apiKey: 'test-serper-key',
      );

      expect(queriesSeen.length, 3);
      expect(
        queriesSeen.firstWhere((q) => q['q'] == 'bệnh viện')['ll'],
        '@10.758000,106.660000,14z',
      );
      expect(
        queriesSeen.firstWhere((q) => q['q'] == 'nhà thuốc')['ll'],
        '@10.758000,106.660000,15z',
      );

      expect(first.isGoogleMaps, isTrue);
      expect(first.places.map((p) => p.name).toList(), [
        'Nhà thuốc Bệnh viện Chợ Rẫy',
        'Bệnh viện Chợ Rẫy',
      ]);
      expect(first.places[0].type, HealthFacilityType.pharmacy);
      expect(first.places[0].dialNumber, '02838550000');
      expect(first.places[1].type, HealthFacilityType.hospital);
      expect(first.places[1].hours, 'Mở cửa cả ngày');

      final second = await findNearbyPlacesDirect(
        origin,
        radiusKm: 5,
        client: client,
        apiKey: 'test-serper-key',
      );
      expect(second.places.length, 2);
      expect(queriesSeen.length, 3);
    },
  );

  test(
    'findNearbyPlacesDirect falls back to Photon when Serper fails',
    () async {
      clearDirectSerperCache();
      addTearDown(clearDirectSerperCache);

      final client = MockClient((request) async {
        if (request.url.host == 'google.serper.dev') {
          return http.Response('Internal error', 500);
        }
        expect(request.url.host, 'photon.komoot.io');
        final q = request.url.queryParameters['q'];
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'features': [
                {
                  'geometry': {
                    'coordinates': [106.7001, 10.7726],
                  },
                  'properties': {
                    'name': q == 'nhà thuốc'
                        ? 'Nhà thuốc Dự Phòng'
                        : 'Bệnh viện Dự Phòng',
                    'housenumber': '12A',
                    'street': 'Lê Lợi',
                    'district': 'Quận 1',
                  },
                },
              ],
            }),
          ),
          200,
        );
      });

      final result = await findNearbyPlacesDirect(
        const NearbyLocation(
          label: 'Q1',
          coordinates: {'latitude': 10.7725, 'longitude': 106.7000},
        ),
        radiusKm: 5,
        client: client,
        apiKey: 'test-serper-key',
      );

      expect(result.isGoogleMaps, isFalse);
      expect(result.places.length, 2);
      expect(result.places.first.address, contains('12A Lê Lợi'));
    },
  );

  test(
    'findNearbyLocationsDirect geocodes via Serper and falls back to Photon',
    () async {
      clearDirectSerperCache();
      addTearDown(clearDirectSerperCache);

      var failSerper = false;
      final client = MockClient((request) async {
        if (request.url.host == 'google.serper.dev') {
          if (failSerper) {
            return http.Response('Upstream error', 502);
          }
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'places': [
                  {
                    'title': 'Chợ Bến Thành',
                    'address': 'Lê Lợi, Quận 1, TP.HCM',
                    'latitude': 10.7725,
                    'longitude': 106.6980,
                  },
                ],
              }),
            ),
            200,
          );
        }
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'features': [
                {
                  'geometry': {
                    'coordinates': [105.8542, 21.0285],
                  },
                  'properties': {
                    'name': 'Hồ Hoàn Kiếm',
                    'housenumber': '1',
                    'street': 'Đinh Tiên Hoàng',
                    'city': 'Hà Nội',
                  },
                },
              ],
            }),
          ),
          200,
        );
      });

      final serperRes = await findNearbyLocationsDirect(
        'Chợ Bến Thành',
        client: client,
        apiKey: 'test-serper-key',
      );
      expect(serperRes.single.label, 'Chợ Bến Thành — Lê Lợi, Quận 1, TP.HCM');
      expect(serperRes.single.coordinates['latitude'], closeTo(10.7725, 0.0001));

      failSerper = true;
      final photonRes = await findNearbyLocationsDirect(
        'Hồ Hoàn Kiếm',
        client: client,
        apiKey: 'test-serper-key',
      );
      expect(photonRes.single.label, contains('1 Đinh Tiên Hoàng'));
    },
  );
}
