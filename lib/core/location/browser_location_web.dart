import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'browser_position.dart';

bool get canUseBrowserLocation => web.window.isSecureContext;

Future<BrowserPosition> getBrowserLocation() async {
  try {
    final position = await _readPosition(precise: false);
    if (position.accuracyMeters.isFinite && position.accuracyMeters < 5000) {
      return position;
    }
  } on BrowserLocationFailure catch (error) {
    if (error == BrowserLocationFailure.denied) rethrow;
  }
  return _readPosition(precise: true);
}

Future<BrowserPosition> _readPosition({required bool precise}) {
  final result = Completer<BrowserPosition>();
  try {
    web.window.navigator.geolocation.getCurrentPosition(
      ((web.GeolocationPosition position) {
        result.complete((
          latitude: position.coords.latitude,
          longitude: position.coords.longitude,
          accuracyMeters: position.coords.accuracy,
        ));
      }).toJS,
      ((web.GeolocationPositionError error) {
        result.completeError(switch (error.code) {
          1 => BrowserLocationFailure.denied,
          3 => BrowserLocationFailure.timedOut,
          _ => BrowserLocationFailure.unavailable,
        });
      }).toJS,
      web.PositionOptions(
        enableHighAccuracy: precise,
        timeout: precise ? 12000 : 6000,
        maximumAge: precise ? 0 : 60000,
      ),
    );
  } catch (_) {
    result.completeError(BrowserLocationFailure.unavailable);
  }
  return result.future.timeout(
    const Duration(seconds: 15),
    onTimeout: () => throw BrowserLocationFailure.timedOut,
  );
}
