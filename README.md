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
