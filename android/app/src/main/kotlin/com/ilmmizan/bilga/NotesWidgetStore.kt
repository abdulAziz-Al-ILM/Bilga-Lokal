package com.ilmmizan.bilga

import android.content.Context
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import org.json.JSONObject
import org.json.JSONArray
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Separate, no-backup, authenticated cache. Never opens or unwraps Bilga's DB. */
internal object NotesWidgetStore {
    private const val ALIAS = "bilga.notes.widget.v1"
    private fun file(context: Context, id: Int): AtomicFile {
        require(id > 0)
        val directory = File(context.noBackupFilesDir, "notes-widgets")
        check(directory.exists() || directory.mkdirs())
        return AtomicFile(File(directory, "$id.bin"))
    }
    @Synchronized private fun key(create: Boolean): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if (!store.containsAlias(ALIAS) && create) {
            val spec = KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).setKeySize(256)
            if (Build.VERSION.SDK_INT >= 28) spec.setUnlockedDeviceRequired(true)
            KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
                init(spec.build()); generateKey()
            }
        }
        return store.getKey(ALIAS, null) as SecretKey
    }
    @Synchronized fun read(context: Context, id: Int): JSONObject? = try {
        val input = file(context, id)
        if (!input.baseFile.exists() || input.baseFile.length() > 1_048_576) null else {
            val bytes = input.readFully()
            require(bytes.size >= 28)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key(false), GCMParameterSpec(128, bytes.copyOfRange(0, 12)))
            cipher.updateAAD("$ALIAS:$id".toByteArray(Charsets.UTF_8))
            JSONObject(String(cipher.doFinal(bytes.copyOfRange(12, bytes.size)), Charsets.UTF_8))
        }
    } catch (_: Exception) { null } // Locked, invalidated or corrupt => generic only.

    @Synchronized fun write(context: Context, id: Int, value: JSONObject) {
        val bytes = value.toString().toByteArray(Charsets.UTF_8)
        require(bytes.size <= 1_048_576)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key(true))
        cipher.updateAAD("$ALIAS:$id".toByteArray(Charsets.UTF_8))
        val sealed = cipher.iv + cipher.doFinal(bytes)
        val output = file(context, id)
        val stream = output.startWrite()
        try { stream.write(sealed); output.finishWrite(stream) }
        catch (e: Exception) { output.failWrite(stream); throw e }
    }
    fun delete(context: Context, id: Int) = file(context, id).delete()

    fun cachedIds(context: Context): IntArray = File(context.noBackupFilesDir, "notes-widgets")
        .listFiles().orEmpty().mapNotNull {
            Regex("([0-9]+)\\.bin(?:\\.bak|\\.new)?").matchEntire(it.name)
                ?.groupValues?.get(1)?.toIntOrNull()?.takeIf { id -> id > 0 }
        }.distinct().toIntArray()

    /** Logical removal of every app-owned snapshot, retaining widget configuration. */
    fun clearSnapshots(context: Context, epoch: Long, ids: IntArray = cachedIds(context), readValue: (Int)->JSONObject? = { read(context,it) }) {
        for (id in ids) {
            val value = readValue(id)
            // A locked Keystore is temporary. Keep its encrypted configuration;
            // the epoch already makes its stale rows invisible until re-export.
            if (value == null) continue
            value.put("rows", JSONArray()).put("approvals", JSONObject())
                .put("permissionEpoch", epoch).put("permissionsVersion", 1)
            try { write(context, id, value) }
            catch (_: Exception) { /* Epoch hides stale rows; preserve encrypted config. */ }
        }
    }
}
