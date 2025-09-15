import 'package:flutter/material.dart';
import 'dart:async';
import 'nfc_service.dart';
import 'package:intl/intl.dart';

class ReadNFCScreen extends StatefulWidget {
  const ReadNFCScreen({Key? key}) : super(key: key);

  @override
  State<ReadNFCScreen> createState() => _ReadNFCScreenState();
}

class _ReadNFCScreenState extends State<ReadNFCScreen> {
  final NFCService _nfcService = NFCService.instance;
  StreamSubscription? _eventSubscription;

  bool _isReading = false;
  String _statusMessage = 'NFC hazır. Kartı okutabilirsiniz.';
  ConsumerCard? _lastReadCard;
  String? _lastError;
  ResultCode? _lastResultCode;

  final DateFormat _dateFormat = DateFormat('dd.MM.yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _listenToEvents();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    super.dispose();
  }

  void _listenToEvents() {
    _eventSubscription = _nfcService.eventStream.listen((event) {
      final type = event['type'];

      switch (type) {
        case 'onResult':
          _handleGeneralResult(event);
          break;
        case 'onReadCard':
          _handleReadCardResult(event);
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

      switch (resultCode) {
        case ResultCode.cardReaded:
          _statusMessage = 'Kart okundu, veriler işleniyor...';
          break;
        case ResultCode.cardNotReadYet:
          _statusMessage = 'Kartı NFC okuyucuya yaklaştırın';
          break;
        case ResultCode.readCardAgain:
          _statusMessage = 'Kartı tekrar okutun';
          _isReading = false;
          break;
        default:
          if (message.isNotEmpty) {
            _statusMessage = message;
          }
      }
    });
  }

  void _handleReadCardResult(Map<String, dynamic> event) {
    final resultCodeStr = event['resultCode'] as String;
    final resultCode = ResultCode.fromString(resultCodeStr);
    final cardData = event['cardData'];

    setState(() {
      _isReading = false;
      _lastResultCode = resultCode;

      if (resultCode == ResultCode.success && cardData != null) {
        _lastReadCard = ConsumerCard.fromMap(cardData);
        _statusMessage = 'Kart başarıyla okundu!';
        _lastError = null;
      } else {
        _statusMessage = 'Kart okuma başarısız';
        _lastError = 'Okuma hatası: ${resultCode.name}';
      }
    });
  }

  Future<void> _startReading() async {
    setState(() {
      _isReading = true;
      _statusMessage = 'Kartı NFC okuyucuya yaklaştırın...';
      _lastError = null;
    });

    try {
      await _nfcService.readCard();
    } catch (e) {
      setState(() {
        _isReading = false;
        _statusMessage = 'Okuma başlatılamadı';
        _lastError = e.toString();
      });
    }
  }

  Widget _buildCardInfo() {
    if (_lastReadCard == null) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.credit_card, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Henüz kart okunmadı',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final card = _lastReadCard!;

    return SingleChildScrollView(
      child: Card(
        margin: const EdgeInsets.all(16),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Kart Bilgileri',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Başarılı',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Kimlik Bilgileri
              _buildSectionTitle('Kimlik Bilgileri'),
              _buildInfoRow('Kart Seri No', card.cardSeriNo ?? '-'),
              _buildInfoRow('Müşteri No', card.customerNo ?? '-'),
              _buildInfoRow('Sayaç No', card.meterNo ?? '-'),
              _buildInfoRow('Müşteri Tipi', card.customerType ?? '-'),
              _buildInfoRow('PayDesk Kodu', card.paydeskCode ?? '-'),

              const SizedBox(height: 16),
              _buildSectionTitle('Kredi Bilgileri'),
              _buildInfoRow(
                'Ana Kredi',
                '${card.mainCredit?.toStringAsFixed(2) ?? '0.00'} TL',
                Colors.blue,
              ),
              _buildInfoRow(
                'Yedek Kredi',
                '${card.reserveCredit?.toStringAsFixed(2) ?? '0.00'} TL',
              ),
              _buildInfoRow(
                'Kritik Limit',
                '${card.criticalCreditLimit?.toStringAsFixed(2) ?? '0.00'} TL',
                Colors.orange,
              ),
              _buildInfoRow(
                'Kalan Kredi',
                '${card.remainingCreditOnMeter?.toStringAsFixed(2) ?? '0.00'} TL',
                Colors.green,
              ),

              const SizedBox(height: 16),
              _buildSectionTitle('Tüketim Bilgileri'),
              _buildInfoRow(
                'Toplam Tüketim',
                '${card.totalConsumption?.toStringAsFixed(2) ?? '0.00'} m³',
              ),
              _buildInfoRow(
                'Dönem Tüketimi',
                '${card.termConsumption?.toStringAsFixed(2) ?? '0.00'} m³',
              ),
              _buildInfoRow('Dönem', '${card.term ?? 0}'),

              const SizedBox(height: 16),
              _buildSectionTitle('Sayaç Bilgileri'),
              _buildInfoRow(
                'Pil Durumu',
                '${card.battery?.toStringAsFixed(0) ?? '0'}%',
                card.battery != null && card.battery! < 20
                    ? Colors.red
                    : Colors.green,
              ),
              _buildInfoRow('Vana Açma', '${card.valveOpenCount ?? 0} kez'),
              _buildInfoRow('Vana Kapama', '${card.valveCloseCount ?? 0} kez'),

              const SizedBox(height: 16),
              _buildSectionTitle('Tarih Bilgileri'),
              _buildInfoRow(
                'Sayaç Tarihi',
                card.meterDate != null
                    ? _dateFormat.format(card.meterDate!)
                    : '-',
              ),
              _buildInfoRow(
                'Son Kredi Yükleme',
                card.lastCreditChargeDate != null
                    ? _dateFormat.format(card.lastCreditChargeDate!)
                    : '-',
              ),

              if (card.monthlyConsumptions.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildSectionTitle('Son Aylık Tüketimler (m³)'),
                const SizedBox(height: 8),
                _buildMonthlyConsumptionGrid(
                    card.monthlyConsumptions.take(6).toList()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, [Color? valueColor]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: valueColor ?? Colors.black87,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyConsumptionGrid(List<double> consumptions) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: consumptions.length,
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Ay ${index + 1}',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
              Text(
                consumptions[index].toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NFC Kart Okuma'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Durum kartı
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 4,
            color: _lastError != null
                ? Colors.red.shade50
                : _isReading
                    ? Colors.blue.shade50
                    : Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_isReading)
                    const CircularProgressIndicator()
                  else
                    Icon(
                      _lastError != null ? Icons.error_outline : Icons.nfc,
                      size: 48,
                      color: _lastError != null
                          ? Colors.red
                          : _isReading
                              ? Colors.blue
                              : Colors.green,
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

          // Okuma butonu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isReading ? null : _startReading,
                icon: Icon(_isReading ? Icons.hourglass_empty : Icons.nfc),
                label: Text(_isReading ? 'Okuma Bekleniyor...' : 'Kartı Oku'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Kart bilgileri
          Expanded(
            child: _buildCardInfo(),
          ),
        ],
      ),
    );
  }
}
