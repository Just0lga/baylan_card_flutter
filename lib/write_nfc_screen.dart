import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'nfc_service.dart';

class WriteNFCScreen extends StatefulWidget {
  const WriteNFCScreen({Key? key}) : super(key: key);

  @override
  State<WriteNFCScreen> createState() => _WriteNFCScreenState();
}

class _WriteNFCScreenState extends State<WriteNFCScreen> {
  final NFCService _nfcService = NFCService.instance;
  StreamSubscription? _eventSubscription;

  final _formKey = GlobalKey<FormState>();
  final _creditController = TextEditingController();
  final _reserveLimitController = TextEditingController();
  final _criticalLimitController = TextEditingController();
  final _customerTypeController = TextEditingController();

  OperationType _selectedOperation = OperationType.addCredit;
  bool _isWriting = false;
  String _statusMessage = 'Form doldurup kartı yazabilirsiniz.';
  String? _lastError;
  bool _lastWriteSuccess = false;
  ResultCode? _lastResultCode;

  @override
  void initState() {
    super.initState();
    _listenToEvents();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _creditController.dispose();
    _reserveLimitController.dispose();
    _criticalLimitController.dispose();
    _customerTypeController.dispose();
    super.dispose();
  }

  void _listenToEvents() {
    _eventSubscription = _nfcService.eventStream.listen((event) {
      final type = event['type'];

      switch (type) {
        case 'onResult':
          _handleGeneralResult(event);
          break;
        case 'onWriteCard':
          _handleWriteCardResult(event);
          break;
      }
    });
  }

  void _handleGeneralResult(Map<String, dynamic> event) {
    final resultCodeStr = event['resultCode'] as String;
    final resultCode = ResultCode.fromString(resultCodeStr);
    final message = event['message'] as String? ?? '';

    setState(() {
      _lastResultCode = resultCode;
      if (message.isNotEmpty) {
        _statusMessage = message;
      }
    });
  }

  void _handleWriteCardResult(Map<String, dynamic> event) {
    final resultCodeStr = event['resultCode'] as String;
    final resultCode = ResultCode.fromString(resultCodeStr);

    setState(() {
      _isWriting = false;
      _lastResultCode = resultCode;
      _lastWriteSuccess = resultCode == ResultCode.success;

      if (_lastWriteSuccess) {
        _statusMessage = 'Kart başarıyla yazıldı!';
        _lastError = null;
        _clearForm();

        // Başarı mesajı göster
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kredi başarıyla yüklendi!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        _statusMessage = 'Kart yazma başarısız';
        _lastError = 'Yazma hatası: ${resultCode.name}';
      }
    });
  }

  void _clearForm() {
    _creditController.clear();
    _reserveLimitController.clear();
    _criticalLimitController.clear();
    _customerTypeController.clear();
    setState(() {
      _selectedOperation = OperationType.addCredit;
    });
  }

  Future<void> _startWriting() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isWriting = true;
      _statusMessage = 'Kartı NFC okuyucuya yaklaştırın...';
      _lastError = null;
      _lastWriteSuccess = false;
    });

    try {
      final credit = _selectedOperation == OperationType.clearCredits
          ? 0.0
          : double.parse(_creditController.text);

      final reserveLimit = _reserveLimitController.text.isEmpty
          ? 0.0
          : double.parse(_reserveLimitController.text);

      final criticalLimit = _criticalLimitController.text.isEmpty
          ? 0.0
          : double.parse(_criticalLimitController.text);

      await _nfcService.writeCard(
        operationType: _selectedOperation,
        credit: credit,
        reserveCreditLimit: reserveLimit,
        criticalCreditLimit: criticalLimit,
        customerType: _customerTypeController.text.isEmpty
            ? null
            : _customerTypeController.text,
      );
    } catch (e) {
      setState(() {
        _isWriting = false;
        _statusMessage = 'Yazma başlatılamadı';
        _lastError = e.toString();
      });
    }
  }

  Widget _buildOperationSelector() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'İşlem Tipi',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            RadioListTile<OperationType>(
              title: const Text('Kredi Ekle'),
              subtitle: const Text('Mevcut krediye ekleme yapar'),
              value: OperationType.addCredit,
              groupValue: _selectedOperation,
              onChanged: (value) {
                setState(() {
                  _selectedOperation = value!;
                });
              },
            ),
            RadioListTile<OperationType>(
              title: const Text('Kredi Ayarla'),
              subtitle: const Text('Krediyi belirtilen değere ayarlar'),
              value: OperationType.setCredit,
              groupValue: _selectedOperation,
              onChanged: (value) {
                setState(() {
                  _selectedOperation = value!;
                });
              },
            ),
            RadioListTile<OperationType>(
              title: const Text('Kredileri Temizle'),
              subtitle: const Text('Tüm kredileri sıfırlar'),
              value: OperationType.clearCredits,
              groupValue: _selectedOperation,
              onChanged: (value) {
                setState(() {
                  _selectedOperation = value!;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kredi Bilgileri',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              // Ana kredi
              TextFormField(
                controller: _creditController,
                decoration: const InputDecoration(
                  labelText: 'Kredi Miktarı (TL) *',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.attach_money),
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                enabled: _selectedOperation != OperationType.clearCredits,
                validator: (value) {
                  if (_selectedOperation == OperationType.clearCredits) {
                    return null;
                  }
                  if (value == null || value.isEmpty) {
                    return 'Kredi miktarı gerekli';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Geçerli bir miktar girin';
                  }
                  if (amount > 99999) {
                    return 'Maksimum 99,999 TL girilebilir';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Yedek kredi limiti
              TextFormField(
                controller: _reserveLimitController,
                decoration: const InputDecoration(
                  labelText: 'Yedek Kredi Limiti (TL)',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.savings),
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),

              const SizedBox(height: 16),

              // Kritik kredi limiti
              TextFormField(
                controller: _criticalLimitController,
                decoration: const InputDecoration(
                  labelText: 'Kritik Kredi Limiti (TL)',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.warning),
                  border: OutlineInputBorder(),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),

              const SizedBox(height: 16),

              // Müşteri tipi
              TextFormField(
                controller: _customerTypeController,
                decoration: const InputDecoration(
                  labelText: 'Müşteri Tipi',
                  hintText: 'Bireysel / Kurumsal',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Kart Yazma'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: _clearForm,
            tooltip: 'Formu Temizle',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Durum kartı
            Card(
              margin: const EdgeInsets.all(16),
              elevation: 4,
              color: _lastError != null
                  ? Colors.red.shade50
                  : _isWriting
                      ? Colors.blue.shade50
                      : _lastWriteSuccess
                          ? Colors.green.shade50
                          : Colors.grey.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_isWriting)
                      const CircularProgressIndicator()
                    else
                      Icon(
                        _lastError != null
                            ? Icons.error_outline
                            : _lastWriteSuccess
                                ? Icons.check_circle
                                : Icons.nfc,
                        size: 48,
                        color: _lastError != null
                            ? Colors.red
                            : _isWriting
                                ? Colors.blue
                                : _lastWriteSuccess
                                    ? Colors.green
                                    : Colors.grey,
                      ),
                    const SizedBox(height: 16),
                    Text(
                      _statusMessage,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    if (_lastError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _lastError!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // İşlem tipi seçimi
            _buildOperationSelector(),

            // Form
            _buildForm(),

            // Yazma butonu
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isWriting ? null : _startWriting,
                  icon: Icon(_isWriting ? Icons.hourglass_empty : Icons.nfc),
                  label: Text(_isWriting ? 'Yazma Bekleniyor...' : 'Karta Yaz'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
