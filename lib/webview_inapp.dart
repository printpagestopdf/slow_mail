import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:slow_mail/utils/utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:easy_localization/easy_localization.dart';
import 'generated/locale_keys.g.dart';

enum WebViewFeature { blockExternal, hasFullscreen, originIncluded }

class WebViewInAppCallback {
  bool isExternalBlocked = true;
  bool isFullScreen = false;
  bool isOriginIncluded = true;
}

class WebViewInApp extends StatefulWidget {
  final String initialContent;
  final bool isHtml;
  final bool isExternalBlocked;
  final void Function(WebViewInAppCallback)? callback;
  final List<WebViewFeature>? supports;

  const WebViewInApp({
    required this.initialContent,
    this.isHtml = true,
    this.isExternalBlocked = true,
    this.supports,
    this.callback,
    super.key,
  });

  @override
  State<WebViewInApp> createState() => WebViewInAppState();
}

class WebViewInAppState extends State<WebViewInApp> {
  final _toolbarExpandController = ExpansibleController();
  InAppWebViewController? _controller;
  bool _loading = true;
  final WebViewInAppCallback _uiFeatureStatus = WebViewInAppCallback();

  @override
  void dispose() {
    if (_controller != null) _controller!.dispose();

    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _uiFeatureStatus.isExternalBlocked = widget.isExternalBlocked;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: Stack(
          children: [
            Column(children: [
              _extContentSwitch(),
              Expanded(
                child: _webView(),
              ),
            ]),
            if (_loading)
              const Positioned.fill(
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ));
  }

  Widget _extContentSwitch() {
    if (widget.supports == null) return Container();
    return Expansible(
      controller: _toolbarExpandController,
      headerBuilder: (context, animation) => InkWell(
        onTap: () => _toolbarExpandController.isExpanded
            ? _toolbarExpandController.collapse()
            : _toolbarExpandController.expand(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            _toolbarExpandController.isExpanded ? Icon(Icons.compress) : Icon(Icons.expand),
            Expanded(
              child: Divider(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                thickness: 1,
                indent: 5,
                endIndent: 5,
              ),
            ),
            _toolbarExpandController.isExpanded ? Icon(Icons.compress) : Icon(Icons.expand),
          ],
        ),
      ),
      expansibleBuilder: (context, header, body, animation) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [header, body],
      ),
      bodyBuilder: (context, animation) => Padding(
        padding: EdgeInsets.symmetric(vertical: 0, horizontal: 10),
        child: Card(
            child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            if (widget.supports!.contains(WebViewFeature.blockExternal))
              Row(
                children: [
                  Checkbox(
                    tristate: false,
                    value: _uiFeatureStatus.isExternalBlocked,
                    onChanged: (value) async {
                      setState(() {
                        _loading = true;
                      });
                      await InAppWebViewController.clearAllCache();

                      InAppWebViewSettings? settings = await _controller!.getSettings();
                      settings!.blockNetworkLoads = value;
                      await _controller!.setSettings(settings: settings);

                      await _controller!.reload();
                      // await _controller!.loadData(data: widget.initialContent);
                      setState(() {
                        _uiFeatureStatus.isExternalBlocked = value!;
                      });
                      if (widget.callback != null) widget.callback!(_uiFeatureStatus);
                    },
                  ),
                  _uiFeatureStatus.isExternalBlocked
                      ? Text(LocaleKeys.external_content_is_blocked.tr())
                      : Text(LocaleKeys.external_content_is_allowed.tr()),
                ],
              ),
            Spacer(),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.supports!.contains(WebViewFeature.originIncluded))
                  IconButton(
                    onPressed: () {
                      _uiFeatureStatus.isOriginIncluded = false;
                      if (widget.callback != null) {
                        widget.callback!(_uiFeatureStatus);
                      }
                    },
                    icon: Icon(Icons.delete_outline),
                    tooltip: LocaleKeys.tt_remove_origin.tr(),
                  ),
                if (widget.supports!.contains(WebViewFeature.hasFullscreen))
                  IconButton(
                    onPressed: () {
                      _uiFeatureStatus.isFullScreen = !_uiFeatureStatus.isFullScreen;
                      if (widget.callback != null) {
                        widget.callback!(_uiFeatureStatus);
                      }
                    },
                    icon: Icon(_uiFeatureStatus.isFullScreen ? Icons.close_fullscreen : Icons.open_in_full),
                    tooltip: LocaleKeys.tt_fullscreen.tr(),
                  ),
                IconButton(
                  onPressed: () => _controller!.zoomOut(),
                  icon: Icon(Icons.zoom_out),
                  tooltip: LocaleKeys.tt_zoom_in.tr(),
                ),
                IconButton(
                  onPressed: () => _controller!.zoomIn(),
                  icon: Icon(Icons.zoom_in),
                  tooltip: LocaleKeys.tt_zoom_out.tr(),
                ),
              ],
            ),
          ],
        )),
      ),
    );
  }

  InAppWebView _webView() {
    return InAppWebView(
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        try {
          await launchUrl(navigationAction.request.url!);
        } catch (_) {}

        return NavigationActionPolicy.CANCEL;
      },
      initialData: widget.isHtml ? InAppWebViewInitialData(data: widget.initialContent) : null,
      initialUrlRequest: widget.isHtml ? null : URLRequest(url: WebUri(widget.initialContent)),
      initialSettings: InAppWebViewSettings(
        useWideViewPort: false,
        ignoresViewportScaleLimits: true,
        useShouldOverrideUrlLoading: true,
        useHybridComposition: true,
        // blockNetworkImage: _isExternalBlocked,
        //loadsImagesAutomatically: false,
        blockNetworkLoads: _uiFeatureStatus.isExternalBlocked,
        safeBrowsingEnabled: true,
        saveFormData: false,
        thirdPartyCookiesEnabled: false,
        cacheEnabled: false,
        databaseEnabled: false,
        domStorageEnabled: false,
        geolocationEnabled: false,
        isElementFullscreenEnabled: false,
        isFindInteractionEnabled: false,
        incognito: true,
        javaScriptCanOpenWindowsAutomatically: false,
        javaScriptEnabled: false,
        transparentBackground: context.isDarkMode ? false : true,
        supportZoom: true,
        verticalScrollBarEnabled: true,
        horizontalScrollBarEnabled: true,
      ),
      onWebViewCreated: (controller) {
        _controller = controller;
      },
      onLoadStop: (controller, url) {
        setState(() {
          _loading = false;
        });
      },
    );
  }
}
