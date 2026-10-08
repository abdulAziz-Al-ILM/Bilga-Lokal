package com.ilmmizan.bilga

import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Base64
import org.json.JSONObject
import java.security.KeyFactory
import java.security.Signature
import java.security.spec.X509EncodedKeySpec
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceFragmentActivity() {
    private var files: FilesBridge? = null
    private var assistant: MethodChannel? = null
    private var launchAgent = false
    private var recognizer: SpeechRecognizer? = null
    private var voiceResult: MethodChannel.Result? = null
    private var voiceArgs: Map<String, Any?> = emptyMap()
    private val handler = Handler(Looper.getMainLooper())
    private val timeout = Runnable { finishVoice(null, "timeout") }

    override fun onCreate(savedInstanceState: Bundle?) {
        launchAgent = intent?.action == "com.ilmmizan.bilga.OPEN_AGENT"
        super.onCreate(savedInstanceState)
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        files?.receive(intent)
        if (intent.action == "com.ilmmizan.bilga.OPEN_AGENT") {
            launchAgent = true
            assistant?.invokeMethod("openAgent", null)
        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        VaultBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        files = FilesBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        files?.receive(intent)
        assistant = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bilga/assistant")
        assistant?.setMethodCallHandler { call, result ->
            if (call.method == "consumeAgentLaunch") {
                result.success(launchAgent)
                launchAgent = false
            } else result.notImplemented()
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bilga/voice").setMethodCallHandler { call, result ->
            when (call.method) {
                "cancel" -> { finishVoice(null, "cancelled"); result.success(null) }
                "listen" -> {
                    if (voiceResult != null) result.error("busy", "Already listening", null)
                    else {
                        voiceResult = result
                        voiceArgs = mapOf("language" to call.argument<String>("language"), "online" to call.argument<Boolean>("online"))
                        if (checkSelfPermission(Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
                            requestPermissions(arrayOf(Manifest.permission.RECORD_AUDIO), 711)
                        } else startVoice()
                    }
                }
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bilga/purchase").setMethodCallHandler { call, result ->
            if (call.method != "verify") { result.notImplemented(); return@setMethodCallHandler }
            try {
                val json = call.argument<String>("json") ?: ""
                val keyBytes = Base64.decode(call.argument<String>("key"), Base64.DEFAULT)
                val key = KeyFactory.getInstance("RSA").generatePublic(X509EncodedKeySpec(keyBytes))
                val verifier = Signature.getInstance("SHA1withRSA")
                verifier.initVerify(key)
                verifier.update(json.toByteArray(Charsets.UTF_8))
                val valid = verifier.verify(Base64.decode(call.argument<String>("signature"), Base64.DEFAULT))
                val receipt = JSONObject(json)
                val product = call.argument<String>("product")
                val products = receipt.optJSONArray("productIds")
                val matches = receipt.optString("productId") == product ||
                    (products != null && (0 until products.length()).any { products.optString(it) == product })
                result.success(valid && matches && receipt.optString("packageName") == packageName &&
                    receipt.has("purchaseState") && receipt.optInt("purchaseState", -1) == 0 &&
                    receipt.optString("purchaseToken").isNotEmpty())
            } catch (_: Exception) { result.success(false) }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bilga/security").setMethodCallHandler { call, result ->
            if (call.method == "secure") {
                if (call.arguments == true) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                result.success(null)
            } else result.notImplemented()
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 711) {
            if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED && voiceResult != null) startVoice()
            else finishVoice(null, "permission")
        }
    }
    private fun startVoice() {
        try {
            val online = voiceArgs["online"] == true
            if (!online && (Build.VERSION.SDK_INT < 31 || !SpeechRecognizer.isOnDeviceRecognitionAvailable(this))) {
                finishVoice(null, "offline_unavailable"); return
            }
            recognizer = if (!online && Build.VERSION.SDK_INT >= 31) SpeechRecognizer.createOnDeviceSpeechRecognizer(this)
                else SpeechRecognizer.createSpeechRecognizer(this)
            recognizer?.setRecognitionListener(object : RecognitionListener {
                override fun onReadyForSpeech(params: Bundle?) {}
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onError(error: Int) { finishVoice(null, "speech_$error") }
                override fun onResults(results: Bundle?) {
                    finishVoice(results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull(), null)
                }
                override fun onPartialResults(partialResults: Bundle?) {}
                override fun onEvent(eventType: Int, params: Bundle?) {}
            })
            val request = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, voiceArgs["language"] as? String ?: "en-US")
                putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, false)
                putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            }
            handler.postDelayed(timeout, 30000)
            recognizer?.startListening(request)
        } catch (_: Exception) { finishVoice(null, "unavailable") }
    }
    private fun finishVoice(text: String?, error: String?) {
        val result = voiceResult
        voiceResult = null
        handler.removeCallbacks(timeout)
        recognizer?.destroy()
        recognizer = null
        if (error != null) result?.error(error, "Speech session ended", null) else result?.success(text)
    }
    override fun onStop() { finishVoice(null, "cancelled"); super.onStop() }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (files?.activityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }
    override fun onDestroy() { files?.close(); files = null; finishVoice(null, "cancelled"); assistant = null; super.onDestroy() }
}
