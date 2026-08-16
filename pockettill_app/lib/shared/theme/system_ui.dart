import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Status bar style for the app's normal white-topped screens (everything
/// behind [pockettill_app_bar.CustomAppBar]) - dark icons on a white
/// background. Applied globally at startup in `main()`.
const SystemUiOverlayStyle lightScreenStatusBar = SystemUiOverlayStyle(
  statusBarColor: Colors.white,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
);

/// Status bar style for a screen with a dark/coloured background of its own
/// (currently just SplashScreen's blue) - light icons. Set and cleared
/// imperatively by that screen's own init/dispose rather than via
/// `AnnotatedRegion`: an `AnnotatedRegion` override here didn't reliably
/// revert to [lightScreenStatusBar] once the screen was replaced (not
/// popped), leaving every later screen with the wrong (light-icon) status
/// bar style.
const SystemUiOverlayStyle darkScreenStatusBar = SystemUiOverlayStyle(
  statusBarColor: Color(0xFF5170FF),
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);

/// Status bar style for a full-screen black view (the camera barcode
/// scanner) - light icons on black, set/cleared the same imperative way as
/// [darkScreenStatusBar].
const SystemUiOverlayStyle blackScreenStatusBar = SystemUiOverlayStyle(
  statusBarColor: Colors.black,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
);
