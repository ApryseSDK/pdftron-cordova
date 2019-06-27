package com.pdftron.cordova;

import android.app.Activity;
import android.net.Uri;
import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.v4.app.FragmentActivity;
import android.util.Log;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.WebView;

import com.pdftron.common.PDFNetException;
import com.pdftron.pdf.config.ToolManagerBuilder;
import com.pdftron.pdf.config.ViewerConfig;
import com.pdftron.pdf.controls.DocumentActivity;
import com.pdftron.pdf.controls.PdfViewCtrlTabFragment;
import com.pdftron.pdf.tools.ToolManager;
import com.pdftron.pdf.utils.Utils;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaInterface;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.CordovaWebView;
import org.apache.cordova.LOG;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.util.ArrayList;

/**
 * This class echoes a string called from JavaScript.
 */
public class PDFTron extends CordovaPlugin {

    private static final String TAG = "PDFTron";

    // options
    public static final String Key_initialDoc = "initialDoc";
    public static final String Key_password = "password";
    public static final String Key_boundingRect = "boundingRect";
    public static final String Key_disabledElements = "disabledElements";
    public static final String Key_showNavIcon = "showTopLeftButton";
    public static final String Key_navIconTitle = "topLeftButtonTitle";

    // methods
    public static final String Key_showDocumentViewer = "showDocumentViewer";
    public static final String Key_disableElements = "disableElements";
    public static final String Key_enableTools = "enableTools";
    public static final String Key_disableTools = "disableTools";
    public static final String Key_setToolMode = "setToolMode";
    public static final String Key_loadDocument = "loadDocument";
    public static final String Key_NativeViewer = "NativeViewer";

    // nav
    public static final String Key_close = "close";
    public static final String Key_menu = "menu";
    public static final String Key_back = "back";

    private DocumentView mDocumentView;
    private ViewerConfig.Builder mBuilder;
    private ToolManagerBuilder mToolManagerBuilder;

    // events
    private final Object messageChannelLock = new Object();
    private CallbackContext messageChannel;

    @Override
    public void initialize(CordovaInterface cordova, CordovaWebView webView) {
        super.initialize(cordova, webView);

        mBuilder = new ViewerConfig.Builder()
                .useSupportActionBar(false)
                .fullscreenModeEnabled(false)
                .multiTabEnabled(false)
                .saveCopyExportPath(cordova.getContext().getCacheDir().getAbsolutePath())
                .openUrlCachePath(cordova.getContext().getCacheDir().getAbsolutePath());
        mToolManagerBuilder = ToolManagerBuilder.from();
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        Log.d("cordova", "execute: " + action + " | " + args.toString());
        if (Key_NativeViewer.equals(action)) {
            String options = args.getString(0);
            String viewerElement = null;
            if (args.length() > 1) {
                viewerElement = args.getString(1);
            }
            addDocumentViewer(options, viewerElement, callbackContext);
            return true;
        } else if (Key_showDocumentViewer.equals(action)) {
            showDocumentViewer(callbackContext);
            return true;
        } else if (Key_disableElements.equals(action)) {
            disableElements(args, callbackContext);
            return true;
        } else if (Key_enableTools.equals(action)) {
            enableTools(args, callbackContext);
            return true;
        } else if (Key_disableTools.equals(action)) {
            disableTools(args, callbackContext);
            return true;
        } else if (Key_setToolMode.equals(action)) {
            setToolMode(args.getString(0), callbackContext);
            return true;
        } else if (Key_loadDocument.equals(action)) {
            loadDocument(args.getString(0), callbackContext);
            return true;
        } else if (action.equals("messageChannel")) {
            synchronized (messageChannelLock) {
                messageChannel = callbackContext;
            }
            return true;
        }
        return false;
    }

    public void hideView() {
        if (mDocumentView == null) {
            return;
        }
        mDocumentView.setVisibility(View.GONE);
    }

    public void fireJavascriptEvent(String action) {
        sendEventMessage(action);
    }

    private void sendEventMessage(String action) {
        JSONObject obj = new JSONObject();
        try {
            obj.put("action", action);
        } catch (JSONException e) {
            LOG.e(TAG, "Failed to create event message", e);
        }
        PluginResult result = new PluginResult(PluginResult.Status.OK, obj);

        if (messageChannel != null) {
            sendEventMessage(result);
        }
    }

    private void sendEventMessage(PluginResult payload) {
        payload.setKeepCallback(true);
        if (messageChannel != null) {
            messageChannel.sendPluginResult(payload);
        }
    }

    private void addDocumentViewer(String options, String viewerElement, CallbackContext callbackContext) {
        try {
            final JSONObject jsonObject = new JSONObject(options);
            cordova.getActivity().runOnUiThread(() -> createDocumentViewerImpl(jsonObject, viewerElement, callbackContext));
        } catch (Exception e) {
            e.printStackTrace();
            callbackContext.error(e.getMessage());
        }
    }

    private void createDocumentViewerImpl(@NonNull JSONObject options, @Nullable String viewerElement, CallbackContext callbackContext) {
        try {
            Activity currentActivity = cordova.getActivity();
            if (currentActivity instanceof FragmentActivity) {
                FragmentActivity fragmentActivity = (FragmentActivity) cordova.getActivity();

                mDocumentView = new DocumentView(cordova.getContext());
                mDocumentView.setSupportFragmentManager(fragmentActivity.getSupportFragmentManager());
                mDocumentView.setPlugin(this);

                // parse options
                if (options.has(Key_initialDoc)) {
                    String initialDoc = options.getString(Key_initialDoc);
                    mDocumentView.setDocumentUri(Uri.parse(initialDoc));
                }

                if (options.has(Key_password)) {
                    String password = options.getString(Key_password);
                    mDocumentView.setPassword(password);
                }

                if (options.has(Key_boundingRect)) {
                    String rect = options.getString(Key_boundingRect);
                    Log.d("cordova", "boundingRect: " + rect);
                    JSONObject rectObject = new JSONObject(rect);
                    int left = (int) Float.parseFloat(rectObject.getString("left"));
                    int top = (int) Float.parseFloat(rectObject.getString("top"));
                    int width = (int) Float.parseFloat(rectObject.getString("width"));
                    int height = (int) Float.parseFloat(rectObject.getString("height"));
                    mDocumentView.setRect((int) Utils.convDp2Pix(cordova.getContext(), left),
                            (int) Utils.convDp2Pix(cordova.getContext(), top),
                            (int) Utils.convDp2Pix(cordova.getContext(), width),
                            (int) Utils.convDp2Pix(cordova.getContext(), height));
                }

                if (options.has(Key_disabledElements)) {
                    disableElements(options.getJSONArray(Key_disabledElements));
                }

                String navIcon = "ic_menu_white_24dp";
                if (options.has(Key_navIconTitle)) {
                    String title = options.getString(Key_navIconTitle);
                    if (Key_menu.equalsIgnoreCase(title)) {
                        navIcon = "ic_menu_white_24dp";
                    } else if (Key_back.equalsIgnoreCase(title)) {
                        navIcon = "ic_arrow_back_white_24dp";
                    } else if (Key_close.equalsIgnoreCase(title)) {
                        navIcon = "ic_close_white_24dp";
                    }
                }
                mDocumentView.setNavIconResName(navIcon);
                boolean showNav = true;
                if (options.has(Key_showNavIcon)) {
                    showNav = options.getBoolean(Key_showNavIcon);
                }
                mDocumentView.setShowNavIcon(showNav);

                if (!Utils.isNullOrEmpty(viewerElement)) {
                    attachDocumentViewerImpl();
                }
                callbackContext.success();
            } else {
                callbackContext.error("Current activity is not instanceof FragmentActivity");
            }
        } catch (Exception e) {
            e.printStackTrace();
            callbackContext.error(e.getMessage());
        }
    }

    private void attachDocumentViewerImpl() throws PDFNetException {
        if (mDocumentView == null) {
            return;
        }
        if (mDocumentView.isUseCustomRect()) {
            mDocumentView.setVisibility(View.VISIBLE);
            if (mDocumentView.getParent() != null) {
                return;
            }
            mDocumentView.setViewerConfig(getConfig());
            if (webView.getView() instanceof WebView) {
                WebView wv = (WebView) webView.getView();
                if (wv.getParent() != null && wv.getParent() instanceof ViewGroup) {
                    ((ViewGroup) wv.getParent()).addView(mDocumentView);
                } else {
                    wv.addView(mDocumentView);
                }
            } else {
                throw new PDFNetException("CordovaWebView is not instanceof WebView", -1, "PDFTron.java", "attachDocumentViewerImpl", "Unable to add viewer.");
            }
        } else {
            // simply launch the activity
            DocumentActivity.openDocument(cordova.getActivity(), mDocumentView.mDocumentUri, mDocumentView.mPassword, getConfig());
        }
    }

    private void disableElements(JSONArray args, CallbackContext callbackContext) {
        try {
            disableElements(args);
            callbackContext.success();
        } catch (Exception ex) {
            callbackContext.error(ex.getMessage());
        }
    }

    private void disableElements(JSONArray args) throws JSONException {
        for (int i = 0; i < args.length(); i++) {
            String item = args.getString(i);
            if ("toolsButton".equals(item)) {
                mBuilder = mBuilder.showAnnotationToolbarOption(false);
            } else if ("searchButton".equals(item)) {
                mBuilder = mBuilder.showSearchView(false);
            } else if ("shareButton".equals(item)) {
                mBuilder = mBuilder.showShareOption(false);
            } else if ("viewControlsButton".equals(item)) {
                mBuilder = mBuilder.showDocumentSettingsOption(false);
            } else if ("thumbnailsButton".equals(item)) {
                mBuilder = mBuilder.showThumbnailView(false);
            } else if ("listsButton".equals(item)) {
                mBuilder = mBuilder
                        .showAnnotationsList(false)
                        .showOutlineList(false)
                        .showUserBookmarksList(false);
            } else if ("thumbnailSlider".equals(item)) {
                mBuilder = mBuilder.showBottomNavBar(false);
            }
        }
        disableTools(args);
    }

    private ToolManager.ToolMode convStringToToolMode(String item) {
        ToolManager.ToolMode mode = null;
        if ("freeHandToolButton".equals(item) || "AnnotationCreateFreeHand".equals(item)) {
            mode = ToolManager.ToolMode.INK_CREATE;
        } else if ("highlightToolButton".equals(item) || "AnnotationCreateTextHighlight".equals(item)) {
            mode = ToolManager.ToolMode.TEXT_HIGHLIGHT;
        } else if ("underlineToolButton".equals(item) || "AnnotationCreateTextUnderline".equals(item)) {
            mode = ToolManager.ToolMode.TEXT_UNDERLINE;
        } else if ("squigglyToolButton".equals(item) || "AnnotationCreateTextSquiggly".equals(item)) {
            mode = ToolManager.ToolMode.TEXT_SQUIGGLY;
        } else if ("strikeoutToolButton".equals(item) || "AnnotationCreateTextStrikeout".equals(item)) {
            mode = ToolManager.ToolMode.TEXT_STRIKEOUT;
        } else if ("rectangleToolButton".equals(item) || "AnnotationCreateRectangle".equals(item)) {
            mode = ToolManager.ToolMode.RECT_CREATE;
        } else if ("ellipseToolButton".equals(item) || "AnnotationCreateEllipse".equals(item)) {
            mode = ToolManager.ToolMode.OVAL_CREATE;
        } else if ("lineToolButton".equals(item) || "AnnotationCreateLine".equals(item)) {
            mode = ToolManager.ToolMode.LINE_CREATE;
        } else if ("arrowToolButton".equals(item) || "AnnotationCreateArrow".equals(item)) {
            mode = ToolManager.ToolMode.ARROW_CREATE;
        } else if ("polylineToolButton".equals(item) || "AnnotationCreatePolyline".equals(item)) {
            mode = ToolManager.ToolMode.POLYLINE_CREATE;
        } else if ("polygonToolButton".equals(item) || "AnnotationCreatePolygon".equals(item)) {
            mode = ToolManager.ToolMode.POLYGON_CREATE;
        } else if ("cloudToolButton".equals(item) || "AnnotationCreatePolygonCloud".equals(item)) {
            mode = ToolManager.ToolMode.CLOUD_CREATE;
        } else if ("signatureToolButton".equals(item) || "AnnotationCreateSignature".equals(item)) {
            mode = ToolManager.ToolMode.SIGNATURE;
        } else if ("freeTextToolButton".equals(item) || "AnnotationCreateFreeText".equals(item)) {
            mode = ToolManager.ToolMode.TEXT_CREATE;
        } else if ("stickyToolButton".equals(item) || "AnnotationCreateSticky".equals(item)) {
            mode = ToolManager.ToolMode.TEXT_ANNOT_CREATE;
        } else if ("calloutToolButton".equals(item) || "AnnotationCreateCallout".equals(item)) {
            mode = ToolManager.ToolMode.CALLOUT_CREATE;
        } else if ("stampToolButton".equals(item) || "AnnotationCreateStamp".equals(item)) {
            mode = ToolManager.ToolMode.STAMPER;
        } else if ("AnnotationCreateDistanceMeasurement".equals(item)) {
            mode = ToolManager.ToolMode.RULER_CREATE;
        } else if ("AnnotationCreatePerimeterMeasurement".equals(item)) {
            mode = ToolManager.ToolMode.PERIMETER_MEASURE_CREATE;
        } else if ("AnnotationCreateAreaMeasurement".equals(item)) {
            mode = ToolManager.ToolMode.AREA_MEASURE_CREATE;
        } else if ("TextSelect".equals(item)) {
            mode = ToolManager.ToolMode.TEXT_SELECT;
        } else if ("AnnotationEdit".equals(item)) {
            mode = ToolManager.ToolMode.ANNOT_EDIT_RECT_GROUP;
        }
        return mode;
    }

    private void enableTools(JSONArray args, CallbackContext callbackContext) {
        try {
            enableTools(args);
            callbackContext.success();
        } catch (Exception ex) {
            callbackContext.error(ex.getMessage());
        }
    }

    private void enableTools(JSONArray args) throws JSONException, PDFNetException {
        ArrayList<ToolManager.ToolMode> modesArr = new ArrayList<>();
        for (int i = 0; i < args.length(); i++) {
            String item = args.getString(i);
            ToolManager.ToolMode mode = convStringToToolMode(item);
            if (mode != null) {
                modesArr.add(mode);
            }
        }
        ToolManager.ToolMode[] modes = modesArr.toArray(new ToolManager.ToolMode[modesArr.size()]);
        if (mDocumentView.mPdfViewCtrlTabHostFragment != null && mDocumentView.mPdfViewCtrlTabHostFragment.getCurrentPdfViewCtrlFragment() != null) {
            ToolManager toolManager = mDocumentView.mPdfViewCtrlTabHostFragment.getCurrentPdfViewCtrlFragment().getToolManager();
            if (toolManager != null) {
                toolManager.enableToolMode(modes);
            }
        } else {
            throw new PDFNetException("Calling enableTools when viewer is not ready", -1, "PDFTron.java", "enableTools", "Viewer is not ready yet. All tools are enabled by default.");
        }
    }

    private void disableTools(JSONArray args, CallbackContext callbackContext) {
        try {
            disableTools(args);
            callbackContext.success();
        } catch (Exception ex) {
            callbackContext.error(ex.getMessage());
        }
    }

    private void disableTools(JSONArray args) throws JSONException {
        ArrayList<ToolManager.ToolMode> modesArr = new ArrayList<>();
        for (int i = 0; i < args.length(); i++) {
            String item = args.getString(i);
            ToolManager.ToolMode mode = convStringToToolMode(item);
            if (mode != null) {
                modesArr.add(mode);
            }
        }
        ToolManager.ToolMode[] modes = modesArr.toArray(new ToolManager.ToolMode[modesArr.size()]);
        if (mDocumentView.mPdfViewCtrlTabHostFragment != null && mDocumentView.mPdfViewCtrlTabHostFragment.getCurrentPdfViewCtrlFragment() != null) {
            ToolManager toolManager = mDocumentView.mPdfViewCtrlTabHostFragment.getCurrentPdfViewCtrlFragment().getToolManager();
            if (toolManager != null) {
                toolManager.disableToolMode(modes);
            }
        } else {
            mToolManagerBuilder = mToolManagerBuilder.disableToolModes(modes);
        }
    }

    private void setToolMode(String toolMode, CallbackContext callbackContext) {
        if (mDocumentView.mPdfViewCtrlTabHostFragment != null && mDocumentView.mPdfViewCtrlTabHostFragment.getCurrentPdfViewCtrlFragment() != null) {
            boolean success = false;
            ToolManager toolManager = mDocumentView.mPdfViewCtrlTabHostFragment.getCurrentPdfViewCtrlFragment().getToolManager();
            if (toolManager != null) {
                ToolManager.ToolMode mode = convStringToToolMode(toolMode);
                if (mode != null) {
                    toolManager.setTool(toolManager.createTool(mode, toolManager.getTool()));
                    success = true;
                }
            }
            if (!success) {
                callbackContext.error("setToolMode to " + toolMode + " failed.");
            }
        } else {
            callbackContext.error("Viewer is not ready yet.");
        }
    }

    private void loadDocument(String document, CallbackContext callbackContext) {
        if (mDocumentView.mPdfViewCtrlTabHostFragment != null && mDocumentView.mPdfViewCtrlTabHostFragment.getCurrentPdfViewCtrlFragment() != null) {
            // fragment already inflated
            cordova.getActivity().runOnUiThread(() -> {
                Bundle args = PdfViewCtrlTabFragment.createBasicPdfViewCtrlTabBundle(cordova.getActivity(), Uri.parse(document), "", getConfig());
                mDocumentView.mPdfViewCtrlTabHostFragment.onOpenAddNewTab(args);
                callbackContext.success();
            });
        } else {
            callbackContext.error("Viewer is not ready yet, use 'initialDoc' option instead.");
        }
    }

    private void showDocumentViewer(CallbackContext callbackContext) {
        cordova.getActivity().runOnUiThread(() -> {
            if (mDocumentView != null) {
                try {
                    attachDocumentViewerImpl();
                    callbackContext.success();
                } catch (Exception ex) {
                    callbackContext.error(ex.getMessage());
                }
            }
        });
    }

    private ViewerConfig getConfig() {
        return mBuilder
                .toolManagerBuilder(mToolManagerBuilder)
                .build();
    }
}
