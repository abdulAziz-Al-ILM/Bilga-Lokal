package com.ilmmizan.bilga

import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Bundle
import android.util.Base64
import org.json.JSONObject
import java.security.KeyFactory
import java.security.Signature
import java.security.spec.X509EncodedKeySpec
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

open class MainActivity : AudioServiceFragmentActivity() {
    private var files: FilesBridge? = null
    private var assistant: MethodChannel? = null
    private var launchAgent = false
    private var todoBridge: TodoBridge? = null
    private var notesWidget: NotesWidgetBridge? = null
    private var moduleReminders: ModuleReminderBridge? = null
    private var speech: SpeechBridge? = null
    private var speechOutput: SpeechOutput? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        launchAgent = intent?.action == "com.ilmmizan.bilga.OPEN_AGENT"
        super.onCreate(savedInstanceState)
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        files?.receive(intent)
        notesWidget?.receive(intent)
        todoBridge?.receive(intent)
        moduleReminders?.receive(intent)
        if (intent.action == "com.ilmmizan.bilga.OPEN_AGENT") {
            launchAgent = true
            assistant?.invokeMethod("openAgent", null)
        }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        WidgetTheme.bind(this,flutterEngine.dartExecutor.binaryMessenger)
        todoBridge = TodoBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        notesWidget = NotesWidgetBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        moduleReminders = ModuleReminderBridge(this,flutterEngine.dartExecutor.binaryMessenger)
        speech?.close();speech=SpeechBridge(this,flutterEngine.dartExecutor.binaryMessenger)
        speechOutput?.close()
        speechOutput = SpeechOutput(this, flutterEngine.dartExecutor.binaryMessenger)
        VaultBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        TrialBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        files = FilesBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        files?.receive(intent)
        assistant = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bilga/assistant")
        assistant?.setMethodCallHandler { call, result ->
            if (call.method == "consumeAgentLaunch") {
                result.success(launchAgent)
                launchAgent = false
            } else result.notImplemented()
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
        // Cached audio-service engines may have attempted their first sync before
        // these Activity channels (including Vault) existed. Retry only after all
        // handlers are installed; cold Dart still performs its normal first sync.
        notesWidget?.ready()
        todoBridge?.ready()
        moduleReminders?.ready()
    }

    override fun onStart() { super.onStart(); speech?.foreground(true); speechOutput?.foreground(true); TodoReminders.foreground=true; stopService(Intent(this,TodoOverlayService::class.java)) }
    override fun onStop() { speech?.foreground(false); speechOutput?.foreground(false);TodoReminders.foreground=false; super.onStop() }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (files?.activityResult(requestCode, resultCode, data) == true) return
        super.onActivityResult(requestCode, resultCode, data)
    }
    override fun onRequestPermissionsResult(requestCode:Int,permissions:Array<out String>,grantResults:IntArray){
        if(speech?.permissionResult(requestCode,grantResults)==true)return
        super.onRequestPermissionsResult(requestCode,permissions,grantResults)
    }
    override fun onDestroy() { speechOutput?.close(); speechOutput=null; speech?.close();speech=null; moduleReminders?.close();moduleReminders=null; todoBridge?.close(); todoBridge=null; notesWidget?.close(); notesWidget = null; files?.close(); files = null; assistant = null; super.onDestroy() }
}
