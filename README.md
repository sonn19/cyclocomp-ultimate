# CycloComp Ultimate 🚴

Aplikasi bike computer Android berbasis Flutter, dikembangkan bertahap.

## Tahap pertama
- GPS speedometer, jarak, elevasi, kecepatan maksimal
- Mulai, jeda, lanjutkan, akhiri perjalanan
- Filter akurasi GPS
- Riwayat perjalanan lokal

## Status
Prototipe awal. Belum siap dipakai sebagai satu-satunya pencatat perjalanan panjang.

## Menjalankan
1. Pasang Flutter SDK dan Android SDK.
2. Jalankan `flutter create --platforms=android .` di folder proyek untuk membuat konfigurasi Android.
3. Tambahkan izin `ACCESS_FINE_LOCATION` dan `ACCESS_COARSE_LOCATION` pada AndroidManifest.xml.
4. Jalankan `flutter pub get` dan `flutter run`.

## Roadmap
- Penyimpanan SQLite dan pemulihan saat crash
- Foreground service agar GPS tetap merekam saat layar mati
- BLE heart rate, cadence, speed, power
- Peta offline, navigasi GPX, tanjakan
- Analisis latihan, AI Coach, sinkronisasi cloud

Huawei Watch GT 1 tidak mendukung HR broadcast standar; gunakan sensor BLE terpisah untuk HR live.
