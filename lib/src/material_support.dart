// ignore: deprecated_member_use
import 'package:flutter/material.dart';

PageRoute<dynamic> defaultPageRouteGenerator(
    RouteSettings settings, Widget content) {
  return MaterialPageRoute(
    settings: settings,
    builder: (_) => content,
  );
}
