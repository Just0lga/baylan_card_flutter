package com.example.baylan_card_flutter

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID
import android.util.Log
import com.bubuapps.baylancardcreditlibrary.BaylanCardCreditLibrary
import com.bubuapps.baylancardcreditlibrary.Model.DTO.Enums.ResultCode
import com.bubuapps.baylancardcreditlibrary.Model.DTO.Enums.enOperationType
import com.bubuapps.baylancardcreditlibrary.Interface.IBaylanCardCreditLibrary
import com.bubuapps.baylancardcreditlibrary.Model.DTO.ConsumerCardDTO
import com.bubuapps.baylancardcreditlibrary.Model.DTO.CreditRequestDTO
import com.bubuapps.baylancardcreditlibrary.Model.DTO.Enums.enResultCodes
import com.bubuapps.baylancardcreditlibrary.Model.DTO.LicenseRequest
import com.bubuapps.baylancardcreditlibrary.Model.DTO.ReadCardRequest


class MainActivity: FlutterActivity(), IBaylanCardCreditLibrary {
    
    companion object {
        private const val TAG = "BaylanCardFlutter"
        private const val CHANNEL = "baylan_card_credit"
        private const val EVENT_CHANNEL = "baylan_card_credit_events"
        
        // PRODUCTION LICENSE KEY - Buraya gerçek lisans anahtarınızı girin
        private const val LICENSE_KEY = "9283ebb4-9822-46fa-bbe3-ac4a4d25b8c2"
    }
    
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private lateinit var baylanCardCreditLibrary: BaylanCardCreditLibrary
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        try {
            // Baylan kütüphanesini başlat
            baylanCardCreditLibrary = BaylanCardCreditLibrary(this)
            
            // Method channel kurulumu
            methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            
            // Event channel kurulumu
            eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
            eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
            
            // Method call handler
            methodChannel.setMethodCallHandler { call, result ->
                handleMethodCall(call, result)
            }
            
            // NFC'yi arkaplanda başlat
            CoroutineScope(Dispatchers.IO).launch {
                try {
                    baylanCardCreditLibrary.ActivateNFCCardReader()
                    Log.d(TAG, "NFC Reader activated successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "NFC activation failed", e)
                }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Flutter engine configuration failed", e)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "MainActivity created")
    }
    
    override fun onDestroy() {
        super.onDestroy()
        try {
            baylanCardCreditLibrary.DisapleNFCReader()
            Log.d(TAG, "NFC Reader deactivated on destroy")
        } catch (e: Exception) {
            Log.e(TAG, "Error deactivating NFC", e)
        }
    }
    
    private fun handleMethodCall(call: MethodCall, result: Result) {
        try {
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
        } catch (e: Exception) {
            Log.e(TAG, "Method call error: ${call.method}", e)
            result.error("METHOD_ERROR", "Unexpected error: ${e.message}", null)
        }
    }
    
    // MainActivity.kt - checkLicense ve getLicense metodlarını bu şekilde güncelleyin

private fun checkLicense(result: Result) {
    // Background thread'de çalıştır
    CoroutineScope(Dispatchers.IO).launch {
        try {
            Log.d(TAG, "=== LICENSE CHECK STARTED ===")
            Log.d(TAG, "Using license key: ${LICENSE_KEY.take(8)}...")
            
            val licenseResult = baylanCardCreditLibrary.CheckLicence()
            
            Log.d(TAG, "License check result code: ${licenseResult.ResultCode}")
            Log.d(TAG, "License check message: ${licenseResult.Message}")
            Log.d(TAG, "License is valid: ${licenseResult.ResultCode == enResultCodes.LicenseisValid}")
            
            val response = mapOf(
                "resultCode" to licenseResult.ResultCode.name,
                "message" to (licenseResult.Message ?: ""),
                "isValid" to (licenseResult.ResultCode == enResultCodes.LicenseisValid)
            )
            
            // Ana thread'e geri dön ve result'ı gönder
            withContext(Dispatchers.Main) {
                result.success(response)
            }
            Log.d(TAG, "License check completed successfully")
        } catch (e: Exception) {
            Log.e(TAG, "License check failed with exception", e)
            withContext(Dispatchers.Main) {
                result.error("LICENSE_CHECK_ERROR", e.message, null)
            }
        }
    }
}

private fun getLicense(call: MethodCall, result: Result) {
    // Background thread'de çalıştır
    CoroutineScope(Dispatchers.IO).launch {
        try {
            Log.d(TAG, "=== GET LICENSE STARTED ===")
            
            val requestId = call.argument<String>("requestId") ?: UUID.randomUUID().toString()
            val licenseKey = call.argument<String>("licenseKey") ?: LICENSE_KEY
            
            Log.d(TAG, "Request ID: $requestId")
            Log.d(TAG, "License key: ${licenseKey.take(8)}...")
            
            // Validation
            if (licenseKey.isEmpty()) {
                Log.e(TAG, "License key is empty!")
                withContext(Dispatchers.Main) {
                    result.error("INVALID_PARAMETER", "License key cannot be empty", null)
                }
                return@launch
            }
            
            val licenseRequest = LicenseRequest().apply {
                this.requestId = requestId
                this.licenceKey = licenseKey
            }
            
            Log.d(TAG, "Calling baylanCardCreditLibrary.GetLicense...")
            val licenseResult = baylanCardCreditLibrary.GetLicense(licenseRequest)
            
            Log.d(TAG, "Get license result code: ${licenseResult.ResultCode}")
            Log.d(TAG, "Get license message: ${licenseResult.Message}")
            Log.d(TAG, "License acquired successfully: ${licenseResult.ResultCode == enResultCodes.LicenseisValid}")
            
            val response = mapOf(
                "resultCode" to licenseResult.ResultCode.name,
                "message" to (licenseResult.Message ?: ""),
                "isValid" to (licenseResult.ResultCode == enResultCodes.LicenseisValid)
            )
            
            // Ana thread'e geri dön ve result'ı gönder
            withContext(Dispatchers.Main) {
                result.success(response)
            }
            Log.d(TAG, "Get license completed successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Get license failed with exception", e)
            withContext(Dispatchers.Main) {
                result.error("GET_LICENSE_ERROR", e.message, null)
            }
        }
    }
}
    private fun activateNFC(result: Result) {
        try {
            val resultCode = baylanCardCreditLibrary.ActivateNFCCardReader()
            result.success(resultCode.name)
            Log.d(TAG, "NFC activation result: ${resultCode.name}")
        } catch (e: Exception) {
            Log.e(TAG, "NFC activation failed", e)
            result.error("NFC_ACTIVATE_ERROR", e.message, null)
        }
    }

    private fun deactivateNFC(result: Result) {
        try {
            val resultCode = baylanCardCreditLibrary.DisapleNFCReader()
            result.success(resultCode.name)
            Log.d(TAG, "NFC deactivation result: ${resultCode.name}")
        } catch (e: Exception) {
            Log.e(TAG, "NFC deactivation failed", e)
            result.error("NFC_DEACTIVATE_ERROR", e.message, null)
        }
    }

    private fun readCard(call: MethodCall, result: Result) {
        try {
            val requestId = call.argument<String>("requestId") ?: UUID.randomUUID().toString()
            
            if (requestId.isEmpty()) {
                result.error("INVALID_PARAMETER", "RequestId cannot be empty", null)
                return
            }
            
            val readCardRequest = ReadCardRequest().apply {
                this.requestId = requestId
            }
            
            baylanCardCreditLibrary.ReadCard(readCardRequest)
            result.success("READ_STARTED")
            Log.d(TAG, "Card read started with RequestId: $requestId")
        } catch (e: Exception) {
            Log.e(TAG, "Read card failed", e)
            result.error("READ_CARD_ERROR", e.message, null)
        }
    }

    private fun writeCard(call: MethodCall, result: Result) {
        try {
            val requestId = call.argument<String>("requestId") ?: UUID.randomUUID().toString()
            val operationType = call.argument<Int>("operationType") ?: 0
            val credit = call.argument<Double>("credit") ?: 0.0
            val reserveCreditLimit = call.argument<Double>("reserveCreditLimit") ?: 0.0
            val criticalCreditLimit = call.argument<Double>("criticalCreditLimit") ?: 0.0
            val paydeskCode = call.argument<String>("paydeskCode")
            val customerType = call.argument<String>("customerType")
            
            // Validation
            if (requestId.isEmpty()) {
                result.error("INVALID_PARAMETER", "RequestId cannot be empty", null)
                return
            }
            
            if (operationType != 2 && credit < 0) { // ClearCredits dışında negative olamaz
                result.error("INVALID_PARAMETER", "Credit values cannot be negative", null)
                return
            }
            
            if (reserveCreditLimit < 0 || criticalCreditLimit < 0) {
                result.error("INVALID_PARAMETER", "Limit values cannot be negative", null)
                return
            }
            
            val enOperationTypeVal = when (operationType) {
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
            Log.d(TAG, "Card write started - RequestId: $requestId, Operation: ${enOperationTypeVal.name}, Credit: $credit")
        } catch (e: Exception) {
            Log.e(TAG, "Write card failed", e)
            result.error("WRITE_CARD_ERROR", e.message, null)
        }
    }

    private fun setUrl(call: MethodCall, result: Result) {
        try {
            val url = call.argument<String>("url") ?: ""
            if (url.isEmpty()) {
                result.error("INVALID_PARAMETER", "URL cannot be empty", null)
                return
            }
            
            baylanCardCreditLibrary.SetUrl(url)
            result.success("URL_SET")
            Log.d(TAG, "URL set: $url")
        } catch (e: Exception) {
            Log.e(TAG, "Set URL failed", e)
            result.error("SET_URL_ERROR", e.message, null)
        }
    }

    private fun getUrl(result: Result) {
        try {
            val url = baylanCardCreditLibrary.GetUrl()
            result.success(url ?: "")
            Log.d(TAG, "URL retrieved: $url")
        } catch (e: Exception) {
            Log.e(TAG, "Get URL failed", e)
            result.error("GET_URL_ERROR", e.message, null)
        }
    }

    // IBaylanCardCreditLibrary interface implementations
    override fun OnResult(tag: String?, code: ResultCode) {
        runOnUiThread {
            try {
                val data = mapOf(
                    "type" to "onResult",
                    "message" to (tag ?: ""),
                    "resultCode" to code.name
                )
                
                eventSink?.success(data)
                Log.d(TAG, "OnResult - Code: ${code.name}, Message: $tag")
            } catch (e: Exception) {
                Log.e(TAG, "OnResult event send failed", e)
            }
        }
    }

    override fun ReadCardResult(consumerCardDTO: ConsumerCardDTO?, code: ResultCode) {
        runOnUiThread {
            try {
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
                
                val data = mapOf(
                    "type" to "onReadCard",
                    "cardData" to cardData,
                    "resultCode" to code.name
                )
                
                eventSink?.success(data)
                Log.d(TAG, "ReadCardResult - Code: ${code.name}, CardData: ${cardData != null}")
            } catch (e: Exception) {
                Log.e(TAG, "ReadCardResult event send failed", e)
            }
        }
    }

    override fun WriteCardResult(code: ResultCode) {
        runOnUiThread {
            try {
                val data = mapOf(
                    "type" to "onWriteCard",
                    "resultCode" to code.name
                )
                
                eventSink?.success(data)
                Log.d(TAG, "WriteCardResult - Code: ${code.name}")
            } catch (e: Exception) {
                Log.e(TAG, "WriteCardResult event send failed", e)
            }
        }
    }
}

/*
package com.example.baylan_card_flutter

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.EventChannel
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import java.util.UUID
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



class MainActivity: FlutterActivity(), IBaylanCardCreditLibrary {
    // Flutter ile kotlin arasındaki bağlantıyı yapacak olan kanal
    // 8 farklı method handle ediliyor
    private val CHANNEL = "baylan_card_credit" // Flutter ile konuşma kanalının adı
    private val EVENT_CHANNEL = "baylan_card_credit_events" // Event channel adı
    private lateinit var methodChannel: MethodChannel // Flutter ile iletişim nesnesi
    private lateinit var eventChannel: EventChannel // Event channel nesnesi
    private var eventSink: EventChannel.EventSink? = null // Event gönderici
    private lateinit var baylanCardCreditLibrary: BaylanCardCreditLibrary // Baylan kütüphanesinin nesnesi

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Baylan kütüphanesini başlat
        baylanCardCreditLibrary = BaylanCardCreditLibrary(this)
        
        // Flutter ile konuşma kanalı kur
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        
        // Event channel kurulumu
        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
        
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
        val licenseResult = baylanCardCreditLibrary.CheckLicence()
        if (licenseResult.ResultCode == enResultCodes.LicenseisValid) {
            val response = mapOf(
                "resultCode" to licenseResult.ResultCode.name,
                "message" to licenseResult.Message,
                "isValid" to true
            )
            result.success(response)
        } else {
            // Lisans başarısız → GetLicense çağır
            val licenseRequest = LicenseRequest().apply {
                this.requestId = UUID.randomUUID().toString()
                this.licenceKey = "9283ebb4-9822-46fa-bbe3-ac4a4d25b8c2" // Flutter’dan da alabilirsin
            }

            val newLicense = baylanCardCreditLibrary.GetLicense(licenseRequest)
            val response = mapOf(
                "resultCode" to newLicense.ResultCode.name,
                "message" to newLicense.Message,
                "isValid" to (newLicense.ResultCode == enResultCodes.LicenseisValid)
            )
            result.success(response)
        }
    } catch (e: Exception) {
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
            val data = mapOf(
                "type" to "onResult",
                "message" to (tag ?: ""),
                "resultCode" to code.name
            )
            
            // Hem MethodChannel hem EventChannel'a gönder
            methodChannel.invokeMethod("onResult", data)
            eventSink?.success(data)
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
            
            val data = mapOf(
                "type" to "onReadCard",
                "cardData" to cardData,
                "resultCode" to code.name
            )
            
            // Hem MethodChannel hem EventChannel'a gönder
            methodChannel.invokeMethod("onReadCard", data)
            eventSink?.success(data)
        }
    }

    override fun WriteCardResult(code: ResultCode) {
        runOnUiThread {
            val data = mapOf(
                "type" to "onWriteCard",
                "resultCode" to code.name
            )
            
            // Hem MethodChannel hem EventChannel'a gönder
            methodChannel.invokeMethod("onWriteCard", data)
            eventSink?.success(data)
        }
    }
}
 */
