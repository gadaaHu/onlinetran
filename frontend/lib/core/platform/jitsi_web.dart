// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;
// ignore: avoid_web_libraries_in_flutter
import 'package:universal_html/html.dart' as html;

/// Registers a Jitsi Meet iframe as a Flutter platform view.
///
/// Call [registerJitsiView] once per unique [viewId], then embed it in Flutter
/// using:
///   HtmlElementView(viewType: viewId)
void registerJitsiView(String viewId, String roomName, String displayName) {
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
    // Build the Jitsi Meet URL with configuration params in the hash fragment.
    // The hash-based config avoids CORS issues with URL query params.
    final encoded = Uri.encodeComponent(displayName);
    final src = 'https://meet.jit.si/$roomName'
        '#config.startWithAudioMuted=false'
        '&config.startWithVideoMuted=false'
        '&config.prejoinPageEnabled=false'
        '&config.disableDeepLinking=true'
        '&userInfo.displayName=$encoded'
        '&interfaceConfig.SHOW_JITSI_WATERMARK=false'
        '&interfaceConfig.TOOLBAR_BUTTONS=["microphone","camera","closedcaptions","desktop","chat","raisehand","tileview","hangup"]';

    final iframe = html.IFrameElement()
      ..src = src
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'camera; microphone; display-capture; fullscreen; autoplay'
      ..setAttribute('allowfullscreen', 'true');

    return iframe;
  });
}
