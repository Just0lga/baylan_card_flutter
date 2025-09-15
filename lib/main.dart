import 'dart:async';

import 'package:flutter/material.dart';
import 'read_nfc_screen.dart';
import 'write_nfc_screen.dart';
import 'nfc_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Baylan Kart Sistemi',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLicenseChecked = false;
  bool _isLicenseValid = false;
  String _licenseStatus = 'Lisans kontrol ediliyor...';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _licenseStatus = 'Lisans kontrol ediliyor...';
    });

    try {
      // Timeout ekleyin
      final isValid = await NFCService.instance
          .ensureValidLicense()
          .timeout(const Duration(seconds: 20));

      setState(() {
        _isLicenseChecked = true;
        _isLicenseValid = isValid;
        _licenseStatus = isValid ? 'Lisans aktif ✓' : 'Lisans alınamadı ✗';
      });
    } on TimeoutException {
      setState(() {
        _isLicenseChecked = true;
        _isLicenseValid = false;
        _licenseStatus = 'Lisans kontrolü zaman aşımı';
      });
    } catch (e) {
      setState(() {
        _isLicenseChecked = true;
        _isLicenseValid = false;
        _licenseStatus = 'Lisans hatası: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Baylan Kart Sistemi'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Icon(
                Icons.credit_card,
                size: 100,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              const Text(
                'NFC Kart İşlemleri',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 40),

              // Lisans durumu
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isLicenseValid
                      ? Colors.green.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isLicenseValid ? Colors.green : Colors.orange,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!_isLicenseChecked)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Icon(
                        _isLicenseValid ? Icons.check_circle : Icons.warning,
                        color: _isLicenseValid ? Colors.green : Colors.orange,
                      ),
                    const SizedBox(width: 8),
                    Text(
                      _licenseStatus,
                      style: TextStyle(
                        color: _isLicenseValid
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Kart Okuma Butonu
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLicenseValid
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ReadNFCScreen(),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.nfc_rounded),
                  label: const Text(
                    'Kart Oku',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Kart Yazma Butonu
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _isLicenseValid
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const WriteNFCScreen(),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text(
                    'Kart Yaz',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // Yenile butonu (lisans başarısızsa)
              if (_isLicenseChecked && !_isLicenseValid)
                TextButton.icon(
                  onPressed: _initializeApp,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tekrar Dene'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
