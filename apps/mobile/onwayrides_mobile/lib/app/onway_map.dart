import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'onway_models.dart';
import 'onway_theme.dart';

class OnWayMapMarkerSpec {
  const OnWayMapMarkerSpec({
    required this.coordinate,
    required this.icon,
    required this.label,
    this.color = OnWayTheme.yellow,
    this.size = 44,
  });

  final OnWayCoordinate coordinate;
  final IconData icon;
  final String label;
  final Color color;
  final double size;
}

Future<OnWayCoordinate?> tryResolveCurrentLocation() async {
  final serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return null;
  }

  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return null;
  }

  final position = await Geolocator.getCurrentPosition(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
  );

  return OnWayCoordinate(
    latitude: position.latitude,
    longitude: position.longitude,
  );
}

LatLng toLatLng(OnWayCoordinate coordinate) {
  return LatLng(coordinate.latitude, coordinate.longitude);
}

String compactCoordinateLabel(OnWayCoordinate coordinate) {
  return '${coordinate.latitude.toStringAsFixed(4)}, ${coordinate.longitude.toStringAsFixed(4)}';
}

List<OnWayCoordinate> buildRoutePath(
  OnWayCoordinate start,
  OnWayCoordinate end,
) {
  final latDelta = end.latitude - start.latitude;
  final lngDelta = end.longitude - start.longitude;
  final midpoint = OnWayCoordinate(
    latitude: start.latitude + (latDelta / 2) + (lngDelta * 0.08),
    longitude: start.longitude + (lngDelta / 2) - (latDelta * 0.08),
  );

  return [start, midpoint, end];
}

class OnWayMapSurface extends StatefulWidget {
  const OnWayMapSurface({
    super.key,
    required this.markers,
    this.route = const [],
    this.height = 280,
    this.onTap,
    this.overlay,
    this.interactive = true,
    this.backgroundColor = const Color(0xFF132321),
  });

  final List<OnWayMapMarkerSpec> markers;
  final List<OnWayCoordinate> route;
  final double height;
  final ValueChanged<OnWayCoordinate>? onTap;
  final Widget? overlay;
  final bool interactive;
  final Color backgroundColor;

  @override
  State<OnWayMapSurface> createState() => _OnWayMapSurfaceState();
}

class _OnWayMapSurfaceState extends State<OnWayMapSurface> {
  final _controller = MapController();

  List<OnWayCoordinate> get _focusCoordinates => [
    ...widget.route,
    ...widget.markers.map((marker) => marker.coordinate),
  ];

  @override
  void didUpdateWidget(covariant OnWayMapSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.markers != widget.markers ||
        oldWidget.route != widget.route) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitCamera());
    }
  }

  void _fitCamera() {
    final points = _focusCoordinates.map(toLatLng).toList(growable: false);
    if (points.isEmpty) {
      return;
    }

    if (points.length == 1) {
      _controller.move(points.first, 14.2);
      return;
    }

    _controller.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        padding: const EdgeInsets.all(48),
        maxZoom: 15,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final points = _focusCoordinates.map(toLatLng).toList(growable: false);
    final initialCenter = points.isEmpty
        ? const LatLng(31.5204, 74.3587)
        : points.first;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter: initialCenter,
                initialZoom: 13.4,
                initialCameraFit: points.length > 1
                    ? CameraFit.coordinates(
                        coordinates: points,
                        padding: const EdgeInsets.all(48),
                        maxZoom: 15,
                      )
                    : null,
                interactionOptions: InteractionOptions(
                  flags: widget.interactive
                      ? InteractiveFlag.all
                      : InteractiveFlag.none,
                ),
                backgroundColor: widget.backgroundColor,
                onMapReady: _fitCamera,
                onTap: widget.onTap == null
                    ? null
                    : (_, point) => widget.onTap!(
                        OnWayCoordinate(
                          latitude: point.latitude,
                          longitude: point.longitude,
                        ),
                      ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.onway.rides',
                ),
                if (widget.route.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: widget.route
                            .map(toLatLng)
                            .toList(growable: false),
                        strokeWidth: 5,
                        color: OnWayTheme.yellow,
                      ),
                    ],
                  ),
                if (widget.markers.isNotEmpty)
                  MarkerLayer(
                    markers: widget.markers
                        .map(
                          (marker) => Marker(
                            point: toLatLng(marker.coordinate),
                            width: marker.size,
                            height: marker.size + 18,
                            child: _MapMarker(marker: marker),
                          ),
                        )
                        .toList(growable: false),
                  ),
              ],
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: IconButton(
                  onPressed: _fitCamera,
                  icon: const Icon(Icons.center_focus_strong_rounded),
                ),
              ),
            ),
            if (widget.overlay != null) Positioned.fill(child: widget.overlay!),
          ],
        ),
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.marker});

  final OnWayMapMarkerSpec marker;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: marker.size,
          height: marker.size,
          decoration: BoxDecoration(
            color: marker.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.28),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(marker.icon, color: OnWayTheme.black, size: 22),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            marker.label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
