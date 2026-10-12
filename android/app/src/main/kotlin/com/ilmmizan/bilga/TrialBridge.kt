package com.ilmmizan.bilga

import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.SystemClock
import android.provider.Settings
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Separate from the vault: licensing must never rotate/delete user data keys. */
class TrialBridge(private val context: Context, messenger: BinaryMessenger) {
    private val alias = "bilga.trial.v1"
    private val file = AtomicFile(File(context.noBackupFilesDir, "core-trial-v1"))
    private val keys = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    init {
        MethodChannel(messenger, "bilga/trial").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "read" -> result.success(mapOf(
                        "state" to read(), "wall" to System.currentTimeMillis(),
                        "elapsed" to SystemClock.elapsedRealtime(),
                        "boot" to Settings.Global.getInt(context.contentResolver, Settings.Global.BOOT_COUNT),
                        "debug" to ((context.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0)
                    ))
                    "write" -> { write(call.arguments as String); result.success(null) }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                // Never silently replace unreadable/removed state with 40 new days.
                result.error("trial_storage", "Trial state could not be verified", null)
            }
        }
    }

    private fun read(): String? {
        val bytes = try { file.readFully() } catch (e: java.io.FileNotFoundException) {
            check(!keys.containsAlias(alias)) { "missing_trial" }
            return null
        }
        check(keys.containsAlias(alias) && bytes.size > 28)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, keys.getKey(alias, null) as SecretKey,
            GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
        return String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)), Charsets.UTF_8)
    }

    private fun write(json: String) {
        val state = JSONObject(json)
        check(state.getInt("version") == 1 && state.getLong("started") > 0)
        check(state.getLong("effective") >= state.getLong("started"))
        if (!keys.containsAlias(alias)) {
            check(!file.baseFile.exists())
            KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
                init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).setKeySize(256).build())
                generateKey()
            }
        } else {
            val old = JSONObject(read() ?: error("missing_trial"))
            check(state.getLong("started") == old.getLong("started"))
            check(state.getLong("effective") >= old.getLong("effective"))
            check(state.getString("installation") == old.getString("installation"))
            check(!old.getBoolean("introduced") || state.getBoolean("introduced"))
        }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, keys.getKey(alias, null) as SecretKey)
        val bytes = cipher.iv + cipher.doFinal(json.toByteArray(Charsets.UTF_8))
        val stream = file.startWrite()
        try { stream.write(bytes); file.finishWrite(stream) }
        catch (e: Exception) { file.failWrite(stream); throw e }
    }
}
