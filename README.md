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

## Akun CycloComp (opsional)

Aplikasi selalu menyediakan **mode tamu** untuk merekam dan melihat riwayat gowes secara lokal.
Tab **Akun** telah disiapkan untuk daftar/masuk menggunakan Email + Password.
Akun memerlukan proyek Supabase **tersendiri**, tidak memakai proyek Kimonik.

1. Buat proyek Supabase CycloComp dan aktifkan Email provider pada Authentication.
2. Ambil Project URL dan **publishable/anon key** (bukan service_role).
3. Untuk menjalankan Flutter dengan login aktif, gunakan:
   ```sh
   flutter run --dart-define=CYCLOCOMP_AUTH_ENABLED=true --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co --dart-define=SUPABASE_ANON_KEY=YOUR_PUBLISHABLE_KEY
   ```
4. Gunakan kebijakan password dan verifikasi email pada Supabase Auth. Jangan simpan password sendiri.
5. **Login tidak berarti backup otomatis**; tabel aktivitas, RLS, dan mekanisme sync cloud masih perlu dibangun.

Tanpa konfigurasi, tab Akun menampilkan status mode tamu; tombol rekam dan riwayat tetap tersedia.

## APK Android

GitHub Actions kini hanya berjalan **manual**, melalui **Actions → Build Android APK → Run workflow**, supaya perubahan fitur kecil tidak membangun APK berulang-ulang.

**Penting:** Perekaman GPS saat layar mati masih belum teruji dan belum andal. Untuk sementara jangan mengandalkan aplikasi untuk perjalanan panjang.

## Background GPS milestone (belum diuji pada perangkat)
- Saat Mulai Gowes, Android memulai foreground location tracking melalui geolocator_android dan menampilkan notifikasi "CycloComp sedang merekam".
- AndroidManifest saat build diberi izin lokasi presisi, foreground service lokasi, wake lock, dan Internet.
- Waktu total dihitung dari jam mulai sehingga penghentian timer oleh sistem tidak membuat waktu 30 menit menjadi 2 menit.
- Titik GPS dan statistik dicadangkan tiap sekitar 10 detik ke penyimpanan lokal dan dipulihkan sebagai perjalanan tidak lengkap saat aplikasi dibuka ulang.
- Perjalanan lama dan baru belum disinkronkan ke cloud. Backup perangkat bukan jaminan jika aplikasi di-force stop, penyimpanan dihapus, atau sistem mematikan layanan.
- Ketika background service aktif, notifikasi harus tetap terlihat. Buka pengaturan aplikasi Android untuk mengizinkan Lokasi Presisi dan tidak membatasi baterai.
- Uji khusus: perjalanan 30 menit, layar terkunci >=20 menit, cek rute GPS dan elapsed time setelah selesai. Jangan mengandalkan aplikasi untuk perjalanan utama sebelum lulus uji.

## Fitur baru: GPS signal dan ekspor GPX
- Dashboard menampilkan perkiraan akurasi GPS dalam meter, untuk membantu mendeteksi sinyal yang lemah.
- Pada tab Riwayat, tekan ikon bagikan untuk mengekspor rute perjalanan berformat GPX 1.1 (posisi, waktu, elevasi apabila tersedia).
- Ekspor memerlukan titik GPS yang valid; perjalanan tanpa data GPS akan menampilkan pesan kesalahan.
- Berbagi GPX tidak otomatis mengunggah aktivitas ke Strava. Sinkronisasi Strava langsung tetap tahap terpisah.
- Kode baru belum dibuild/diuji pada POCO X7 Pro. Build Android hanya dijalankan manual sesuai kesepakatan.
