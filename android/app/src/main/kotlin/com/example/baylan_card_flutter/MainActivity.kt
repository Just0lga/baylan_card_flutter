package com.example.baylan_card_flutter

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import java.util.randomUUID
import com.bubuapps.baylancardcreditlibrary.BaylanCardCreditLibrary
import com.bubuapps.baylancardcreditlibrary.Model.DTO.Enums.ResultCode
import com.bubuapps.baylancardcreditlibrary.Model.DTO.Enums.enOperationType
import com.bubuapps.baylancardcreditlibrary.Interface.IBaylanCardCreditLibrary
import com.bubuapps.baylancardcreditlibrary.Model.Card.Model.CardStatus2
import com.bubuapps.baylancardcreditlibrary.Model.DTO.ConsumerCardDTO
import com.bubuapps.baylancardcreditlibrary.Model.DTO.CreditRequestDTO
import com.bubuapps.baylancardcreditlibrary.Model.DTO.Enums.enResultCodes
import com.bubuapps.baylancardcreditlibrary.Model.DTO.LicenseRequest
import com.bubuapps.baylancardcreditlibrary.Model.DTO.ReadCardRequest
import com.bubuapps.baylancardcreditlibrary.Model.Service.ResultModel


Tolga bey, bir de event_channel koyun buraya. override ettiğiniz methodlarımızı tetikleyeiblmemiz için gerekiyor. Ekstra olarak bir şey kalmadı gerisi sizde :)
yardımcı olabilecğem başka bir şey var mıdır? Implementation tamam 
url ve şifreler doğruysa devamını inceleyeceğim çok teşekkür edeirm, sorunum olursa rahatsız ederim teşekkürler r,ca ederiz iyi günler iyi günlerrr

class MainActivity: FlutterActivity(), IBaylanCardCreditLibrary {
    // Flutter ile kotlin arasındaki bağlantıyı yapacak olan kanal
    // 8 farklı method handle ediliyor
    private val CHANNEL = "baylan_card_credit" // Flutter ile konuşma kanalının adı
    private lateinit var methodChannel: MethodChannel // Flutter ile iletişim nesnesi
    private lateinit var baylanCardCreditLibrary: BaylanCardCreditLibrary // Baylan kütüphanesinin nesnesi

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Baylan kütüphanesini başlat
        baylanCardCreditLibrary = BaylanCardCreditLibrary(this)
        
        // Flutter ile konuşma kanalı kur
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        // Flutterdan gelecek çağrıları dinle
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkLicense" -> checkLicense(result)
                "getLicense" -> getLicense(call, result)
                "activateNFC" -> activateNFC(result)
                "deactivateNFC" -> deactivateNFC(result)
                "readCard" -> readCard(call, result)
                "writeCard" -> writeCard(call, result)
                "setUrl" -> setUrl(call, result)
                "getUrl" -> getUrl(result)
                else -> result.notImplemented()
            }
        }
        
        // NFC'yi otomatik başlat
        // GlobalScope.launch: Kotlin coroutine(eş zamanlı olmayan bir işlemdir), NFC işlemi zaman alabilir bu yüzden arkaplanda çalışır
        GlobalScope.launch {
            baylanCardCreditLibrary.ActivateNFCCardReader()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }
    
    // Mevcut lisansı kontrol eden kod, kart okuma yazma öncesi license geçerli olmalı
    private fun checkLicense(result: Result) {
        try {
            // Baylan kütüphanesine lisans durumunu sor
            val licenseResult = baylanCardCreditLibrary.CheckLicence()
            
            // Sonucu flutterın anlayacağı formata çevir
            val response = mapOf(
                "resultCode" to licenseResult.ResultCode.name,
                "message" to licenseResult.Message,
                "isValid" to (licenseResult.ResultCode == enResultCodes.LicenseisValid)
            )

            // Sonucu fluttera gönder
            result.success(response)
        } catch (e: Exception) {
            // Hata varsa fluttera gönder
            result.error("LICENSE_ERROR", e.message, null)
        }
    }
    
    // Yeni lisans alır
    private fun getLicense(call: MethodCall, result: Result) {
        try {
            val requestId = call.argument<String>("requestId") ?: ""
            val licenseKey = call.argument<String>("licenseKey") ?: ""
            
            val licenseRequest = LicenseRequest().apply {
                this.requestId = requestId
                this.licenceKey = licenseKey
            }
            
            val licenseResult = baylanCardCreditLibrary.GetLicense(licenseRequest)
            val response = mapOf(
                "resultCode" to licenseResult.ResultCode.name,
                "message" to licenseResult.Message,
                "isValid" to (licenseResult.ResultCode == enResultCodes.LicenseisValid)
            )
            result.success(response)
        } catch (e: Exception) {
            result.error("GET_LICENSE_ERROR", e.message, null)
        }
    }

    // NFC okuyucuyu aktif eder
    private fun activateNFC(result: Result) {
        try {
            val resultCode = baylanCardCreditLibrary.ActivateNFCCardReader()
            result.success(resultCode.name)
        } catch (e: Exception) {
            result.error("NFC_ACTIVATE_ERROR", e.message, null)
        }
    }

    // NFC okuyucuyu kapatır
    private fun deactivateNFC(result: Result) {
        try {
            val resultCode = baylanCardCreditLibrary.DisapleNFCReader()
            result.success(resultCode.name)
        } catch (e: Exception) {
            result.error("NFC_DEACTIVATE_ERROR", e.message, null)
        }
    }

    // Kart okuma işlemini başlatır
    private fun readCard(call: MethodCall, result: Result) {
        try {
            // Flutterdan gelen parametreleri al
            val requestId = call.argument<String>("requestId") ?: UUID.randomUUID().toString()
            
            //Okuma isteği nesnesi oluştur
            val readCardRequest = ReadCardRequest().apply {
                this.requestId = requestId
            }
            
            // Okuma işlemini başlat
            baylanCardCreditLibrary.ReadCard(readCardRequest)
            
            // Fluttera işlem başladı de
            result.success("READ_STARTED")
        } catch (e: Exception) {
            result.error("READ_CARD_ERROR", e.message, null)
        }
    }

    // Karta kredi yazma işlemi
    private fun writeCard(call: MethodCall, result: Result) {
        try {
            val requestId = call.argument<String>("requestId") ?: UUID.randomUUID().toString()
            val operationType = call.argument<Int>("operationType") ?: 0
            val credit = call.argument<Double>("credit") ?: 0.0
            val reserveCreditLimit = call.argument<Double>("reserveCreditLimit") ?: 0.0
            val criticalCreditLimit = call.argument<Double>("criticalCreditLimit") ?: 0.0
            val paydeskCode = call.argument<String>("paydeskCode")
            val customerType = call.argument<String>("customerType")
            
            val enOperationTypeVal = when (operationType) {
                0 -> enOperationType.None
                1 -> enOperationType.AddCredit
                2 -> enOperationType.ClearCredits
                3 -> enOperationType.SetCredit
                else -> enOperationType.None
            }
            
            val creditRequestDTO = CreditRequestDTO().apply {
                this.requestId = requestId
                this.operationType = enOperationTypeVal
                this.credit = credit
                this.reserveCreditLimit = reserveCreditLimit
                this.criticalCreditLimit = criticalCreditLimit
                this.paydeskCode = paydeskCode
                this.customerType = customerType
            }
            
            baylanCardCreditLibrary.CreditOperation(creditRequestDTO)
            result.success("WRITE_STARTED")
        } catch (e: Exception) {
            result.error("WRITE_CARD_ERROR", e.message, null)
        }
    }

    private fun setUrl(call: MethodCall, result: Result) {
        try {
            val url = call.argument<String>("url") ?: ""
            baylanCardCreditLibrary.SetUrl(url)
            result.success("URL_SET")
        } catch (e: Exception) {
            result.error("SET_URL_ERROR", e.message, null)
        }
    }

    private fun getUrl(result: Result) {
        try {
            val url = baylanCardCreditLibrary.GetUrl()
            result.success(url)
        } catch (e: Exception) {
            result.error("GET_URL_ERROR", e.message, null)
        }
    }

    // IBaylanCardCreditLibrary interface implementations
    override fun OnResult(tag: String?, code: ResultCode) {
        runOnUiThread {
            methodChannel.invokeMethod("onResult", mapOf(
                "message" to (tag ?: ""),
                "resultCode" to code.name
            ))
        }
    }

    // Okuma işleminden gelen veriyi okur
    override fun ReadCardResult(consumerCardDTO: ConsumerCardDTO?, code: ResultCode) {
        runOnUiThread {
            
            // 1. Kart verilerini Flutter formatına çevir
            val cardData = consumerCardDTO?.let { card ->
                mapOf(
                    "reserveCreditLimit" to card.reserveCreditLimit,
                    "cardSeriNo" to card.cardSeriNo,
                    "customerNo" to card.customerNo,
                    "meterNo" to card.meterNo,
                    "term" to card.term,
                    "mainCredit" to card.mainCredit,
                    "reserveCredit" to card.reserveCredit,
                    "criticalCreditLimit" to card.criticalCreditLimit,
                    "mainCreditTenThousandDigits" to card.mainCreditTenThousandDigits,
                    "diameter" to card.diameter,
                    "cardType" to card.cardType,
                    "paydeskCode" to card.paydeskCode,
                    "customerType" to card.customerType,
                    "battery" to card.battery,
                    "reserveBattery" to card.reserveBattery,
                    "meterDate" to card.meterDate?.toString(),
                    "lastCreditDecreaseDate" to card.lastCreditDecreaseDate?.toString(),
                    "lastCreditChargeDate" to card.lastCreditChargeDate?.toString(),
                    "remainingCreditOnMeter" to card.remainingCreditOnMeter,
                    "spentCreditbyMeter" to card.spentCreditbyMeter,
                    "termCreditInMeter" to card.termCreditInMeter,
                    "debtCredit" to card.debtCredit,
                    "totalConsumption" to card.totalConsumption,
                    "termConsumption" to card.termConsumption,
                    "termDay" to card.termDay,
                    "monthlyConsumption1" to card.monthlyConsumption1,
                    "monthlyConsumption2" to card.monthlyConsumption2,
                    "monthlyConsumption3" to card.monthlyConsumption3,
                    "monthlyConsumption4" to card.monthlyConsumption4,
                    "monthlyConsumption5" to card.monthlyConsumption5,
                    "monthlyConsumption6" to card.monthlyConsumption6,
                    "monthlyConsumption7" to card.monthlyConsumption7,
                    "monthlyConsumption8" to card.monthlyConsumption8,
                    "monthlyConsumption9" to card.monthlyConsumption9,
                    "monthlyConsumption10" to card.monthlyConsumption10,
                    "monthlyConsumption11" to card.monthlyConsumption11,
                    "monthlyConsumption12" to card.monthlyConsumption12,
                    "monthlyConsumption13" to card.monthlyConsumption13,
                    "monthlyConsumption14" to card.monthlyConsumption14,
                    "monthlyConsumption15" to card.monthlyConsumption15,
                    "monthlyConsumption16" to card.monthlyConsumption16,
                    "monthlyConsumption17" to card.monthlyConsumption17,
                    "monthlyConsumption18" to card.monthlyConsumption18,
                    "monthlyConsumption19" to card.monthlyConsumption19,
                    "monthlyConsumption20" to card.monthlyConsumption20,
                    "monthlyConsumption21" to card.monthlyConsumption21,
                    "monthlyConsumption22" to card.monthlyConsumption22,
                    "monthlyConsumption23" to card.monthlyConsumption23,
                    "monthlyConsumption24" to card.monthlyConsumption24,
                    "valveOpenCount" to card.valveOpenCount,
                    "valveCloseCount" to card.valveCloseCount,
                    "version" to card.version,
                    "meterType" to card.meterType,
                    "authorityCode" to card.authorityCode
                )
            }
            
            // Fluttera bu verileri gönder
            methodChannel.invokeMethod("onReadCard", mapOf(
                "cardData" to cardData,
                "resultCode" to code.name
            ))
        }
    }

    override fun WriteCardResult(code: ResultCode) {
        runOnUiThread {
            methodChannel.invokeMethod("onWriteCard", mapOf(
                "resultCode" to code.name
            ))
        }
    }
}