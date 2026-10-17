import 'package:flutter/material.dart';

class StravaStatusPage extends StatelessWidget {
  const StravaStatusPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0B1420),
    appBar: AppBar(title: const Text('Strava Auto Sync'),backgroundColor:const Color(0xFF0B1420)),
    body:ListView(padding:const EdgeInsets.all(20),children:const [
      Icon(Icons.sync_disabled,color:Colors.orangeAccent,size:64),
      SizedBox(height:16),
      Text('STRAVA BELUM TERHUBUNG',textAlign:TextAlign.center,
        style:TextStyle(fontWeight:FontWeight.bold,fontSize:21)),
      SizedBox(height:16),
      Text('Upload otomatis membutuhkan Strava OAuth resmi dan backend yang menjaga client secret serta refresh token.'),
      SizedBox(height:12),
      Text('Status sinkronisasi tidak akan mengklaim sukses sebelum Strava menerima aktivitas.'),
      SizedBox(height:12),
      Text('Untuk sementara, buka tab Riwayat dan bagikan file GPX perjalanan secara manual.'),
      SizedBox(height:12),
      Text('Langkah berikutnya: daftar aplikasi di Strava API, konfigurasikan callback backend, dan aktifkan scope activity:write.'),
    ]),
  );
}
