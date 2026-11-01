import 'browser_navigation_stub.dart'
    if (dart.library.js_interop) 'browser_navigation_web.dart';

/// The bits of the browser that sign-in needs, so tests can fake them.
abstract interface class BrowserNavigation {
  /// The page's own location, including any `?code=` return.
  Uri get current;

  /// Leaves the app for [url] (the Warcraft Logs authorize page).
  void goTo(Uri url);

  /// Rewrites the address bar without reloading.
  void replaceUrl(Uri url);
}

/// The real browser on the web; a no-op elsewhere.
BrowserNavigation platformNavigation() => createPlatformNavigation();
