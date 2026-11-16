package com.papigiras.lab

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import android.util.Base64
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream
import java.io.FileNotFoundException
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * One explicitly remembered login per role, scoped to this application/device.
 * Only authenticated ciphertext is written to noBackupFilesDir. Keys remain in
 * Android Keystore; there are no plaintext preferences or cloud/backup copies.
 * Dart is responsible for consent and only invokes save after successful login.
 */
internal class SecureCredentialStore(context: Context) : MethodChannel.MethodCallHandler {
    private val appContext = context.applicationContext
    private val roles = setOf("attorney", "passenger", "coordinator")
    private val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val arguments = call.arguments as? Map<*, *>
        val role = arguments?.get("role") as? String
        if (role !in roles) {
            result.error("invalid-role", null, null)
            return
        }
        // No exception text or credential payload is returned/logged.
        try {
            when (call.method) {
                "contains" -> result.success(contains(role!!))
                "read" -> result.success(read(role!!))
                "save" -> {
                    val rut = arguments?.get("rut") as? String
                    val password = arguments?.get("password") as? String
                    if (rut.isNullOrBlank() || rut.length > 32 ||
                        password.isNullOrEmpty() || password.length > 4096) {
                        result.error("invalid-credential", null, null)
                        return
                    }
                    save(role!!, rut, password)
                    result.success(null)
                }
                "delete" -> {
                    file(role!!).delete()
                    if (file(role).baseFile.exists()) {
                        result.error("credential-store-unavailable", null, null)
                        return
                    }
                    keyStore.deleteEntry(alias(role))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        } catch (_: Exception) {
            result.error("credential-store-unavailable", null, null)
        }
    }

    private fun alias(role: String) = "${appContext.packageName}.pilo.sign-in.$role.v1"
    private fun file(role: String) = AtomicFile(
        File(appContext.noBackupFilesDir, "pilo-sign-in-$role.enc")
    )
    private fun aad(role: String) = alias(role).toByteArray(Charsets.UTF_8)

    private fun key(role: String, create: Boolean): SecretKey? {
        (keyStore.getKey(alias(role), null) as? SecretKey)?.let { return it }
        if (!create) return null
        val builder = KeyGenParameterSpec.Builder(
            alias(role), KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        ).setKeySize(256)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setRandomizedEncryptionRequired(true)
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
            .apply { init(builder.build()) }.generateKey()
    }

    private fun save(role: String, rut: String, password: String) {
        val plaintext = JSONObject().put("rut", rut).put("password", password)
            .toString().toByteArray(Charsets.UTF_8)
        try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, key(role, create = true))
            cipher.updateAAD(aad(role))
            val envelope = JSONObject().put("version", 1)
                .put("iv", Base64.encodeToString(cipher.iv, Base64.NO_WRAP))
                .put("data", Base64.encodeToString(cipher.doFinal(plaintext), Base64.NO_WRAP))
                .toString().toByteArray(Charsets.UTF_8)
            val destination = file(role)
            var stream: FileOutputStream? = null
            try {
                stream = destination.startWrite()
                stream.write(envelope)
                destination.finishWrite(stream)
            } catch (error: Exception) {
                destination.failWrite(stream)
                throw error
            }
        } finally {
            plaintext.fill(0)
        }
    }

    private fun contains(role: String): Boolean = try {
        // openRead also restores an interrupted AtomicFile write, when necessary.
        file(role).openRead().use { true }
    } catch (_: FileNotFoundException) {
        false
    }

    private fun read(role: String): Map<String, String>? {
        val source = file(role)
        val bytes = try {
            source.openRead().use { stream ->
                // Bound local data before allocating/decrypting it. openRead has
                // already recovered any interrupted AtomicFile write.
                if (source.baseFile.length() !in 1..32768) throw IllegalStateException()
                stream.readBytes()
            }
        } catch (_: FileNotFoundException) {
            return null
        }
        val envelope = JSONObject(String(bytes, Charsets.UTF_8))
        if (envelope.getInt("version") != 1) throw IllegalStateException()
        val iv = Base64.decode(envelope.getString("iv"), Base64.NO_WRAP)
        if (iv.size != 12) throw IllegalStateException()
        val secret = key(role, create = false) ?: throw IllegalStateException()
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, secret, GCMParameterSpec(128, iv))
        cipher.updateAAD(aad(role))
        val plaintext = cipher.doFinal(Base64.decode(envelope.getString("data"), Base64.NO_WRAP))
        try {
            val saved = JSONObject(String(plaintext, Charsets.UTF_8))
            val rut = saved.getString("rut")
            val password = saved.getString("password")
            if (rut.isBlank() || rut.length > 32 || password.isEmpty() || password.length > 4096) {
                throw IllegalStateException()
            }
            return mapOf("rut" to rut, "password" to password)
        } finally {
            plaintext.fill(0)
        }
    }
}
