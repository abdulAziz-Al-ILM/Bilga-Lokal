package com.ilmmizan.bilga;

import android.app.Instrumentation;
import android.app.Activity;
import android.graphics.Rect;
import android.os.Bundle;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.view.accessibility.AccessibilityNodeInfo;

/** Self-targeted Java runner needs no classes from Bilga or Kotlin runtime.
 * No idle wait, no app restart; only static/synthetic labels and geometry leave
 * the device. User note/task text is never printed. */
public final class WidgetUiProbe extends Instrumentation {
    private static final String[] ALLOWED = {"Bilga Recovery 20261016","Bilga Notes Recovery 20261016","RecoveryTest",
   "Widget preview line one. Line two. Line three.","Vazifalar","Yozuvlar","Eslatmalar","Saqlash",
   "Vidjetda ko‘rsatishga ruxsat berish","Tasdiqlangan sarlavhalar","To-Do vidjeti","Notes vidjeti",
   "Davom etish","Kechiktirish","Bajarildi","Bajarilgan","Bugun","OK","Cancel",
   "5 daqiqa","10 daqiqa","30 daqiqa","1 soat","Ertaga","Hozircha bo‘sh",
   "Boshqa ilovalar ustida ko‘rsatish","Umumiy ma’lumot","Faqat sarlavhalar","Matn parchasi va teglar",
   "Maxfiy: matnsiz","Tasdiqlangan matn va teglar","5 daq","10 daq","30 daq","60 daq","Yorug‘","Qorong‘i","Telefon sozlamasi","Yopish",
   "Profil","Rang mavzusi","Tashqi ko‘rinish","Och","To‘q","Tizim","Saqlashga ruxsat"};
    private final StringBuilder output = new StringBuilder();
    @Override public void onCreate(Bundle arguments) { super.onCreate(arguments); start(); }
    private void walk(AccessibilityNodeInfo node) {
        String text=String.valueOf(node.getText())+"\n"+String.valueOf(node.getContentDescription());
        Rect bounds=new Rect(); node.getBoundsInScreen(bounds);
        for(String label:ALLOWED) if(text.contains(label)) output.append(label).append(' ').append(bounds).append('\n');
        String id=node.getViewIdResourceName();
        if(id!=null && (id.startsWith("com.ilmmizan.bilga:id/") || id.startsWith("com.blackview.launcher:id/")))
            output.append(id).append(' ').append(bounds).append('\n');
        if(node.isCheckable() || "android.widget.EditText".contentEquals(String.valueOf(node.getClassName())))
            output.append(node.getClassName()).append(" checked=").append(node.isChecked()).append(' ').append(bounds).append('\n');
        for(int i=0;i<node.getChildCount();i++) { AccessibilityNodeInfo child=node.getChild(i); if(child!=null) walk(child); }
    }
    @Override public void onStart() {
        AccessibilityServiceInfo info=getUiAutomation().getServiceInfo();
        info.flags |= AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS;
        getUiAutomation().setServiceInfo(info);
        android.os.SystemClock.sleep(100); // Service-info updates invalidate the initial root cache.
        AccessibilityNodeInfo root=getUiAutomation().getRootInActiveWindow();
        for(int attempt=0;root==null && attempt<20;attempt++) {
            android.os.SystemClock.sleep(100); root=getUiAutomation().getRootInActiveWindow();
        }
        if(root!=null) walk(root); else output.append("No accessible active window\n");
        Bundle result=new Bundle(); result.putString("stream",output.toString()); finish(root==null ? Activity.RESULT_CANCELED : Activity.RESULT_OK,result);
    }
}
