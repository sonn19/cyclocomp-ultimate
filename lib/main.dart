import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const CycloCompApp());

class CycloCompApp extends StatelessWidget {
  const CycloCompApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'CycloComp Ultimate',
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark(useMaterial3: true),
    home: const RidePage(),
  );
}

class RidePage extends StatefulWidget {
  const RidePage({super.key});
  @override
  State<RidePage> createState() => _RidePageState();
}

class _RidePageState extends State<RidePage> {
  StreamSubscription<Position>? gps;
  Timer? timer;
  Position? previous;
  DateTime? started;
  bool recording = false, paused = false, starting = false;
  double speed = 0, maxSpeed = 0, distance = 0, altitude = 0;
  int seconds = 0;
  String status = 'GPS siap';
  final List<Map<String, dynamic>> track = [];
  List<Map<String, dynamic>> rides = [];

  @override
  void initState() { super.initState(); loadRides(); }

  Future<void> loadRides() async {
    final p = await SharedPreferences.getInstance();
    final entries = p.getStringList('rides') ?? [];
    if (mounted) setState(() => rides = entries.map((e) => Map<String,dynamic>.from(jsonDecode(e) as Map)).toList());
  }

  Future<void> startRide() async {
    if (starting || recording) return;
    setState(() { starting = true; status = 'Memeriksa izin GPS...'; });
    try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      setState(() => status = 'Lokasi HP mati. Aktifkan Lokasi/GPS lalu coba lagi.'); return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      setState(() => status = 'Izinkan lokasi untuk CycloComp di pengaturan Android.'); return;
    }
    await gps?.cancel();
    timer?.cancel();
    setState(() {
      recording = true; paused = false; previous = null;
      speed = 0; maxSpeed = 0; distance = 0; altitude = 0; seconds = 0;
      started = DateTime.now(); track.clear(); status = 'Merekam — menunggu titik GPS pertama. Uji di luar ruangan.';
    });
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && recording && !paused) setState(() => seconds++);
    });
    gps = Geolocator.getPositionStream(locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 0,
    )).listen((p) {
      if (!mounted || !recording || paused) return;
      if (p.accuracy > 100) { setState(() => status = 'GPS belum akurat (±\${p.accuracy.toStringAsFixed(0)} m). Coba area terbuka.'); return; }
      final nextSpeed = max(0.0, p.speed * 3.6);
      if (nextSpeed > 100) return;
      if (previous != null) {
        final dt = p.timestamp.difference(previous!.timestamp).inMilliseconds / 1000;
        final meters = Geolocator.distanceBetween(previous!.latitude, previous!.longitude, p.latitude, p.longitude);
        if (dt > 0 && meters / dt <= 28 && meters < 150) distance += meters;
      }
      previous = p;
      track.add({'lat':p.latitude,'lon':p.longitude,'time':p.timestamp.toIso8601String(),'alt':p.altitude});
      setState(() { speed = nextSpeed < 1 ? 0 : nextSpeed; maxSpeed = max(maxSpeed,speed); altitude = p.altitude; status = 'GPS aktif • \${track.length} titik • akurasi ±\${p.accuracy.toStringAsFixed(0)} m'; });
    }, onError: (Object e) { if (mounted) setState(() => status = 'GPS error: $e'); });
    } catch (e) {
      await gps?.cancel(); timer?.cancel();
      if (mounted) setState(() { recording = false; status = 'Gagal mulai merekam: $e'; });
    } finally {
      if (mounted) setState(() => starting = false);
    }
  }

  void togglePause() => setState(() { paused = !paused; previous = null; speed = 0; });

  Future<void> finishRide() async {
    await gps?.cancel(); timer?.cancel();
    if (!recording) return;
    final entry = {'started':started?.toIso8601String(), 'distanceKm':distance/1000,
      'maxSpeed':maxSpeed, 'movingSeconds':seconds, 'track':List<Map<String,dynamic>>.from(track)};
    final p = await SharedPreferences.getInstance();
    final current = p.getStringList('rides') ?? [];
    current.insert(0,jsonEncode(entry));
    await p.setStringList('rides',current);
    if (mounted) setState(() { recording = false; paused = false; speed = 0; status = 'Perjalanan disimpan'; });
    await loadRides();
  }

  @override
  void dispose() { gps?.cancel(); timer?.cancel(); super.dispose(); }

  String get duration {
    final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = seconds % 60;
    return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}:${s.toString().padLeft(2,'0')}';
  }

  Widget metric(String title, String value) => Card(child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(title,style:const TextStyle(color:Colors.white70)),const SizedBox(height:8),
      Text(value,style:const TextStyle(fontSize:23,fontWeight:FontWeight.bold)),
    ]),
  ));

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title:const Text('🚴 CycloComp Ultimate')),
    body: ListView(padding:const EdgeInsets.all(16),children:[
      Text(status,style:const TextStyle(color:Colors.greenAccent)),
      if (recording) Text(paused ? 'Dijeda — perjalanan belum dihentikan' : '● REKAM AKTIF — waktu terus berjalan meskipun belum bergerak',style:const TextStyle(color:Colors.orangeAccent)),
      const SizedBox(height:20),
      const Center(child:Text('KECEPATAN GPS')),
      Center(child:Text(speed.toStringAsFixed(1),style:const TextStyle(fontSize:86,fontWeight:FontWeight.bold))),
      const Center(child:Text('km/jam')),
      const SizedBox(height:20),
      Row(children:[
        Expanded(child:metric('JARAK','${(distance/1000).toStringAsFixed(2)} km')),
        Expanded(child:metric('WAKTU',duration)),
      ]),
      Row(children:[
        Expanded(child:metric('MAX SPEED','${maxSpeed.toStringAsFixed(1)} km/h')),
        Expanded(child:metric('ELEVASI','${altitude.toStringAsFixed(0)} m')),
      ]),
      const SizedBox(height:12),
      if (!recording) FilledButton(onPressed:starting ? null : startRide,child:Text(starting ? 'MENYIAPKAN GPS...' : 'MULAI GOWES')),
      if (recording) Row(children:[
        Expanded(child:OutlinedButton(onPressed:togglePause,child:Text(paused?'LANJUTKAN':'JEDA'))),
        const SizedBox(width:12),
        Expanded(child:FilledButton(onPressed:finishRide,child:const Text('SELESAI'))),
      ]),
      const SizedBox(height:24),
      Text('Riwayat Gowes',style:Theme.of(context).textTheme.titleLarge),
      for (final r in rides.take(20)) ListTile(
        leading:const Icon(Icons.route),
        title:Text('${((r['distanceKm'] as num?)??0).toStringAsFixed(2)} km'),
        subtitle:Text('${r['started']??'-'}'),
      ),
    ]),
  );
}
