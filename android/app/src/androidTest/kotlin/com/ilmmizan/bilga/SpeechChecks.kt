package com.ilmmizan.bilga

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.speech.SpeechRecognizer

/** Checks capability only. Never requests permission or starts the microphone. */
internal object SpeechChecks {
    fun run(c:Context):Pair<Boolean,String> {
        require(c.packageName=="com.ilmmizan.bilga.review" && c.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE!=0)
        return try {
            val app=c.packageManager.getApplicationInfo(c.packageName,PackageManager.GET_META_DATA)
            check(app.metaData.getString("bilga.voice.mode")=="push_to_talk")
            val packageInfo=c.packageManager.getPackageInfo(c.packageName,PackageManager.GET_PERMISSIONS)
            val permissions=packageInfo.requestedPermissions.orEmpty()
            check(permissions.contains("android.permission.RECORD_AUDIO"))
            check(!permissions.contains("android.permission.FOREGROUND_SERVICE_MICROPHONE"))
            val system=SpeechRecognizer.isRecognitionAvailable(c)
            val onDevice=Build.VERSION.SDK_INT>=31&&SpeechRecognizer.isOnDeviceRecognitionAvailable(c)
            val granted=c.checkSelfPermission("android.permission.RECORD_AUDIO")==PackageManager.PERMISSION_GRANTED
            (system||onDevice) to "VOICE_CAPABILITY system=$system onDevice=$onDevice microphonePreviouslyGranted=$granted; no capture or permission request performed\n"
        }catch(e:Throwable){false to "Voice capability check failed: ${e.javaClass.simpleName}\n"}
    }
}
