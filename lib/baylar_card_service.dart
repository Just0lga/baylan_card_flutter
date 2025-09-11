import 'package:flutter/services.dart';
import 'dart:async';

class BaylanCardService {
  static const MethodChannel _channel = MethodChannel('baylan_card_credit');

  // Callback listeners
  static Function(String message, String resultCode)? onResult;
  static Function(Map<String, dynamic>? cardData, String resultCode)?
      onReadCard;
  static Function(String resultCode)? onWriteCard;

  BaylanCardService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  // Native'den gelen callback'leri handle eder
  static Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onResult':
        final String message = call.arguments['message'] ?? '';
        final String resultCode = call.arguments['resultCode'] ?? '';
        onResult?.call(message, resultCode);
        break;

      case 'onReadCard':
        final Map<String, dynamic>? cardData = call.arguments['cardData'];
        final String resultCode = call.arguments['resultCode'] ?? '';
        onReadCard?.call(cardData, resultCode);
        break;

      case 'onWriteCard':
        final String resultCode = call.arguments['resultCode'] ?? '';
        onWriteCard?.call(resultCode);
        break;
    }
  }

  // Lisans kontrolü
  Future<Map<String, dynamic>?> checkLicense() async {
    try {
      final result = await _channel.invokeMethod('checkLicense');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('License check error: $e');
      return null;
    }
  }

  // Lisans alma
  Future<Map<String, dynamic>?> getLicense({
    required String requestId,
    required String licenseKey,
  }) async {
    try {
      final result = await _channel.invokeMethod('getLicense', {
        'requestId': requestId,
        'licenseKey': licenseKey,
      });
      return Map<String, dynamic>.from(result);
    } catch (e) {
      print('Get license error: $e');
      return null;
    }
  }

  // NFC Aktif etme
  Future<String?> activateNFC() async {
    try {
      final result = await _channel.invokeMethod('activateNFC');
      return result;
    } catch (e) {
      print('Activate NFC error: $e');
      return null;
    }
  }

  // NFC Deaktif etme
  Future<String?> deactivateNFC() async {
    try {
      final result = await _channel.invokeMethod('deactivateNFC');
      return result;
    } catch (e) {
      print('Deactivate NFC error: $e');
      return null;
    }
  }

  // Kart okuma
  Future<void> readCard(String requestId) async {
    try {
      await _channel.invokeMethod('readCard', {
        'requestId': requestId,
      });
    } catch (e) {
      print('Read card error: $e');
    }
  }

  // Kart yazma
  Future<void> writeCard({
    required String requestId,
    required int
        operationType, // 0: None, 1: AddCredit, 2: ClearCredits, 3: SetCredit
    required double credit,
    required double reserveCreditLimit,
    required double criticalCreditLimit,
    String? paydeskCode,
    String? customerType,
  }) async {
    try {
      await _channel.invokeMethod('writeCard', {
        'requestId': requestId,
        'operationType': operationType,
        'credit': credit,
        'reserveCreditLimit': reserveCreditLimit,
        'criticalCreditLimit': criticalCreditLimit,
        'paydeskCode': paydeskCode,
        'customerType': customerType,
      });
    } catch (e) {
      print('Write card error: $e');
    }
  }

  // URL set etme
  Future<void> setUrl(String url) async {
    try {
      await _channel.invokeMethod('setUrl', {'url': url});
    } catch (e) {
      print('Set URL error: $e');
    }
  }

  // URL alma
  Future<String?> getUrl() async {
    try {
      final result = await _channel.invokeMethod('getUrl');
      return result;
    } catch (e) {
      print('Get URL error: $e');
      return null;
    }
  }
}

// Result Code Enum
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

  const ResultCode(this.value);
  final int value;

  static ResultCode fromValue(int value) {
    return ResultCode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ResultCode.failed,
    );
  }
}

// Operation Type Enum
enum OperationType {
  none(0),
  addCredit(1),
  clearCredits(2),
  setCredit(3);

  const OperationType(this.value);
  final int value;
}

// Consumer Card Model
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
  final int? diameter;
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
  final double? termDay;
  final List<double?> monthlyConsumptions;
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
    return ConsumerCard(
      reserveCreditLimit: map['reserveCreditLimit']?.toDouble(),
      cardSeriNo: map['cardSeriNo'],
      customerNo: map['customerNo'],
      meterNo: map['meterNo'],
      term: map['term']?.toInt(),
      mainCredit: map['mainCredit']?.toDouble(),
      reserveCredit: map['reserveCredit']?.toDouble(),
      criticalCreditLimit: map['criticalCreditLimit']?.toDouble(),
      mainCreditTenThousandDigits: map['mainCreditTenThousandDigits']?.toInt(),
      diameter: map['diameter']?.toInt(),
      cardType: map['cardType']?.toInt(),
      paydeskCode: map['paydeskCode'],
      customerType: map['customerType'],
      battery: map['battery']?.toDouble(),
      reserveBattery: map['reserveBattery']?.toInt(),
      meterDate:
          map['meterDate'] != null ? DateTime.parse(map['meterDate']) : null,
      lastCreditDecreaseDate: map['lastCreditDecreaseDate'] != null
          ? DateTime.parse(map['lastCreditDecreaseDate'])
          : null,
      lastCreditChargeDate: map['lastCreditChargeDate'] != null
          ? DateTime.parse(map['lastCreditChargeDate'])
          : null,
      remainingCreditOnMeter: map['remainingCreditOnMeter']?.toDouble(),
      spentCreditbyMeter: map['spentCreditbyMeter']?.toDouble(),
      termCreditInMeter: map['termCreditInMeter']?.toDouble(),
      debtCredit: map['debtCredit']?.toDouble(),
      totalConsumption: map['totalConsumption']?.toDouble(),
      termConsumption: map['termConsumption']?.toDouble(),
      termDay: map['termDay']?.toDouble(),
      monthlyConsumptions: _parseMonthlyConsumptions(map),
      valveOpenCount: map['valveOpenCount']?.toInt(),
      valveCloseCount: map['valveCloseCount']?.toInt(),
      version: map['version']?.toInt(),
      meterType: map['meterType']?.toInt(),
      authorityCode: map['authorityCode'],
    );
  }

  static List<double?> _parseMonthlyConsumptions(Map<String, dynamic> map) {
    List<double?> consumptions = [];
    for (int i = 1; i <= 24; i++) {
      consumptions.add(map['monthlyConsumption$i']?.toDouble());
    }
    return consumptions;
  }
}
