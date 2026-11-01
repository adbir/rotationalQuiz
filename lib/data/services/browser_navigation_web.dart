import 'dart:js_interop';

import 'browser_navigation.dart';

@JS('location.assign')
external void _assign(String url);

@JS('history.replaceState')
external void _replaceState(JSAny? state, String title, String url);

BrowserNavigation createPlatformNavigation() => const _WebBrowser();

class _WebBrowser implements BrowserNavigation {
  const _WebBrowser();

  @override
  Uri get current => Uri.base;

  @override
  void goTo(Uri url) => _assign(url.toString());

  @override
  void replaceUrl(Uri url) => _replaceState(null, '', url.toString());
}
