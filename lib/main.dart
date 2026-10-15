import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'account_page.dart';
import 'gpx_export.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geolocator_android/geolocator_android.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('CYCLOCOMP_AUTH_ENABLED', defaultValue: false);
  const url = String.fromEnvironment('SUPABASE_URL');
  const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (enabled && url.isNotEmpty && anonKey.isNotEmpty) {
    await Supabase.initialize(url: url, anonKey: anonKey);
  }
  runApp(const CycloCompApp());
}

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
  int currentTab = 0;
  int movingSeconds = 0;
  DateTime? previousFixTime;
  DateTime? lastBackupAt;
  bool finishing = false;
  bool keepScreenOn = false;
  double? gpsAccuracy;
  DateTime? lastResumeAt;
  DateTime? pausedAt;
  Duration pausedDuration = Duration.zero;
  LatLng? currentPoint;
  String status = 'GPS siap';
  final List<Map<String, dynamic>> track = [];
  List<Map<String, dynamic>> rides = [];

  @override
  void initState() { super.initState(); loadRides(); recoverInterruptedRide(); restoreScreenPreference(); }

  Future<void> restoreScreenPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('keep_screen_on') ?? false;
    await WakelockPlus.toggle(enable: enabled);
    if (mounted) setState(() => keepScreenOn = enabled);
  }

  Future<void> toggleScreenOn(bool enabled) async {
    try {
      await WakelockPlus.toggle(enable: enabled);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('keep_screen_on', enabled);
      if (mounted) setState(() => keepScreenOn = enabled);
    } catch (e) {
      if (mounted) setState(() => status = 'Gagal mengatur layar: $e');
    }
  }

  Future<void> loadRides() async {
    final p = await SharedPreferences.getInstance();
    final entries = p.getStringList('rides') ?? [];
    if (mounted) setState(() => rides = entries.map((e) => Map<String,dynamic>.from(jsonDecode(e) as Map)).toList());
  }

  Map<String, dynamic> get rideSnapshot => {
    'started': started?.toIso8601String(),
    'distanceKm': distance / 1000,
    'maxSpeed': maxSpeed,
    'elapsedSeconds': started == null ? seconds : DateTime.now().difference(started!).inSeconds,
    'movingSeconds': movingSeconds,
    'track': List<Map<String, dynamic>>.from(track),
  };

  Future<void> saveDraft() async {
    if (!recording) return;
    final p = await SharedPreferences.getInstance();
    await p.setString('active_ride_backup', jsonEncode(rideSnapshot));
  }

  Future<void> recoverInterruptedRide() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('active_ride_backup');
    if (raw == null) return;
    try {
      final recovered = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      recovered['interrupted'] = true;
      recovered['recoveredAt'] = DateTime.now().toIso8601String();
      final current = p.getStringList('rides') ?? [];
      current.insert(0, jsonEncode(recovered));
      await p.setStringList('rides', current);
      await p.remove('active_ride_backup');
      if (mounted) setState(() {
        rides = current.map((e) => Map<String, dynamic>.from(jsonDecode(e) as Map)).toList();
        status = 'Perjalanan sebelumnya dipulihkan dari backup (mungkin tidak lengkap).';
      });
    } catch (_) {
      if (mounted) setState(() => status = 'Backup perjalanan gagal dibaca; data backup tidak dihapus.');
    }
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
      started = DateTime.now(); lastResumeAt = started; pausedAt = null; pausedDuration = Duration.zero;
      currentPoint = null; movingSeconds = 0; previousFixTime = null; lastBackupAt = null;
      gpsAccuracy = null;
      track.clear(); status = 'Merekam — menunggu titik GPS pertama. Uji di luar ruangan.';
    });
    await saveDraft();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !recording) return;
      setState(() => seconds = DateTime.now().difference(started!).inSeconds);
      if (lastBackupAt == null || DateTime.now().difference(lastBackupAt!) >= const Duration(seconds: 10)) {
        lastBackupAt = DateTime.now();
        unawaited(saveDraft());
      }
    });
    gps = Geolocator.getPositionStream(locationSettings: const AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 3,
      intervalDuration: Duration(seconds: 2),
      foregroundNotificationConfig: ForegroundNotificationConfig(
        notificationTitle: 'CycloComp sedang merekam',
        notificationText: 'Rekaman GPS aktif meskipun layar terkunci',
        notificationChannelName: 'Rekaman Gowes',
        enableWakeLock: true,
        setOngoing: true,
      ),
    )).listen((p) {
      if (!mounted || !recording || paused) return;
      gpsAccuracy = p.accuracy;
      if (p.accuracy > 100) { setState(() => status = 'GPS belum akurat (±\${p.accuracy.toStringAsFixed(0)} m). Coba area terbuka.'); return; }
      final nextSpeed = max(0.0, p.speed * 3.6);
      if (nextSpeed > 100) return;
      if (previous != null) {
        final dt = p.timestamp.difference(previous!.timestamp).inMilliseconds / 1000;
        final meters = Geolocator.distanceBetween(previous!.latitude, previous!.longitude, p.latitude, p.longitude);
        if (dt > 0 && dt <= 30 && meters / dt <= 28 && meters < 150 &&
            meters >= 3 && p.accuracy <= 40) {
          distance += meters;
          if (nextSpeed >= 2) movingSeconds += dt.round();
        }
      }
      previous = p;
      previousFixTime = p.timestamp;
      currentPoint = LatLng(p.latitude, p.longitude);
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

  void togglePause() { setState(() {
    paused = !paused; previous = null; previousFixTime = null; speed = 0;
    if (paused) { pausedAt = DateTime.now(); }
    else if (pausedAt != null) { pausedDuration += DateTime.now().difference(pausedAt!); pausedAt = null; }
  });
    unawaited(saveDraft());
  }

  Future<void> confirmFinishRide() async {
    if (finishing) return;
    final shouldFinish = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Akhiri perjalanan?'),
        content: const Text('Perjalanan akan disimpan ke riwayat. Pastikan kamu sudah berhenti dengan aman.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('BATAL')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('SIMPAN')),
        ],
      ),
    );
    if (shouldFinish == true && mounted) await finishRide();
  }

  Future<void> finishRide() async {
    if (!recording || finishing) return;
    setState(() => finishing = true);
    await gps?.cancel();
    timer?.cancel();
    final entry = rideSnapshot;
    try {
      final p = await SharedPreferences.getInstance();
      final current = p.getStringList('rides') ?? [];
      current.insert(0, jsonEncode(entry));
      final saved = await p.setStringList('rides', current);
      if (!saved) throw StateError('Gagal menulis riwayat');
      await p.remove('active_ride_backup');
      if (mounted) setState(() {
        recording = false; paused = false; speed = 0;
        status = 'Perjalanan disimpan'; rides = current.map((e) => Map<String,dynamic>.from(jsonDecode(e) as Map)).toList();
      });
    } catch (e) {
      if (mounted) setState(() => status = 'Gagal menyimpan: $e. Backup tetap tersedia.');
    } finally {
      if (mounted) setState(() => finishing = false);
    }
  }

  @override
  void dispose() { gps?.cancel(); timer?.cancel(); WakelockPlus.disable(); super.dispose(); }

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


  static const green = Color(0xFF44E9AE);
  static const panel = Color(0xFF172638);
  final MapController mapController = MapController();

  List<LatLng> get path => track.map((p) => LatLng(
    (p['lat'] as num).toDouble(), (p['lon'] as num).toDouble(),
  )).toList();

  Widget stat(String name, String number, String unit, IconData icon) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color:panel,borderRadius:BorderRadius.circular(16)),
    child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Icon(icon,color:green,size:16),const SizedBox(width:5),
        Expanded(child:Text(name,style:const TextStyle(fontSize:10,color:Color(0xFF9EB4C9))))]),
      const SizedBox(height:9),
      Text(number,style:const TextStyle(fontSize:23,fontWeight:FontWeight.bold)),
      Text(unit,style:const TextStyle(fontSize:11,color:Color(0xFF9EB4C9))),
    ]),
  );

  Widget mapView({bool compact = false}) {
    final center = currentPoint ?? (path.isNotEmpty ? path.last : const LatLng(-6.8048,110.8405));
    return ClipRRect(
      borderRadius:BorderRadius.circular(16),
      child: FlutterMap(
        key: ValueKey(compact ? 'mini-map' : 'full-map'),
        options: MapOptions(initialCenter:center,initialZoom:compact ? 15 : 14),
        children:[
          TileLayer(
            urlTemplate:'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName:'com.cyclocomp.ultimate',
          ),
          if (path.length >= 2) PolylineLayer(polylines:[
            Polyline(points:path,color:green,strokeWidth:4),
          ]),
          if (currentPoint != null) MarkerLayer(markers:[
            Marker(point:currentPoint!,width:42,height:42,child:const Icon(
              Icons.my_location,color:Colors.blueAccent,size:38)),
          ]),
          const RichAttributionWidget(attributions:[
            TextSourceAttribution('© OpenStreetMap contributors'),
          ]),
        ],
      ),
    );
  }

  Widget rideControls() => Padding(
    padding:const EdgeInsets.symmetric(vertical:10),
    child: recording ? Row(children:[
      Expanded(child:OutlinedButton.icon(
        onPressed:togglePause,
        icon:Icon(paused ? Icons.play_arrow : Icons.pause),
        label:Text(paused ? 'LANJUT' : 'JEDA'),
      )),
      const SizedBox(width:10),
      Expanded(child:FilledButton.icon(
        onPressed:finishing ? null : confirmFinishRide,
        icon:const Icon(Icons.stop),label:const Text('SELESAI'),
        style:FilledButton.styleFrom(backgroundColor:green,foregroundColor:Colors.black),
      )),
    ]) : FilledButton.icon(
      onPressed:starting ? null : startRide,
      icon:const Icon(Icons.play_arrow),
      label:Text(starting ? 'MENYIAPKAN GPS...' : 'MULAI GOWES'),
      style:FilledButton.styleFrom(backgroundColor:green,foregroundColor:Colors.black,
        padding:const EdgeInsets.all(16)),
    ),
  );

  Widget dashboard() => ListView(padding:const EdgeInsets.all(16),children:[
    Text(status,style:const TextStyle(color:green,fontSize:12)),
    SwitchListTile.adaptive(
      dense:true,
      contentPadding:EdgeInsets.zero,
      value:keepScreenOn,
      onChanged:toggleScreenOn,
      title:const Text('Mode Holder Sepeda',style:TextStyle(fontWeight:FontWeight.w700,fontSize:14)),
      subtitle:const Text('Layar tetap menyala saat dipasang di holder. Gunakan seperlunya untuk menghemat baterai.',style:TextStyle(fontSize:11)),
      secondary:const Icon(Icons.screen_lock_portrait,color:green),
    ),
    const SizedBox(height:12),
    Container(
      padding:const EdgeInsets.all(22),
      decoration:BoxDecoration(color:panel,borderRadius:BorderRadius.circular(20)),
      child:Column(children:[
        const Text('CURRENT SPEED',style:TextStyle(letterSpacing:2,fontSize:12,color:Color(0xFF9EB4C9))),
        Text(speed.toStringAsFixed(1),style:const TextStyle(fontSize:80,fontWeight:FontWeight.w800,height:1.2)),
        const Text('km/h',style:TextStyle(color:Color(0xFF9EB4C9))),
        const SizedBox(height:12),
        Text(recording ? (paused ? '⏸ DIJEDA' : '● RECORDING') : 'SIAP MEREKAM',
          style:const TextStyle(color:green,fontWeight:FontWeight.bold)),
        Text(duration,style:const TextStyle(fontSize:18)),
      ]),
    ),
    const SizedBox(height:12),
    GridView.count(
      physics:const NeverScrollableScrollPhysics(),shrinkWrap:true,
      crossAxisCount:3,childAspectRatio:0.95,crossAxisSpacing:8,mainAxisSpacing:8,
      children:[
        stat('DISTANCE',(distance/1000).toStringAsFixed(2),'km',Icons.route),
        stat('AVG SPEED',movingSeconds > 0 ? (distance / movingSeconds * 3.6).toStringAsFixed(1) : '0.0','km/h',Icons.speed),
        stat('MAX SPEED',maxSpeed.toStringAsFixed(1),'km/h',Icons.trending_up),
        stat('MOVE TIME',_clock(movingSeconds),'hh:mm:ss',Icons.timer),
        stat('GPS POINTS','${track.length}','points',Icons.gps_fixed),
        stat('ELEVATION',altitude.toStringAsFixed(0),'m',Icons.terrain),
      ],
    ),
    const SizedBox(height:14),
    Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
      const Text('LIVE ROUTE',style:TextStyle(fontWeight:FontWeight.bold)),
      TextButton(onPressed:()=>setState(()=>currentTab=1),child:const Text('LIHAT PETA →')),
    ]),
    SizedBox(height:190,child:mapView(compact:true)),
    rideControls(),
    const Text('Mode GPS background aktif saat merekam. Jaga notifikasi CycloComp tetap aktif dan uji sebelum gowes jauh.',
      style:TextStyle(color:Colors.orangeAccent,fontSize:11)),
  ]);

  String _clock(int n) =>
    '${(n~/3600).toString().padLeft(2,'0')}:${((n%3600)~/60).toString().padLeft(2,'0')}:${(n%60).toString().padLeft(2,'0')}';

  Widget mapScreen() => Column(children:[
    Expanded(child:mapView()),
    Padding(padding:const EdgeInsets.symmetric(horizontal:16,vertical:6),child:Row(
      mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        Text('${(distance/1000).toStringAsFixed(2)} km'),
        Text('Titik GPS: ${track.length}'),
        Text(duration),
      ],
    )),
    Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:rideControls()),
  ]);

  Widget history() => ListView(padding:const EdgeInsets.all(16),children:[
    const Text('RIWAYAT GOWES',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
    const SizedBox(height:14),
    if(rides.isEmpty) const Text('Belum ada perjalanan yang disimpan.'),
    for(final r in rides) Card(color:panel,child:ListTile(
      leading:const Icon(Icons.route,color:green),
      title:Text('${((r['distanceKm'] as num?)??0).toStringAsFixed(2)} km'),
      subtitle:Text('${r['started']??'-'} • ${_clock(((r['elapsedSeconds']??r['movingSeconds']) as num?)?.toInt() ?? 0)}'),
    )),
  ]);

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor:const Color(0xFF0B1420),
    appBar:AppBar(backgroundColor:const Color(0xFF0B1420),
      title:const Row(children:[
        Icon(Icons.directions_bike,color:green),SizedBox(width:10),
        Text('CYCLOCOMP',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800,letterSpacing:1)),
      ]),
      actions:[Icon(recording?Icons.gps_fixed:Icons.gps_not_fixed,color:green),
        const SizedBox(width:16)]),
    body:IndexedStack(index:currentTab,children:[dashboard(),mapScreen(),history(),const AccountPage()]),
    bottomNavigationBar:NavigationBar(
      backgroundColor:panel,selectedIndex:currentTab,
      onDestinationSelected:(value)=>setState(()=>currentTab=value),
      destinations:const [
        NavigationDestination(icon:Icon(Icons.dashboard_outlined),selectedIcon:Icon(Icons.dashboard),label:'Dashboard'),
        NavigationDestination(icon:Icon(Icons.map_outlined),selectedIcon:Icon(Icons.map),label:'Peta'),
        NavigationDestination(icon:Icon(Icons.history),label:'Riwayat'),
        NavigationDestination(icon:Icon(Icons.person_outline),label:'Akun'),
      ],
    ),
  );
}
