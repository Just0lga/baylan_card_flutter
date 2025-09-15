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
        
        // Sabit URL ve Lisans anahtarı
        private const val LICENSE_KEY = "9283ebb4-9822-46fa-bbe3-ac4a4d25b8c2"
        private const val BAYLAN_SERVER_URL = "https://baylanbms.maraskaski.gov.tr:55176/"
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
            
            // Çalışan kod gibi GlobalScope kullan
            GlobalScope.launch {
                baylanCardCreditLibrary.ActivateNFCCardReader()
                checkLicenceSync() // Sync versiyon
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Flutter engine configuration failed", e)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "MainActivity created")
        
        // Sabit URL'yi başlangıçta set et
        try {
            baylanCardCreditLibrary.SetUrl(BAYLAN_SERVER_URL)
            Log.d(TAG, "Default URL set: $BAYLAN_SERVER_URL")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to set default URL", e)
        }
    }
    
    // Çalışan koddan kopyalanan sync CheckLicence metodu
    private fun checkLicenceSync() {
        try {
            if (baylanCardCreditLibrary.CheckLicence().ResultCode == enResultCodes.LicenseisValid) {
                Log.d(TAG, "License is valid")
                runOnUiThread {
                    // Flutter'a bildir
                    eventSink?.success(mapOf(
                        "type" to "licenseValid",
                        "message" to "License is valid"
                    ))
                }
            } else {
                Log.d(TAG, "License invalid, getting new license...")
                
                val licenseRequest = LicenseRequest()
                licenseRequest.requestId = UUID.randomUUID().toString()
                licenseRequest.licenceKey = LICENSE_KEY
                
                val resultModel = baylanCardCreditLibrary.GetLicense(licenseRequest)
                
                if (resultModel.ResultCode == enResultCodes.LicenseisValid) {
                    Log.d(TAG, "New license acquired successfully")
                    runOnUiThread {
                        eventSink?.success(mapOf(
                            "type" to "licenseAcquired",
                            "message" to resultModel.Message
                        ))
                    }
                } else {
                    Log.e(TAG, "License acquisition failed: ${resultModel.Message}")
                    runOnUiThread {
                        eventSink?.success(mapOf(
                            "type" to "licenseError",
                            "message" to resultModel.Message
                        ))
                    }
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "License check error", e)
            runOnUiThread {
                eventSink?.success(mapOf(
                    "type" to "licenseError",
                    "message" to e.message
                ))
            }
        }
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
    
    // Çalışan kod stilinde düzeltilmiş checkLicense
    private fun checkLicense(result: Result) {
        try {
            val licenseResult = baylanCardCreditLibrary.CheckLicence()
            
            val response = mapOf(
                "resultCode" to licenseResult.ResultCode.name,
                "message" to (licenseResult.Message ?: ""),
                "isValid" to (licenseResult.ResultCode == enResultCodes.LicenseisValid)
            )
            
            result.success(response)
        } catch (e: Exception) {
            Log.e(TAG, "License check failed", e)
            result.error("LICENSE_CHECK_ERROR", e.message, null)
        }
    }

    private fun getLicense(call: MethodCall, result: Result) {
        try {
            val requestId = call.argument<String>("requestId") ?: UUID.randomUUID().toString()
            val licenseKey = call.argument<String>("licenseKey") ?: LICENSE_KEY
            
            val licenseRequest = LicenseRequest().apply {
                this.requestId = requestId
                this.licenceKey = licenseKey
            }
            
            val licenseResult = baylanCardCreditLibrary.GetLicense(licenseRequest)
            
            val response = mapOf(
                "resultCode" to licenseResult.ResultCode.name,
                "message" to (licenseResult.Message ?: ""),
                "isValid" to (licenseResult.ResultCode == enResultCodes.LicenseisValid)
            )
            
            result.success(response)
        } catch (e: Exception) {
            Log.e(TAG, "Get license failed", e)
            result.error("GET_LICENSE_ERROR", e.message, null)
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
            
            // Sabit URL'yi her seferinde set et (çalışan kod gibi)
            baylanCardCreditLibrary.SetUrl(BAYLAN_SERVER_URL)
            Log.d(TAG, "URL set for read operation: $BAYLAN_SERVER_URL")
            
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
            
            // URL'yi yazma işlemi için de set et
            baylanCardCreditLibrary.SetUrl(BAYLAN_SERVER_URL)
            
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
            Log.d(TAG, "Card write started - RequestId: $requestId")
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

    // IBaylanCardCreditLibrary interface implementations - çalışan kodla aynı
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