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
    private String requested;
    private boolean failed;
    @Override public void onCreate(Bundle arguments) { requested=arguments==null ? null : arguments.getString("fixtureAction"); super.onCreate(arguments); start(); }
    private AccessibilityNodeInfo find(AccessibilityNodeInfo node,String id,String text) {
        if(node==null) return null;
        Rect b=new Rect();node.getBoundsInScreen(b);
        if(!b.isEmpty() && node.isVisibleToUser() && (id==null || id.equals(node.getViewIdResourceName())) &&
            (text==null || String.valueOf(node.getText()).contains(text))) return node;
        for(int i=0;i<node.getChildCount();i++) { AccessibilityNodeInfo found=find(node.getChild(i),id,text);if(found!=null)return found; }
        return null;
    }
    private void fixtureAction() {
        if("overlaySnooze5".equals(requested)) {
            for(android.view.accessibility.AccessibilityWindowInfo window:getUiAutomation().getWindows()) {
                AccessibilityNodeInfo panel=window.getRoot();
                if(panel!=null && "com.ilmmizan.bilga".contentEquals(String.valueOf(panel.getPackageName())) && find(panel,null,"Bilga Recovery 20261016")!=null) {
                    AccessibilityNodeInfo choice=find(panel,null,"5 daq");
                    if(choice==null || !choice.performAction(AccessibilityNodeInfo.ACTION_CLICK)) throw new IllegalStateException("Overlay preset unavailable");
                    output.append("Synthetic overlay snooze delivered\n");return;
                }
            }
            throw new IllegalStateException("Visible synthetic overlay required");
        }
        if(!"snooze5".equals(requested) && !"done".equals(requested)) throw new IllegalArgumentException("Unsupported fixture action");
        AccessibilityNodeInfo root=getUiAutomation().getRootInActiveWindow();
        AccessibilityNodeInfo title=find(root,"com.ilmmizan.bilga:id/todo_widget_row_title","Bilga Recovery 20261016");
        if(title==null) throw new IllegalStateException("Visible synthetic fixture required");
        AccessibilityNodeInfo row=title.getParent().getParent();
        AccessibilityNodeInfo button=find(row,"com.ilmmizan.bilga:id/todo_widget_row_"+("done".equals(requested) ? "done" : "snooze"),null);
        if(button==null || !button.performAction(AccessibilityNodeInfo.ACTION_CLICK)) throw new IllegalStateException("Fixture button unavailable");
        if("snooze5".equals(requested)) {
            AccessibilityNodeInfo choice=null;
            for(int i=0;i<20 && choice==null;i++) { android.os.SystemClock.sleep(100);choice=find(getUiAutomation().getRootInActiveWindow(),"com.ilmmizan.bilga:id/todo_snooze5",null); }
            if(choice==null || !choice.performAction(AccessibilityNodeInfo.ACTION_CLICK)) throw new IllegalStateException("Inline preset unavailable");
        }
        android.os.SystemClock.sleep(1500);
        output.append("Synthetic widget action delivered: ").append(requested).append('\n');
    }
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
        info.flags |= AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS | AccessibilityServiceInfo.FLAG_RETRIEVE_INTERACTIVE_WINDOWS;
        getUiAutomation().setServiceInfo(info);
        android.os.SystemClock.sleep(100); // Service-info updates invalidate the initial root cache.
        AccessibilityNodeInfo root=getUiAutomation().getRootInActiveWindow();
        for(int attempt=0;attempt<20;attempt++) {
            output.setLength(0);
            if(root!=null) walk(root);
            if(output.length()>0) break;
            android.os.SystemClock.sleep(100); root=getUiAutomation().getRootInActiveWindow();
        }
        for(android.view.accessibility.AccessibilityWindowInfo window:getUiAutomation().getWindows()) {
            AccessibilityNodeInfo extra=window.getRoot();
            if(extra!=null && "com.ilmmizan.bilga".contentEquals(String.valueOf(extra.getPackageName())) && (root==null || !"com.ilmmizan.bilga".contentEquals(String.valueOf(root.getPackageName())))) {
                output.append("Bilga external window\n");walk(extra);
            }
        }
        // Inspect only a pixel inside the public/static Core widget background.
        // The screenshot stays in device memory; no screen image is saved/exported.
        if(root!=null && "com.blackview.launcher".contentEquals(String.valueOf(root.getPackageName()))) {
            AccessibilityNodeInfo core=find(root,"com.ilmmizan.bilga:id/agent_widget_root",null);
            if(core!=null) {
                Rect b=new Rect();core.getBoundsInScreen(b);
                android.graphics.Bitmap bitmap=getUiAutomation().takeScreenshot();
                if(bitmap!=null) {
                    int x=b.centerX(),y=b.top+32;
                    if(x>=0 && x<bitmap.getWidth() && y>=0 && y<bitmap.getHeight())
                        output.append("Public Core widget background ARGB: ").append(Integer.toHexString(bitmap.getPixel(x,y))).append('\n');
                    bitmap.recycle();
                }
            }
        }
        if(requested!=null) {
            try { fixtureAction(); }
            catch(Exception e) { failed=true;output.append("Fixture action FAILED: ").append(e.getClass().getSimpleName()).append(": ").append(e instanceof IllegalStateException ? e.getMessage() : "details withheld").append('\n'); }
        }
        if(output.length()==0) output.append("No matching active controls\n");
        Bundle result=new Bundle(); result.putString("stream",output.toString()); finish(root==null || failed ? Activity.RESULT_CANCELED : Activity.RESULT_OK,result);
    }
}
