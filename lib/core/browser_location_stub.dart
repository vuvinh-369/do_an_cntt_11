import 'browser_position.dart';

bool get canUseBrowserLocation => false;

Future<BrowserPosition> getBrowserLocation() async =>
    throw BrowserLocationFailure.unavailable;
