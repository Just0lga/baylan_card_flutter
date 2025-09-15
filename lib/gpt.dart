// lib/nfc_read.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

/// NFC Read UI + platform channel wrapper for the Baylan library.
///
/// Usage:
///   - Put this file in lib/nfc_read.dart
///   - In main.dart set home: NfcReadPage()
///
/// Not: Android tarafında MainActivity.kt'nde method/event channel isimleri
/// "baylan_card_credit" ve "baylan_card_credit_events" ile uyumlu olmalı.
class NfcReadPage extends StatefulWidget {
  const NfcReadPage({Key? key}) : super(key: key);

  @override
  State<NfcReadPage> createState() => _NfcReadPageState();
}

class _NfcReadPageState extends State<NfcReadPage> {
  static const _methodChannel = MethodChannel('baylan_card_credit');
  static const _eventChannel = EventChannel('baylan_card_credit_events');

  // README'den gelen sabitler (senin verdiğin)
  final String _providedUrl =
      'https://baylanbms.maraskaski.gov.tr:55176/Baylan/';
  final String _providedLicenseKey = '9283ebb4-9822-46fa-bbe3-ac4a4d25b8c2';

  StreamSubscription? _eventSub;
  final List<Map<String, dynamic>> _events = [];
  Map<String, dynamic>? _lastCardData;
  String _status = 'Hazır';
  bool _licensed = false;
  bool _nfcActivated = false;

  @override
  void initState() {
    super.initState();
    _startEventListener();
    // Otomatik başlangıç: URL set, lisans almaya çalış (iyi bir UX için kullanıcıya izin verme opsiyonu ekleyebilirsin)
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _eventSub?.cancel();
    super.dispose();
  }

  // EventChannel'den gelen native mesajları dinle
  void _startEventListener() {
    _eventSub = _eventChannel.receiveBroadcastStream().listen((raw) {
      // raw muhtemelen bir Map (kotlin tarafında mapOf ile gönderiliyor)
      Map<String, dynamic> map;
      if (raw is Map) {
        // dynamic map => cast to Map<String, dynamic>
        map = Map<String, dynamic>.from(raw);
      } else {
        // eğer string gelirse parse et
        try {
          map = jsonDecode(raw.toString()) as Map<String, dynamic>;
        } catch (_) {
          map = {'raw': raw.toString()};
        }
      }

      setState(() {
        _events.insert(0, map);
      });

      // Özel: onReadCard gelirse card verisini kaydet
      if (map['type'] == 'onReadCard') {
        final cardData = map['cardData'];
        if (cardData != null && cardData is Map) {
          _lastCardData = Map<String, dynamic>.from(cardData);
        } else {
          _lastCardData = null;
        }
      }

      // onResult ile genel durumlar (ör: NFC aktifleştirme) gelebilir
      if (map['type'] == 'onResult') {
        final rc = map['resultCode'] ?? '';
        if (rc == 'NFCReaderActivated' || rc == 'NFCReaderActivated') {
          _nfcActivated = true;
        }
      }
    }, onError: (err) {
      setState(() {
        _events.insert(0, {'error': err.toString()});
      });
    });
  }

  // Bootstrap: setUrl -> getLicense -> checkLicense -> activateNFC
  Future<void> _bootstrap() async {
    setState(() => _status = 'Hazırlanıyor: URL set ediliyor...');
    try {
      await _setUrl(_providedUrl);
      setState(() => _status = 'URL set edildi. Lisans alınıyor...');
      // requestId, README'de belirtildiği gibi benzersiz olmalı, burada UUID kullanıyoruz
      final requestId = const Uuid().v4();
      final licenseRes = await _getLicense(
          requestId: requestId, licenseKey: _providedLicenseKey);
      // licenseRes map bekleniyor: {resultCode, message, isValid}
      if (licenseRes != null && licenseRes['isValid'] == true) {
        setState(() {
          _licensed = true;
          _status = 'Lisans geçerli.';
        });
      } else {
        setState(() {
          _licensed = false;
          _status =
              'Lisans alınamadı: ${licenseRes?['message'] ?? 'bilinmiyor'}';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Hazırlık hatası: ${e.toString()}';
      });
    }
  }

  // Platform metodlarının wrapper'ları

  Future<dynamic> _invokeMethod(String method,
      [Map<String, dynamic>? args]) async {
    try {
      final res = await _methodChannel.invokeMethod(method, args);
      return res;
    } on PlatformException catch (e) {
      // Flutter tarafında yakala, UI'a yaz
      setState(() {
        _events.insert(0,
            {'type': 'platform_error', 'method': method, 'message': e.message});
      });
      rethrow;
    } catch (e) {
      setState(() {
        _events.insert(
            0, {'type': 'error', 'method': method, 'message': e.toString()});
      });
      rethrow;
    }
  }

  Future<void> _setUrl(String url) async {
    await _invokeMethod('setUrl', {'url': url});
    setState(() {
      _events.insert(0, {'type': 'url_set', 'url': url});
    });
  }

  Future<String?> _getUrl() async {
    final res = await _invokeMethod('getUrl');
    return res?.toString();
  }

  Future<Map<String, dynamic>?> _getLicense(
      {required String requestId, required String licenseKey}) async {
    final res = await _invokeMethod(
        'getLicense', {'requestId': requestId, 'licenseKey': licenseKey});
    if (res is Map) return Map<String, dynamic>.from(res);
    return null;
  }

  Future<Map<String, dynamic>?> _checkLicense() async {
    final res = await _invokeMethod('checkLicense');
    if (res is Map) return Map<String, dynamic>.from(res);
    return null;
  }

  Future<String?> _activateNfc() async {
    final res = await _invokeMethod('activateNFC');
    setState(() {
      _nfcActivated = true;
      _events.insert(0, {'type': 'activateNFC', 'result': res});
    });
    return res?.toString();
  }

  Future<String?> _deactivateNfc() async {
    final res = await _invokeMethod('deactivateNFC');
    setState(() {
      _nfcActivated = false;
      _events.insert(0, {'type': 'deactivateNFC', 'result': res});
    });
    return res?.toString();
  }

  Future<String?> _readCard({String? requestId}) async {
    final rid = requestId ?? const Uuid().v4();
    final res = await _invokeMethod('readCard', {'requestId': rid});
    setState(() {
      _events.insert(
          0, {'type': 'readCard_started', 'requestId': rid, 'result': res});
      _status = 'Kart okutuluyor... (requestId: $rid)';
    });
    return res?.toString();
  }

  Future<String?> _writeCard({
    String? requestId,
    required int operationType,
    required double credit,
    double? reserveCreditLimit,
    double? criticalCreditLimit,
    String? paydeskCode,
    String? customerType,
  }) async {
    final rid = requestId ?? const Uuid().v4();
    final args = {
      'requestId': rid,
      'operationType': operationType, // 0..3 per README
      'credit': credit,
      'reserveCreditLimit': reserveCreditLimit ?? 0.0,
      'criticalCreditLimit': criticalCreditLimit ?? 0.0,
      'paydeskCode': paydeskCode,
      'customerType': customerType,
    };
    final res = await _invokeMethod('writeCard', args);
    setState(() {
      _events.insert(0, {
        'type': 'writeCard_started',
        'requestId': rid,
        'args': args,
        'result': res
      });
      _status = 'Kredi yazma başlatıldı (requestId: $rid)';
    });
    return res?.toString();
  }

  // UI actions

  Future<void> _onManualCheckLicense() async {
    setState(() => _status = 'Lisans kontrol ediliyor...');
    try {
      final l = await _checkLicense();
      setState(() {
        _licensed = l?['isValid'] == true;
        _status = 'CheckLicense sonucu: ${l?['resultCode'] ?? l}';
        _events.insert(0, {'type': 'checkLicense', 'result': l});
      });
    } catch (e) {
      setState(() => _status = 'CheckLicense hatası: ${e.toString()}');
    }
  }

  Future<void> _onActivateNfc() async {
    setState(() => _status = 'NFC aktifleştiriliyor...');
    try {
      await _activateNfc();
      setState(() => _status = 'NFC aktifleştirildi.');
    } catch (e) {
      setState(() => _status = 'NFC aktifleştirme hatası: ${e.toString()}');
    }
  }

  Future<void> _onRead() async {
    if (!_licensed) {
      // Lisans yoksa otomatik almaya çalış
      setState(() => _status = 'Lisans yok — lisans almaya çalışılıyor...');
      final reqId = const Uuid().v4();
      try {
        final gl = await _getLicense(
            requestId: reqId, licenseKey: _providedLicenseKey);
        if (gl != null && gl['isValid'] == true) {
          setState(() {
            _licensed = true;
            _status = 'Lisans alındı, NFC aktifleştiriliyor...';
          });
        } else {
          setState(() {
            _status = 'Lisans alınamadı: ${gl?['message'] ?? 'bilinmiyor'}';
            return;
          });
        }
      } catch (e) {
        setState(() {
          _status = 'Lisans alma hatası: ${e.toString()}';
          return;
        });
      }
    }

    // NFC aktif değilse aktif et
    if (!_nfcActivated) {
      try {
        await _activateNfc();
      } catch (_) {
        // hata olsa da devam etmeyelim
        setState(() =>
            _status = 'NFC aktifleştirme hatası, okutma başarısız olabilir.');
      }
    }

    // Read başlat
    try {
      await _readCard();
      setState(() => _status = 'Okuma başlatıldı — karta dokun.');
    } catch (e) {
      setState(() => _status = 'Okuma hatası: ${e.toString()}');
    }
  }

  Future<void> _onWriteSample() async {
    // Örnek: AddCredit (operationType=1) credit=10.0
    setState(() => _status = 'Yazma başlatılıyor (örnek)...');
    try {
      await _writeCard(
          operationType: 1, credit: 10.0, paydeskCode: '1', customerType: 'A');
      setState(() => _status = 'Yazma talebi gönderildi.');
    } catch (e) {
      setState(() => _status = 'Yazma hatası: ${e.toString()}');
    }
  }

  // Pretty print JSON map for display
  String _pretty(Object? o) {
    try {
      if (o == null) return '-';
      if (o is String) {
        final decoded = jsonDecode(o);
        return const JsonEncoder.withIndent('  ').convert(decoded);
      } else if (o is Map || o is List) {
        return const JsonEncoder.withIndent('  ').convert(o);
      } else {
        return o.toString();
      }
    } catch (e) {
      return o.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Baylan NFC - Okuma/Yazma'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () async {
              final url = await _getUrl();
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Konfigürasyon'),
                  content: Text(
                      'URL: $url\nLisanslı mı: $_licensed\nNFC Aktif mi: $_nfcActivated'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Kapat'))
                  ],
                ),
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // durum ve butonlar
            Card(
              child: ListTile(
                title: Text('Durum: $_status'),
                subtitle: Text(
                    'Son kart: ${_lastCardData != null ? (_lastCardData!['cardSeriNo'] ?? '-') : '-'}'),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.usb),
                  label: const Text('URL Set & Lisans Otomatik (Başlat)'),
                  onPressed: _bootstrap,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.verified_user),
                  label: const Text('Check License'),
                  onPressed: _onManualCheckLicense,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.nfc),
                  label: const Text('NFC Aktifleştir'),
                  onPressed: _onActivateNfc,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.nfc_outlined),
                  label: const Text('Okut (Read)'),
                  onPressed: _onRead,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.upload),
                  label: const Text('Yazma Örneği (AddCredit)'),
                  onPressed: _onWriteSample,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.power_off),
                  label: const Text('NFC Kapat'),
                  onPressed: () async {
                    try {
                      await _deactivateNfc();
                      setState(() => _status = 'NFC kapatıldı.');
                    } catch (e) {
                      setState(() =>
                          _status = 'NFC kapatma hatası: ${e.toString()}');
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Kart verisi gösterimi
            Expanded(
              child: Row(
                children: [
                  // Events list
                  Flexible(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Event Log',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.grey.shade300)),
                            padding: const EdgeInsets.all(8),
                            child: _events.isEmpty
                                ? const Text('Henüz event yok.')
                                : ListView.builder(
                                    itemCount: _events.length,
                                    itemBuilder: (_, i) {
                                      final e = _events[i];
                                      final t = e['type'] ??
                                          e['resultCode'] ??
                                          e['raw'] ??
                                          e.toString();
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 4),
                                        child: Text('- ${t.toString()}'),
                                      );
                                    },
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Card data pretty
                  Flexible(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Son Okunan Kart',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Expanded(
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.grey.shade300)),
                            padding: const EdgeInsets.all(8),
                            child: SingleChildScrollView(
                              child: Text(
                                _lastCardData == null
                                    ? 'Henüz kart okunmadı.'
                                    : _pretty(_lastCardData),
                                style: const TextStyle(fontFamily: 'monospace'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Küçük not
            Text(
              'Not: Native kütüphane gerçek cihazda çalıştırılmalıdır. '
              'Lisans/RequestId mekanizması README’e göre sunucu doğrulaması gerektirir.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          ],
        ),
      ),
    );
  }
}
