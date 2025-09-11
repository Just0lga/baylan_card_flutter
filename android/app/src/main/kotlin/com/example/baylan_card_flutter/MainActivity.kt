package com.example.baylan_card_flutter

import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result

import com.bubuapps.baylancardcreditlibrary.BaylanCardCreditLibrary
import com.bubuapps.baylancardcreditlibrary.Interface.IBaylanCardCreditLibrary
import com.bubuapps.baylancardcreditlibrary.Model.DTO.ConsumerCardDTO
import com.bubuapps.baylancardcreditlibrary.Model.DTO.CreditRequestDTO
import com.bubuapps.baylancardcreditlibrary.Model.DTO.Enums.ResultCode
import com.bubuapps.baylancardcreditlibrary.Model.DTO.Enums.enOperationType
import com.bubuapps.baylancardcreditlibrary.Model.DTO.Enums.enResultCodes
import com.bubuapps.baylancardcreditlibrary.Model.DTO.LicenseRequest
import com.bubuapps.baylancardcreditlibrary.Model.DTO.ReadCardRequest
import com.bubuapps.baylancardcreditlibrary.Model.Service.ResultModel
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.launch
import java.util.UUID

class MainActivity: FlutterActivity(), IBaylanCardCreditLibrary {
    private val CHANNEL = "baylan_card_credit"
    private lateinit var methodChannel: MethodChannel
    private lateinit var baylanCardCreditLibrary: BaylanCardCreditLibrary

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Baylan kütüphanesini initialize et
        baylanCardCreditLibrary = BaylanCardCreditLibrary(this)
        
        // Method channel'ı setup et
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
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
        
        // NFC'yi başlat
        GlobalScope.launch {
            baylanCardCreditLibrary.ActivateNFCCardReader()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    private fun checkLicense(result: Result) {
        try {
            val licenseResult = baylanCardCreditLibrary.CheckLicence()
            val response = mapOf(
                "resultCode" to licenseResult.ResultCode.name,
                "message" to licenseResult.Message,
                "isValid" to (licenseResult.ResultCode == enResultCodes.LicenseisValid)
            )
            result.success(response)
        } catch (e: Exception) {
            result.error("LICENSE_ERROR", e.message, null)
        }
    }

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

    private fun activateNFC(result: Result) {
        try {
            val resultCode = baylanCardCreditLibrary.ActivateNFCCardReader()
            result.success(resultCode.name)
        } catch (e: Exception) {
            result.error("NFC_ACTIVATE_ERROR", e.message, null)
        }
    }

    private fun deactivateNFC(result: Result) {
        try {
            val resultCode = baylanCardCreditLibrary.DisapleNFCReader()
            result.success(resultCode.name)
        } catch (e: Exception) {
            result.error("NFC_DEACTIVATE_ERROR", e.message, null)
        }
    }

    private fun readCard(call: MethodCall, result: Result) {
        try {
            val requestId = call.argument<String>("requestId") ?: UUID.randomUUID().toString()
            
            val readCardRequest = ReadCardRequest().apply {
                this.requestId = requestId
            }
            
            baylanCardCreditLibrary.ReadCard(readCardRequest)
            result.success("READ_STARTED")
        } catch (e: Exception) {
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

    override fun ReadCardResult(consumerCardDTO: ConsumerCardDTO?, code: ResultCode) {
        runOnUiThread {
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