import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class SensorsPage extends StatefulWidget {
  const SensorsPage({super.key});
  @override
  State<SensorsPage> createState() => _SensorsPageState();
}

class _SensorsPageState extends State<SensorsPage> {
  StreamSubscription<List<ScanResult>>? scanSub;
  final List<ScanResult> devices = [];
  final List<StreamSubscription<List<int>>> sensorSubscriptions = [];
  BluetoothDevice? connected;
  int? bpm;
  int? cadence;
  int? previousCrankRevs;
  int? previousCrankTime;
  bool scanning = false;
  String message = 'Cari sensor BLE heart rate atau cadence.';

  @override
  void dispose() {
    scanSub?.cancel();
    for(final sub in sensorSubscriptions) { sub.cancel(); }
    connected?.disconnect();
    super.dispose();
  }

  Future<void> scan() async {
    try {
      setState(() { scanning = true; devices.clear(); message='Memindai sensor...'; });
      await scanSub?.cancel();
      scanSub = FlutterBluePlus.scanResults.listen((results) {
        if (!mounted) return;
        setState(() {
          for(final result in results) {
            if(result.device.platformName.isNotEmpty &&
              !devices.any((e) => e.device.remoteId == result.device.remoteId)) {
              devices.add(result);
            }
          }
        });
      });
      await FlutterBluePlus.startScan(timeout:const Duration(seconds:12));
    } catch(e) {
      if(mounted) setState(()=>message='Bluetooth gagal: $e. Periksa izin Nearby devices.');
    } finally {
      if(mounted) setState(()=>scanning=false);
    }
  }

  Future<void> connect(BluetoothDevice device) async {
    setState(() => message='Menghubungkan ${device.platformName}...');
    try {
      await connected?.disconnect();
      for(final sub in sensorSubscriptions) { await sub.cancel(); }
      sensorSubscriptions.clear();
      await device.connect(timeout:const Duration(seconds:15));
      connected = device;
      final services = await device.discoverServices();
      for(final service in services) {
        for(final c in service.characteristics) {
          final id = c.uuid.toString().toLowerCase();
          if(id.endsWith('2a37') || id.endsWith('2a5b') ||
             id.contains('00002a37-') || id.contains('00002a5b-')) {
            await c.setNotifyValue(true);
            sensorSubscriptions.add(c.lastValueStream.listen((v) {
              if (!mounted) return;
              if((id.contains('2a37')) && v.length >= 2) {
                final flags = v[0];
                final value = (flags & 1) != 0 && v.length >= 3
                  ? v[1] | (v[2] << 8) : v[1];
                setState(()=>bpm=value);
              }
              if(id.contains('2a5b') && v.isNotEmpty) {
                final flags=v[0];
                if((flags & 2) != 0) {
                  final offset=(flags & 1) != 0 ? 7 : 1;
                  if(v.length < offset+4) return;
                  final rev=v[offset] | (v[offset+1]<<8);
                  final time=v[offset+2] | (v[offset+3]<<8);
                  if(previousCrankRevs != null && previousCrankTime != null) {
                    final dr=(rev-previousCrankRevs!) & 65535;
                    final dt=(time-previousCrankTime!) & 65535;
                    if(dt>0 && dr<=30) {
                      final rpm=(dr*60*1024/dt).round();
                      if(rpm<=250) setState(()=>cadence=rpm);
                    }
                  }
                  previousCrankRevs=rev;
                  previousCrankTime=time;
                }
              }
            }));
          }
        }
      }
      if(mounted) setState(()=>message='Terhubung: ${device.platformName}. Data muncul jika sensor mendukung profil BLE standar.');
    } catch(e) {
      if(mounted) setState(()=>message='Koneksi gagal: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor:const Color(0xFF0B1420),
    appBar:AppBar(title:const Text('Sensor Bluetooth'),backgroundColor:const Color(0xFF0B1420)),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      Text(message),
      const SizedBox(height:12),
      Row(children:[
        Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(16),
          child:Column(children:[const Text('HEART RATE'),Text(bpm?.toString() ?? '--',
            style:const TextStyle(fontSize:38)),const Text('bpm')])))),
        Expanded(child:Card(child:Padding(padding:const EdgeInsets.all(16),
          child:Column(children:[const Text('CADENCE'),Text(cadence?.toString() ?? '--',
            style:const TextStyle(fontSize:38)),const Text('rpm')])))),
      ]),
      FilledButton.icon(onPressed:scanning ? null : scan,
        icon:const Icon(Icons.bluetooth_searching),label:Text(scanning ? 'MEMINDAI...' : 'CARI SENSOR BLE')),
      for(final entry in devices) ListTile(
        leading:const Icon(Icons.bluetooth),
        title:Text(entry.device.platformName),
        subtitle:Text(entry.device.remoteId.toString()),
        trailing:const Icon(Icons.chevron_right),
        onTap:()=>connect(entry.device),
      ),
      const SizedBox(height:16),
      const Text('Versi awal: satu sensor per koneksi, profil standar BLE HR (0x180D) dan CSC (0x1816). Sensor tertentu memerlukan pengujian nyata.'),
    ]),
  );
}
