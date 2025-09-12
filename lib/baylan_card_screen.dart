import 'package:baylan_card_flutter/baylar_card_service.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

class BaylanCardScreen extends StatefulWidget {
  const BaylanCardScreen({super.key});

  @override
  State<BaylanCardScreen> createState() => _BaylanCardScreenState();
}

class _BaylanCardScreenState extends State<BaylanCardScreen> {
  final BaylanCardService _baylanService = BaylanCardService();
  final Uuid _uuid = const Uuid();

  // Controllers
  final _licenseKeyController = TextEditingController();
  final _urlController = TextEditingController();
  final _creditController = TextEditingController();
  final _reserveCreditController = TextEditingController();
  final _criticalCreditController = TextEditingController();

  // State variables
  bool _isLoading = false;
  bool _isLicenseValid = false;
  bool _isNfcActive = false;
  ConsumerCard? _currentCard;
  String _statusMessage = '';
  OperationType _selectedOperation = OperationType.addCredit;

  @override
  void initState() {
    super.initState();
    _licenseKeyController.text = "9283ebb4-9822-46fa-bbe3-ac4a4d25b8c2";
    _initializeService();
    _requestPermissions();
    _loadInitialUrl();
  }

  void _initializeService() {
    // Callback'leri set et
    BaylanCardService.onResult = (message, resultCode) {
      setState(() {
        _statusMessage = '$message (Code: $resultCode)';
        _isLoading = false;
      });
      _showSnackBar(message);
    };

    BaylanCardService.onReadCard = (cardData, resultCode) {
      setState(() {
        _isLoading = false;
        if (cardData != null && resultCode == 'Success') {
          _currentCard = ConsumerCard.fromMap(cardData);
          _creditController.text = _currentCard!.mainCredit?.toString() ?? '';
          _reserveCreditController.text =
              _currentCard!.reserveCredit?.toString() ?? '';
          _criticalCreditController.text =
              _currentCard!.criticalCreditLimit?.toString() ?? '';
          _statusMessage = 'Kart başarıyla okundu';
        } else {
          _statusMessage = 'Kart okuma hatası: $resultCode';
        }
      });
      _showSnackBar(_statusMessage);
    };

    BaylanCardService.onWriteCard = (resultCode) {
      setState(() {
        _isLoading = false;
        if (resultCode == 'Success') {
          _statusMessage = 'Kart başarıyla yazıldı';
        } else {
          _statusMessage = 'Kart yazma hatası: $resultCode';
        }
      });
      _showSnackBar(_statusMessage);
    };
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.nearbyWifiDevices,
      Permission.notification,
    ].request();
  }

  Future<void> _loadInitialUrl() async {
    final url = await _baylanService.getUrl();
    if (url != null) {
      _urlController.text = url;
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  Future<void> _checkLicense() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _baylanService.checkLicense();
      if (result != null) {
        setState(() {
          _isLicenseValid = result['isValid'] ?? false;
          _statusMessage = result['message'] ?? 'Lisans kontrolü tamamlandı';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Lisans kontrol hatası: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _getLicense() async {
    if (_licenseKeyController.text.isEmpty) {
      _showSnackBar('Lütfen lisans anahtarını girin');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await _baylanService.getLicense(
        requestId: _uuid.v4(),
        licenseKey: _licenseKeyController.text,
      );

      if (result != null) {
        setState(() {
          _isLicenseValid = result['isValid'] ?? false;
          _statusMessage = result['message'] ?? 'Lisans alma işlemi tamamlandı';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Lisans alma hatası: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleNFC() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String? result;
      if (_isNfcActive) {
        result = await _baylanService.deactivateNFC();
      } else {
        result = await _baylanService.activateNFC();
      }

      if (result != null) {
        setState(() {
          _isNfcActive = result == 'NFCReaderActivated';
          _statusMessage = _isNfcActive ? 'NFC aktif' : 'NFC deaktif';
        });
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'NFC toggle hatası: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _readCard() async {
    if (!_isLicenseValid) {
      _showSnackBar('Önce lisans alınmalı');
      return;
    }

    // URL'yi set et
    if (_urlController.text.isNotEmpty) {
      await _baylanService.setUrl(_urlController.text);
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Kartı okumak için NFC alanına yaklaştırın...';
    });

    try {
      await _baylanService.readCard(_uuid.v4());
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Kart okuma hatası: $e';
      });
    }
  }

  Future<void> _writeCard() async {
    if (!_isLicenseValid) {
      _showSnackBar('Önce lisans alınmalı');
      return;
    }

    if (_creditController.text.isEmpty) {
      _showSnackBar('Lütfen kredi miktarını girin');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Kartı yazmak için NFC alanına yaklaştırın...';
    });

    try {
      await _baylanService.writeCard(
        requestId: _uuid.v4(),
        operationType: _selectedOperation.value,
        credit: double.parse(_creditController.text),
        reserveCreditLimit:
            double.tryParse(_reserveCreditController.text) ?? 0.0,
        criticalCreditLimit:
            double.tryParse(_criticalCreditController.text) ?? 0.0,
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Kart yazma hatası: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Baylan Card Credit'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // License Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isLicenseValid ? Icons.check_circle : Icons.error,
                          color: _isLicenseValid ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Lisans Durumu',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _licenseKeyController,
                      decoration: const InputDecoration(
                        labelText: 'Lisans Anahtarı',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _checkLicense,
                            child: const Text('Lisans Kontrol Et'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _getLicense,
                            child: const Text('Lisans Al'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // NFC Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isNfcActive ? Icons.nfc : Icons.nfc_outlined,
                          color: _isNfcActive ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'NFC Durumu',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'Sunucu URL',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _toggleNFC,
                        child: Text(_isNfcActive ? 'NFC Kapat' : 'NFC Aç'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Card Operations Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kart İşlemleri',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _readCard,
                            icon: const Icon(Icons.credit_card),
                            label: const Text('Kart Oku'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<OperationType>(
                      value: _selectedOperation,
                      decoration: const InputDecoration(
                        labelText: 'İşlem Tipi',
                        border: OutlineInputBorder(),
                      ),
                      items: OperationType.values.map((op) {
                        String label;
                        switch (op) {
                          case OperationType.none:
                            label = 'Hiçbiri';
                            break;
                          case OperationType.addCredit:
                            label = 'Kredi Ekle';
                            break;
                          case OperationType.clearCredits:
                            label = 'Kredileri Temizle';
                            break;
                          case OperationType.setCredit:
                            label = 'Kredi Ayarla';
                            break;
                        }
                        return DropdownMenuItem(
                          value: op,
                          child: Text(label),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedOperation = value!;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _creditController,
                      decoration: const InputDecoration(
                        labelText: 'Ana Kredi',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _reserveCreditController,
                      decoration: const InputDecoration(
                        labelText: 'Rezerv Kredi',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _criticalCreditController,
                      decoration: const InputDecoration(
                        labelText: 'Kritik Kredi Limiti',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _writeCard,
                        icon: const Icon(Icons.edit),
                        label: const Text('Kart Yaz'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Status Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Durum',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      const Center(
                        child: CircularProgressIndicator(),
                      )
                    else
                      Text(_statusMessage),
                  ],
                ),
              ),
            ),

            // Card Information Section
            if (_currentCard != null) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kart Bilgileri',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      _buildCardInfoRow(
                          'Kart Seri No', _currentCard!.cardSeriNo),
                      _buildCardInfoRow('Müşteri No', _currentCard!.customerNo),
                      _buildCardInfoRow('Sayaç No', _currentCard!.meterNo),
                      _buildCardInfoRow('Ana Kredi',
                          _currentCard!.mainCredit?.toStringAsFixed(2)),
                      _buildCardInfoRow('Rezerv Kredi',
                          _currentCard!.reserveCredit?.toStringAsFixed(2)),
                      _buildCardInfoRow(
                          'Kritik Kredi Limiti',
                          _currentCard!.criticalCreditLimit
                              ?.toStringAsFixed(2)),
                      _buildCardInfoRow(
                          'Batarya', _currentCard!.battery?.toStringAsFixed(1)),
                      _buildCardInfoRow('Toplam Tüketim',
                          _currentCard!.totalConsumption?.toStringAsFixed(2)),
                      _buildCardInfoRow(
                          'Sayaçtaki Kalan Kredi',
                          _currentCard!.remainingCreditOnMeter
                              ?.toStringAsFixed(2)),
                      if (_currentCard!.meterDate != null)
                        _buildCardInfoRow('Sayaç Tarihi',
                            _currentCard!.meterDate!.toString().split(' ')[0]),
                      if (_currentCard!.lastCreditChargeDate != null)
                        _buildCardInfoRow(
                            'Son Kredi Yükleme',
                            _currentCard!.lastCreditChargeDate!
                                .toString()
                                .split(' ')[0]),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCardInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value ?? 'N/A'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _licenseKeyController.dispose();
    _urlController.dispose();
    _creditController.dispose();
    _reserveCreditController.dispose();
    _criticalCreditController.dispose();
    super.dispose();
  }
}
