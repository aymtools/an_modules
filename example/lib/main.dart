import 'package:an_lifecycle_cancellable/an_lifecycle_cancellable.dart';
import 'package:an_modules/an_modules.dart';
import 'package:anlifecycle/anlifecycle.dart';
import 'package:common/common.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  /// 一般会在 [startApp] 注册 全局异常捕获等操作
  startApp();

  /// 由于使用了自动化注册 此处无须任何的手动注册
}

Future<void> startApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  ///初始化你的功能 例如初始化 sp
  final sp = await SharedPreferences.getInstance();

  /// 一般选择将sp 注入到全局的 LifecycleAppOwner 中 后续就无须进行异步获取
  launchWithAppOwner((owner) => owner.extData.putIfAbsent(ifAbsent: () => sp));

  /// 正常启动App
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 选择 Lifecycle 来协助管理 生命周期内容 非必须 但是推荐使用
    return LifecycleApp(
      child: MaterialApp(
        title: 'Modules Demo',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        navigatorObservers: [
          // Lifecycle 所需的 LifecycleNavigatorObserver 非必须 但是推荐使用
          LifecycleNavigatorObserver.hookMode(),
        ],
        initialRoute: '/',
        // 路由生成器交给 modules 管理
        onGenerateRoute: Module.app.generateRouteFactory,
        // modules的初始化处理
        builder: AppInitializer.builder(initializing: AppInitializing()),
      ),
    );
  }
}

/// 自定义初始化时 loading 页面 以便符合视觉规范 注意当前还未初始化 Navigator 请勿使用相关内容 例如 Overlay 和 route
class AppInitializing extends StatelessWidget {
  const AppInitializing({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('App Initializer'),
      ),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
