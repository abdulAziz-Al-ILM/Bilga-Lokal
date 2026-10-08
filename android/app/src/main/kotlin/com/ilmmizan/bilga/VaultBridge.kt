package com.ilmmizan.bilga
import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.StatFs
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
class VaultBridge(private val activity: Activity, messenger: BinaryMessenger) {
 init {MethodChannel(messenger,"bilga/vault").setMethodCallHandler {call,result ->
  try {when(call.method){
   "key" -> result.success(key())
   "device" -> {val info=ActivityManager.MemoryInfo();(activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager).getMemoryInfo(info);result.success(mapOf("ram" to info.totalMem,"available" to info.availMem,"lowMemory" to info.lowMemory,"sdk" to Build.VERSION.SDK_INT,"arm64" to Build.SUPPORTED_ABIS.contains("arm64-v8a"),"disk" to StatFs(activity.filesDir.path).availableBytes))}
   else -> result.notImplemented()
  }} catch(_:Exception){result.error("vault","Private storage unavailable",null)}
 }}
 @Synchronized private fun key():String {
  val store=KeyStore.getInstance("AndroidKeyStore").apply{load(null)};val alias="bilga.vault.wrap.v1"
  if(!store.containsAlias(alias)){KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore").apply {init(KeyGenParameterSpec.Builder(alias,KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT).setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).setKeySize(256).build());generateKey()}}
  val key=store.getKey(alias,null) as SecretKey;val prefs=activity.getSharedPreferences("bilga-vault",Context.MODE_PRIVATE);val saved=prefs.getString("wrapped",null);val cipher=Cipher.getInstance("AES/GCM/NoPadding")
  val bytes=if(saved==null){val b=ByteArray(32);SecureRandom().nextBytes(b);cipher.init(Cipher.ENCRYPT_MODE,key);val sealed=cipher.doFinal(b);check(prefs.edit().putString("wrapped",Base64.encodeToString(cipher.iv+sealed,Base64.NO_WRAP)).commit());b}else{val b=Base64.decode(saved,Base64.NO_WRAP);require(b.size==60);cipher.init(Cipher.DECRYPT_MODE,key,GCMParameterSpec(128,b.copyOfRange(0,12)));cipher.doFinal(b.copyOfRange(12,b.size))}
  return bytes.joinToString(""){"%02x".format(it.toInt() and 255)}
 }
}
