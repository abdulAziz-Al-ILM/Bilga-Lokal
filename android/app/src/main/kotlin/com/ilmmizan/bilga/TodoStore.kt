package com.ilmmizan.bilga

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import org.json.JSONObject
import java.io.File
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Independent encrypted, atomic, private no-backup mirror. Never holds DB keys. */
internal object TodoStore {
    private const val ALIAS = "bilga.todo.reminders.v1"
    internal fun file(c: Context, name: String = "state") = AtomicFile(File(c.noBackupFilesDir, "todo-reminders/$name.bin").also { check(it.parentFile!!.exists() || it.parentFile!!.mkdirs()) })
    private fun key(create: Boolean): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        if (!store.containsAlias(ALIAS) && create) {
            KeyGenerator.getInstance("AES", "AndroidKeyStore").apply {
                init(KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                    .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).setKeySize(256).build())
                generateKey()
            }
        }
        return store.getKey(ALIAS, null) as SecretKey
    }
    @Synchronized fun read(c: Context, name: String = "state"): JSONObject? = try {
        val f = file(c,name)
        if (!f.baseFile.exists()) null else {
            require(f.baseFile.length() <= 32 * 1024 * 1024)
            val bytes=f.readFully(); require(bytes.size>=28)
            val cipher=Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE,key(false),GCMParameterSpec(128,bytes.copyOfRange(0,12)))
            cipher.updateAAD("$ALIAS:$name".toByteArray())
            JSONObject(String(cipher.doFinal(bytes.copyOfRange(12,bytes.size)),Charsets.UTF_8))
        }
    } catch (_: Exception) { null }
    @Synchronized fun write(c: Context,value: JSONObject,name: String = "state") {
        val plain=value.toString().toByteArray(Charsets.UTF_8); require(plain.size<=32*1024*1024)
        val cipher=Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE,key(true)); cipher.updateAAD("$ALIAS:$name".toByteArray())
        val f=file(c,name); val output=f.startWrite()
        try { output.write(cipher.iv+cipher.doFinal(plain)); f.finishWrite(output) }
        catch (e: Exception) { f.failWrite(output); throw e }
    }
}
