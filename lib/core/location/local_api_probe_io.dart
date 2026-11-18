import 'dart:io';

Future<bool> isLocalApiReachable(Uri baseUri) async {
  final host = baseUri.host.toLowerCase();
  if (host != '127.0.0.1' && host != 'localhost' && host != '::1') {
    return true;
  }
  final port = baseUri.hasPort
      ? baseUri.port
      : (baseUri.scheme == 'https' ? 443 : 80);
  try {
    final socket = await Socket.connect(
      baseUri.host,
      port,
      timeout: const Duration(milliseconds: 250),
    );
    socket.destroy();
    return true;
  } on Object {
    return false;
  }
}
