package com.ilmmizan.bilga

import android.app.Instrumentation
import android.app.Activity
import android.graphics.Rect
import android.os.Bundle
import android.view.accessibility.AccessibilityNodeInfo

/** No idle wait: RemoteViews Chronometer updates every second. Self-targeted,
 * so app lifecycle, SQLCipher and scheduled alarms are never touched. Only
 * known static/synthetic labels and control geometry leave the device. */
class WidgetUiProbe:Instrumentation() {
 override fun onCreate(arguments:Bundle?) { super.onCreate(arguments);start() }
 override fun onStart() {
  val allowed=listOf("Bilga Recovery 20261016","Bilga Notes Recovery 20261016","RecoveryTest",
   "Widget preview line one. Line two. Line three.","Vazifalar","Yozuvlar","Eslatmalar","Saqlash",
   "Vidjetda ko‘rsatishga ruxsat berish","Tasdiqlangan sarlavhalar","To-Do vidjeti","Notes vidjeti",
   "Davom etish","Kechiktirish","Bajarildi","Bajarilgan","Bugun","OK","Cancel",
   "5 daqiqa","10 daqiqa","30 daqiqa","1 soat","Ertaga","Hozircha bo‘sh",
   "Boshqa ilovalar ustida ko‘rsatish","Umumiy ma’lumot","Faqat sarlavhalar","Matn parchasi va teglar",
   "Profil","Rang mavzusi","Tashqi ko‘rinish","Och","To‘q","Tizim","Saqlashga ruxsat")
  val out=StringBuilder()
  fun walk(node:AccessibilityNodeInfo) {
   val text=node.text?.toString().orEmpty()+"\n"+node.contentDescription?.toString().orEmpty()
   val bounds=Rect();node.getBoundsInScreen(bounds)
   for(label in allowed) if(text.contains(label)) out.append(label).append(' ').append(bounds).append('\n')
   val id=node.viewIdResourceName.orEmpty()
   if(id.startsWith("com.ilmmizan.bilga:id/") || id.startsWith("com.blackview.launcher:id/"))
    out.append(id).append(' ').append(bounds).append('\n')
   if(node.isCheckable || node.className?.toString()=="android.widget.EditText")
    out.append(node.className).append(" checked=").append(node.isChecked).append(' ').append(bounds).append('\n')
   for(i in 0 until node.childCount) node.getChild(i)?.let { walk(it) }
  }
  val root=uiAutomation.rootInActiveWindow
  if(root!=null) walk(root) else out.append("No accessible active window\n")
  finish(Activity.RESULT_OK,Bundle().apply {putString("stream",out.toString())})
 }
}
