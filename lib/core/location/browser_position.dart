typedef BrowserPosition = ({
  double latitude,
  double longitude,
  double accuracyMeters,
});

enum BrowserLocationFailure implements Exception {
  denied,
  unavailable,
  timedOut,
}
