import 'package:flutter/material.dart';

extension NavigatorBuildContextExt on BuildContext {
  NavigatorState get navigator => Navigator.of(this);

  NavigatorState get navigatorRoot => Navigator.of(this, rootNavigator: true);
}
