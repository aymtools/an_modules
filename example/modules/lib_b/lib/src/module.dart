import 'package:an_modules/an_modules.dart';
import 'package:flutter/cupertino.dart';
import 'package:lib_b/src/pages/counter.dart';

class BModule {
  /// 利用 plugin 自动化注册 模块内容
  static void registerWith() {
    Module.registerModule(
      module: Module(
        name: 'lib_b',
        pages: {'/b/counter': (_) => const CounterPage(title: 'libB Counter')},
        routeParser: (_, settings) {
          if (settings.name == '/') {
            return RouteSettings(
                name: '/b/counter', arguments: settings.arguments);
          }
          return null;
        },
      ),
    );
  }
}
