import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Exports one saved ride's actual GPS points; no fabricated route data.
Future<void> shareRideGpx(Map<String, dynamic> ride) async {
  final raw = ride['track'];
  if (raw is! List || raw.isEmpty) {
    throw StateError('Perjalanan ini tidak memiliki titik GPS untuk diekspor.');
  }

  final xml = StringBuffer()
    ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
    ..writeln('<gpx version="1.1" creator="CycloComp Ultimate" xmlns="http://www.topografix.com/GPX/1/1">')
    ..writeln('  <trk><name>CycloComp Ride</name><trkseg>');

  var valid = 0;
  for (final item in raw) {
    if (item is! Map) continue;
    final lat = item['lat'];
    final lon = item['lon'];
    if (lat is! num || lon is! num ||
        !lat.isFinite || !lon.isFinite ||
        lat < -90 || lat > 90 || lon < -180 || lon > 180) continue;
    final altitude = item['alt'];
    final time = DateTime.tryParse('${item['time'] ?? ''}')?.toUtc();
    xml.write('    <trkpt lat="${lat.toString()}" lon="${lon.toString()}">');
    if (altitude is num && altitude.isFinite) {
      xml.write('<ele>${altitude.toString()}</ele>');
    }
    if (time != null) {
      xml.write('<time>${time.toIso8601String()}</time>');
    }
    xml.writeln('</trkpt>');
    valid++;
  }
  xml..writeln('  </trkseg></trk>')..writeln('</gpx>');
  if (valid == 0) throw StateError('Tidak ada titik GPS valid untuk diekspor.');

  final directory = await getTemporaryDirectory();
  final start = DateTime.tryParse('${ride['started'] ?? ''}') ?? DateTime.now();
  final date = start.toIso8601String().replaceAll(':', '-').split('.').first;
  final file = File('${directory.path}/CycloComp-$date.gpx');
  await file.writeAsString(xml.toString(), flush: true);
  await Share.shareXFiles([XFile(file.path, mimeType: 'application/gpx+xml')],
      text: 'Rute gowes CycloComp Ultimate');
}
