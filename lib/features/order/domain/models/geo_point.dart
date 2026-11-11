import 'package:latlong2/latlong.dart';

/// A plain coordinate pair.
///
/// The map UI runs on flutter_map/OpenStreetMap, but the location layer still
/// spoke in geolocator's `Position` (a sensor reading with accuracy, heading and
/// speed fields that were always filled with dummy values) and Google Maps'
/// `LatLng`/`CameraPosition`. Both native plugins were dead weight — the Maps
/// SDK could never even initialise, since the manifest API key was the literal
/// placeholder `map_api_key_here`.
class GeoPoint {
  final double latitude;
  final double longitude;

  const GeoPoint({required this.latitude, required this.longitude});

  static const GeoPoint zero = GeoPoint(latitude: 0, longitude: 0);

  LatLng toLatLng() => LatLng(latitude, longitude);

  factory GeoPoint.fromLatLng(LatLng latLng) =>
      GeoPoint(latitude: latLng.latitude, longitude: latLng.longitude);

  @override
  String toString() => 'GeoPoint($latitude, $longitude)';

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// What the map is currently centred on. Replaces Google Maps' CameraPosition.
class MapCameraPosition {
  final GeoPoint target;
  final double zoom;

  const MapCameraPosition({required this.target, this.zoom = 16});
}
