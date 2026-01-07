part of 'modules.dart';

mixin _ModuleContainerRoutes on _ModuleContainerBase {
  MPageRouteGenerator<dynamic> _defaultPageRouteGenerator =
      (RouteSettings settings, Widget content) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => content,
    );
  };

  ///  设置默认的路由生成器
  @override
  set pageRouteGenerator(MPageRouteGenerator generator) {
    _defaultPageRouteGenerator = generator;
  }

  /// 当无法使用[generateRouteFactory]时使用，将会无法自定义路由和路由解析拦截   模块页面生成器
  @override
  Map<String, WidgetBuilder> get generateRouters {
    _initialize();
    final Map<String, WidgetBuilder> routes = {};
    for (final module in _allModulePages.entries) {
      routes[module.key] = (_) => Builder(
          builder: (context) =>
              module.value(ModalRoute.of(context)?.settings.arguments));
    }
    return routes;
  }

  /// 模块路由生成器
  /// 使用这个时无需使用 [generateRouters] 内部已经包含
  @override
  RouteFactory get generateRouteFactory {
    _initialize();
    return (RouteSettings settings) {
      RouteSettings? config;
      if (_allModuleRouteParsers.isNotEmpty) {
        final context = _initializeModulesKey.currentContext!;

        RouteSettings? parsing(RouteSettings settings) {
          RouteSettings? result;
          for (var parser in _allModuleRouteParsers) {
            result = parser(context, settings);
            if (result != null &&
                (result.name != settings.name ||
                    result.arguments != settings.arguments ||
                    result.runtimeType != settings.runtimeType)) {
              return result;
            }
          }
          return null;
        }

        /// 如果出现了 路由转换 则需要重新执行所有的解析器
        RouteSettings? tmp = settings;
        while (tmp != null) {
          config = tmp;
          tmp = parsing(tmp);
        }
      }
      config ??= settings;

      // /// 不知道context 应该从哪里取
      // if (config is Page) {
      //   return config.createRoute(context);
      // }

      final String? name = config.name;
      if (name == null) return null;
      final arguments = config.arguments;
      final MPageRouteBuilder? builder = _allModuleRoutes[name];
      if (builder != null) {
        Widget content = const SizedBox.shrink();
        if (_allModulePages.containsKey(name)) {
          content = _allModulePages[name]!(arguments);
        }
        final route = builder(arguments, content);
        assert(route.settings.name == name);
        return route;
      } else if (_allModulePages.containsKey(name)) {
        Widget content = _allModulePages[name]!(arguments);
        return _defaultPageRouteGenerator(config, content);
      }
      return null;
    };
  }
}
