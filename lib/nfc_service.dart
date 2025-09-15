import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

class NFCService {
  static const MethodChannel _methodChannel =
      MethodChannel('baylan_card_credit');
  static const EventChannel _eventChannel =
      EventChannel('baylan_card_credit_events');

  // Singleton pattern
  static NFCService? _instance;
  static NFCService get instance => _instance ??= NFCService._();
  NFCService._();

  Stream<Map<String, dynamic>>? _eventStream;
  int _currentPayDeskCode = 1;

  // Event Stream - Kotlin'den gelen tüm eventleri dinler
  Stream<Map<String, dynamic>> get eventStream {
    _eventStream ??= _eventChannel.receiveBroadcastStream().map((event) {
      return Map<String, dynamic>.from(event as Map);
    }).handleError((error) {
      print('EventStream Error: $error');
    });
    return _eventStream!;
  }

  String generateRequestId() {
    return const Uuid().v4();
  }

  // PayDeskCode yönetimi
  int getNextPayDeskCode() {
    _currentPayDeskCode++;
    if (_currentPayDeskCode > 255) {
      _currentPayDeskCode = 1;
    }
    return _currentPayDeskCode;
  }

  // Lisans kontrolü
  Future<Map<String, dynamic>> checkLicense() async {
    try {
      final result = await _methodChannel.invokeMethod('checkLicense');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      throw Exception('Lisans kontrolü başarısız: $e');
    }
  }

  // Lisans alma
  Future<Map<String, dynamic>> getLicense({String? customLicenseKey}) async {
    try {
      final requestId = generateRequestId();

      final result = await _methodChannel.invokeMethod('getLicense', {
        'requestId': requestId,
        'licenseKey':
            customLicenseKey, // null ise Kotlin'deki hardcoded key kullanılır
      });

      return Map<String, dynamic>.from(result);
    } catch (e) {
      throw Exception('Lisans alma başarısız: $e');
    }
  }

  // Otomatik lisans kontrolü (basitleştirilmiş)
  Future<bool> ensureValidLicense() async {
    try {
      print('Checking license...');

      // Önce mevcut lisansı kontrol et
      final checkResult = await checkLicense();
      print('License check result: ${checkResult['isValid']}');

      if (checkResult['isValid'] == true) {
        return true;
      }

      // Lisans geçersizse yeni lisans al
      print('Getting new license...');
      final licenseResult = await getLicense();
      print('License acquisition result: ${licenseResult['isValid']}');

      return licenseResult['isValid'] == true;
    } catch (e) {
      print('License error: $e');
      return false;
    }
  }

  // NFC'yi aktif et
  Future<String> activateNFC() async {
    try {
      final result = await _methodChannel.invokeMethod('activateNFC');
      return result.toString();
    } catch (e) {
      throw Exception('NFC aktivasyon başarısız: $e');
    }
  }

  // NFC'yi deaktif et
  Future<String> deactivateNFC() async {
    try {
      final result = await _methodChannel.invokeMethod('deactivateNFC');
      return result.toString();
    } catch (e) {
      throw Exception('NFC deaktivasyon başarısız: $e');
    }
  }

  // Kart okuma
  Future<String> readCard() async {
    try {
      final requestId = generateRequestId();

      final result = await _methodChannel.invokeMethod('readCard', {
        'requestId': requestId,
      });

      return result.toString();
    } catch (e) {
      throw Exception('Kart okuma başarısız: $e');
    }
  }

  // Karta kredi yazma
  Future<String> writeCard({
    required OperationType operationType,
    required double credit,
    double reserveCreditLimit = 0.0,
    double criticalCreditLimit = 0.0,
    String? customerType,
  }) async {
    try {
      final requestId = generateRequestId();
      final paydeskCode = getNextPayDeskCode().toString();

      final result = await _methodChannel.invokeMethod('writeCard', {
        'requestId': requestId,
        'operationType': operationType.value,
        'credit': credit,
        'reserveCreditLimit': reserveCreditLimit,
        'criticalCreditLimit': criticalCreditLimit,
        'paydeskCode': paydeskCode,
        'customerType': customerType,
      });

      return result.toString();
    } catch (e) {
      throw Exception('Kart yazma başarısız: $e');
    }
  }

  // URL ayarla
  Future<String> setUrl(String url) async {
    try {
      final result = await _methodChannel.invokeMethod('setUrl', {'url': url});
      return result.toString();
    } catch (e) {
      throw Exception('URL ayarlama başarısız: $e');
    }
  }

  // URL al
  Future<String> getUrl() async {
    try {
      final result = await _methodChannel.invokeMethod('getUrl');
      return result.toString();
    } catch (e) {
      throw Exception('URL alma başarısız: $e');
    }
  }
}

// Operation Type Enum
enum OperationType {
  none(0),
  addCredit(1),
  clearCredits(2),
  setCredit(3);

  final int value;
  const OperationType(this.value);
}

// Result Codes Enum
enum ResultCode {
  success(0),
  nfcReaderDeactive(999),
  nfcReaderActivated(888),
  cardNotReadYet(2828),
  cardReaded(1010),
  failed(1),
  readCardAgain(2),
  invalidLicence(59),
  licenseServiceError(60),
  cardKeyNotFoundOnTheServer(61),
  authenticateToSectorSuccess(62),
  authenticateToSectorFailed(63);

  final int value;
  const ResultCode(this.value);

  static ResultCode fromString(String name) {
    return ResultCode.values.firstWhere(
      (e) => e.name.toLowerCase() == name.toLowerCase(),
      orElse: () => ResultCode.failed,
    );
  }
}

// Kart Modeli
class ConsumerCard {
  final double? reserveCreditLimit;
  final String? cardSeriNo;
  final String? customerNo;
  final String? meterNo;
  final int? term;
  final double? mainCredit;
  final double? reserveCredit;
  final double? criticalCreditLimit;
  final int? mainCreditTenThousandDigits;
  final double? diameter;
  final int? cardType;
  final String? paydeskCode;
  final String? customerType;
  final double? battery;
  final int? reserveBattery;
  final DateTime? meterDate;
  final DateTime? lastCreditDecreaseDate;
  final DateTime? lastCreditChargeDate;
  final double? remainingCreditOnMeter;
  final double? spentCreditbyMeter;
  final double? termCreditInMeter;
  final double? debtCredit;
  final double? totalConsumption;
  final double? termConsumption;
  final int? termDay;
  final List<double> monthlyConsumptions;
  final int? valveOpenCount;
  final int? valveCloseCount;
  final int? version;
  final int? meterType;
  final String? authorityCode;

  ConsumerCard({
    this.reserveCreditLimit,
    this.cardSeriNo,
    this.customerNo,
    this.meterNo,
    this.term,
    this.mainCredit,
    this.reserveCredit,
    this.criticalCreditLimit,
    this.mainCreditTenThousandDigits,
    this.diameter,
    this.cardType,
    this.paydeskCode,
    this.customerType,
    this.battery,
    this.reserveBattery,
    this.meterDate,
    this.lastCreditDecreaseDate,
    this.lastCreditChargeDate,
    this.remainingCreditOnMeter,
    this.spentCreditbyMeter,
    this.termCreditInMeter,
    this.debtCredit,
    this.totalConsumption,
    this.termConsumption,
    this.termDay,
    this.monthlyConsumptions = const [],
    this.valveOpenCount,
    this.valveCloseCount,
    this.version,
    this.meterType,
    this.authorityCode,
  });

  factory ConsumerCard.fromMap(Map<String, dynamic> map) {
    // Aylık tüketimleri liste olarak topla (24 aya kadar)
    List<double> consumptions = [];
    for (int i = 1; i <= 24; i++) {
      final value = map['monthlyConsumption$i'];
      if (value != null) {
        consumptions.add((value as num).toDouble());
      }
    }

    return ConsumerCard(
      reserveCreditLimit: _toDouble(map['reserveCreditLimit']),
      cardSeriNo: map['cardSeriNo'],
      customerNo: map['customerNo'],
      meterNo: map['meterNo'],
      term: map['term'],
      mainCredit: _toDouble(map['mainCredit']),
      reserveCredit: _toDouble(map['reserveCredit']),
      criticalCreditLimit: _toDouble(map['criticalCreditLimit']),
      mainCreditTenThousandDigits: map['mainCreditTenThousandDigits'],
      diameter: _toDouble(map['diameter']),
      cardType: map['cardType'],
      paydeskCode: map['paydeskCode'],
      customerType: map['customerType'],
      battery: _toDouble(map['battery']),
      reserveBattery: map['reserveBattery'],
      meterDate: _parseDate(map['meterDate']),
      lastCreditDecreaseDate: _parseDate(map['lastCreditDecreaseDate']),
      lastCreditChargeDate: _parseDate(map['lastCreditChargeDate']),
      remainingCreditOnMeter: _toDouble(map['remainingCreditOnMeter']),
      spentCreditbyMeter: _toDouble(map['spentCreditbyMeter']),
      termCreditInMeter: _toDouble(map['termCreditInMeter']),
      debtCredit: _toDouble(map['debtCredit']),
      totalConsumption: _toDouble(map['totalConsumption']),
      termConsumption: _toDouble(map['termConsumption']),
      termDay: map['termDay'],
      monthlyConsumptions: consumptions,
      valveOpenCount: map['valveOpenCount'],
      valveCloseCount: map['valveCloseCount'],
      version: map['version'],
      meterType: map['meterType'],
      authorityCode: map['authorityCode'],
    );
  }

  // Helper methods
  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
