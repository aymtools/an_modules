import 'package:an_modules/an_modules.dart';

class AModule {
  /// 利用 plugin 自动化注册 模块内容
  static void registerWith([registrar]) {
    Module.registerModule(
      module: Module(
        name: 'lib_a',
      ),
    );
  }
}
