package com.pdftron.cordova;

import android.content.Context;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.util.AttributeSet;
import android.view.ViewGroup;

public class DocumentView extends com.pdftron.pdf.controls.DocumentView {

    private int left;
    private int top;
    private int width;
    private int height;

    private boolean useCustomRect;
    private String resTitle;

    private PDFTron myPlugin;

    public DocumentView(@NonNull Context context) {
        super(context);
    }

    public DocumentView(@NonNull Context context, @Nullable AttributeSet attrs) {
        super(context, attrs);
    }

    public DocumentView(@NonNull Context context, @Nullable AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
    }

    @Override
    public void setNavIconResName(String resName) {
        resTitle = resName;
        super.setNavIconResName(resName);
    }

    public void setPlugin(PDFTron pdftron) {
        myPlugin = pdftron;
    }

    public void setRect(int l, int t, int w, int h) {
        useCustomRect = true;
        this.left = l;
        this.top = t;
        this.width = w;
        this.height = h;
    }

    @Override
    public void onNavButtonPressed() {
        boolean handled = false;
        if (resTitle != null && myPlugin != null) {
            if (resTitle.equals("ic_arrow_back_white_24dp") || resTitle.equals("ic_close_white_24dp")) {
                if (getParent() instanceof ViewGroup) {
                    myPlugin.hideView();
                    handled = true;
                }
            }
        }
        if (!handled) {
            sendJavascriptEvent("topLeftButtonPressed");
        }
    }

    @Override
    public void onTabDocumentLoaded(String tag) {
        sendJavascriptEvent("documentLoaded");
    }

    private void sendJavascriptEvent(String event) {
        if (myPlugin == null) {
            return;
        }
        myPlugin.fireJavascriptEvent(event);
    }

    @Override
    protected void onMeasure(int widthMeasureSpec, int heightMeasureSpec) {
        if (useCustomRect) {
            int nextWidthMeasureSpec = MeasureSpec.makeMeasureSpec(width, MeasureSpec.EXACTLY);
            int nextHeightMeasureSpec = MeasureSpec.makeMeasureSpec(height, MeasureSpec.EXACTLY);
            super.onMeasure(nextWidthMeasureSpec, nextHeightMeasureSpec);

            layout(left, top, left + width, top + height);

            if (getLayoutParams() != null && getLayoutParams() instanceof ViewGroup.MarginLayoutParams) {
                ViewGroup.MarginLayoutParams params = (ViewGroup.MarginLayoutParams) getLayoutParams();
                params.leftMargin = left;
                params.topMargin = top;
            }
        } else {
            super.onMeasure(widthMeasureSpec, heightMeasureSpec);
        }
    }
}