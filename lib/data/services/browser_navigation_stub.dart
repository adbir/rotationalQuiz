import 'browser_navigation.dart';

BrowserNavigation createPlatformNavigation() => const _NoBrowser();

/// Non-web builds have no page to redirect.
class _NoBrowser implements BrowserNavigation {
  const _NoBrowser();

  @override
  Uri get current => Uri.base;

  @override
  void goTo(Uri url) {}

  @override
  void replaceUrl(Uri url) {}
}
