import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const authConfigured = bool.fromEnvironment('CYCLOCOMP_AUTH_ENABLED', defaultValue: false) &&
  String.fromEnvironment('SUPABASE_URL') != '' &&
  String.fromEnvironment('SUPABASE_ANON_KEY') != '';

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool register = false;
  bool busy = false;
  bool showPassword = false;
  String? message;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!authConfigured) return;
    final address = email.text.trim();
    if (!address.contains('@') || password.text.length < 8) {
      setState(() => message = 'Masukkan email valid dan password minimal 8 karakter.');
      return;
    }
    setState(() { busy = true; message = null; });
    try {
      final auth = Supabase.instance.client.auth;
      if (register) {
        final response = await auth.signUp(email: address, password: password.text);
        if (!mounted) return;
        setState(() => message = response.session == null
          ? 'Pendaftaran diterima. Periksa email untuk konfirmasi akun.'
          : 'Pendaftaran berhasil. Kamu sudah masuk.');
      } else {
        await auth.signInWithPassword(email: address, password: password.text);
      }
      password.clear();
    } on AuthException catch (e) {
      if (mounted) setState(() => message = e.message);
    } catch (_) {
      if (mounted) setState(() => message = 'Koneksi bermasalah. Coba lagi saat online.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF44E9AE);
    if (!authConfigured) {
      return ListView(padding: const EdgeInsets.all(24), children: const [
        Icon(Icons.directions_bike, color: accent, size: 64),
        SizedBox(height: 16),
        Text('MODE TAMU', textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        SizedBox(height: 12),
        Text('Kamu bisa merekam dan menyimpan gowes di HP tanpa akun.',
            textAlign: TextAlign.center),
        SizedBox(height: 16),
        Card(child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Login Email & Password sudah disiapkan dalam aplikasi, '
            'tetapi belum aktif sampai proyek Supabase CycloComp dihubungkan. '
            'Data tamu belum otomatis dicadangkan ke cloud.'),
        )),
      ]);
    }
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          return ListView(padding: const EdgeInsets.all(24), children: [
            const Icon(Icons.verified_user, color: accent, size: 60),
            const SizedBox(height: 16),
            const Text('AKUN CYCLOCOMP', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(user.email ?? 'Akun aktif', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            const Card(child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Login aktif. Sinkronisasi riwayat dan backup cloud '
                  'akan ditambahkan berikutnya. Rekaman saat ini masih tersimpan di HP.'),
            )),
            OutlinedButton.icon(
              onPressed: busy ? null : () async {
                await Supabase.instance.client.auth.signOut();
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.logout), label: const Text('KELUAR AKUN'),
            ),
          ]);
        }
        return ListView(padding: const EdgeInsets.all(24), children: [
          const Icon(Icons.directions_bike, size: 58, color: accent),
          const SizedBox(height: 12),
          Text(register ? 'DAFTAR CYCLOCOMP' : 'MASUK CYCLOCOMP',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('Login opsional. Tanpa login, rekam GPS tetap bisa digunakan.',
              textAlign: TextAlign.center),
          const SizedBox(height: 22),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: !showPassword,
            autofillHints: [register ? AutofillHints.newPassword : AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Password (minimal 8 karakter)',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => showPassword = !showPassword),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (message != null) Text(message!, style: const TextStyle(color: Colors.amberAccent)),
          FilledButton(
            onPressed: busy ? null : submit,
            style: FilledButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
            child: Text(busy ? 'MEMPROSES...' : register ? 'DAFTAR' : 'MASUK'),
          ),
          TextButton(
            onPressed: busy ? null : () => setState(() { register = !register; message = null; }),
            child: Text(register ? 'Sudah punya akun? Masuk' : 'Belum punya akun? Daftar'),
          ),
          const SizedBox(height: 12),
          const Text('Untuk mode tamu, kembali ke Dashboard. Tidak perlu daftar.',
              textAlign: TextAlign.center),
        ]);
      },
    );
  }
}
