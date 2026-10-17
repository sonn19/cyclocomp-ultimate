import 'dart:math';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:xml/xml.dart';

class RideRoute {
  final String name;
  final List<LatLng> points;
  const RideRoute(this.name, this.points);
}

Future<RideRoute?> chooseGpxRoute() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom, allowedExtensions: ['gpx'], withData:true,
  );
  if(result == null || result.files.isEmpty) return null;
  final file = result.files.first;
  if(file.bytes == null) throw const FormatException('File GPX tidak dapat dibaca.');
  final document = XmlDocument.parse(String.fromCharCodes(file.bytes!));
  final nodes = document.descendants.whereType<XmlElement>().where(
    (e) => e.name.local == 'trkpt' || e.name.local == 'rtept',
  );
  final points = <LatLng>[];
  for(final node in nodes) {
    final lat = double.tryParse(node.getAttribute('lat') ?? '');
    final lon = double.tryParse(node.getAttribute('lon') ?? '');
    if(lat != null && lon != null && lat.isFinite && lon.isFinite &&
       lat.abs() <= 90 && lon.abs() <= 180) {
      points.add(LatLng(lat,lon));
    }
    if(points.length >= 20000) break;
  }
  if(points.length < 2) throw const FormatException('GPX tidak berisi jalur yang valid.');
  return RideRoute(file.name, points);
}

/// Approximation in meters to nearest recorded route waypoint.
double distanceToRoute(LatLng position, List<LatLng> points) {
  if(points.isEmpty) return double.infinity;
  const measure = Distance();
  var closest = double.infinity;
  for(var i = 0; i < points.length; i += max(1,points.length ~/ 800)) {
    closest = min(closest, measure.as(LengthUnit.Meter, position, points[i]));
  }
  return closest;
}
