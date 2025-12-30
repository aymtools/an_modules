part of 'modules.dart';

class _ModuleContainerInner {
  final ModuleContainer container;

  _ModuleContainerInner({required this.container});

  MPageRouteGenerator<dynamic> _defaultPageRouteGenerator =
      (RouteSettings settings, Widget content) {
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => content,
    );
  };

  ///  设置默认的路由生成器
  set pageRouteGenerator(MPageRouteGenerator generator) {
    _defaultPageRouteGenerator = generator;
  }

  /// 简单快速初始化时 注册这里
  final List<MSInitializer> _allModuleSimpleInitializers = [];

  /// 单次初始化 注册这里
  final List<MSInitializer> _allModuleOnceInitializers = [];

  /// 当模块需要自定义全局初始化时注册这里
  final List<MInitializer> _allModuleInitializers = [];

  /// 所有的模块的路由解析器
  final List<MRouteParser> _allModuleRouteParsers = [];

  /// 所有的模块的路由页面生成器
  final Map<String, MPageBuilder> _allModulePages = {};

  /// 所有的模块的路由生成器
  final Map<String, MPageRouteBuilder> _allModuleRoutes = {};

  bool _isInitialized = false;

  void _initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    final modules = container._sortModules();
    for (final module in modules) {
      module._initialize(this);
    }
  }

  /// 当无法使用[generateRouteFactory]时使用，将会无法自定义路由和路由解析拦截   模块页面生成器
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

  GlobalKey _initializeModulesKey = GlobalKey();

  final GlobalKey _initializeLoadingKey = GlobalKey();

  Widget? _moduleInitializerLoading;

  Widget _loadingWidget(Widget loading) {
    _moduleInitializerLoading ??=
        _ModuleInitializerLoading(moduleContainer: container, child: loading);
    return _moduleInitializerLoading!;
  }

  bool _onceInitialized = false;

  void _callOnceInitializer(BuildContext context) {
    if (_onceInitialized) return;
    _onceInitialized = true;
    final mis = List.unmodifiable(_allModuleOnceInitializers);
    for (final i in mis) {
      i.call(context);
    }
  }
}

extension on Module {
  void _initialize(_ModuleContainerInner inner) {
    if (onceInitializer != null) {
      inner._allModuleOnceInitializers.add(onceInitializer!);
    }
    if (simpleInitializer != null) {
      inner._allModuleSimpleInitializers.add(simpleInitializer!);
    }
    if (initializer != null) {
      inner._allModuleInitializers.add(initializer!);
    }

    if (routeParser != null) {
      inner._allModuleRouteParsers.add(routeParser!);
    }

    inner._allModuleRoutes.addAll(routes);

    final wrapper = pageWrapper;
    final modulePages = <String, Widget Function(Object? arguments)>{
      for (var page in pages.entries)
        page.key: (arg) {
          /// 一般是指 module 内部页面
          Widget pageContent = page.value.call(arg);
          if (wrapper != null) {
            pageContent = wrapper(pageContent);
          }
          if (name.isNotEmpty) {
            pageContent = _ModuleAssetBundleManager(
              packageName: name,
              child: pageContent,
            );
          }
          return pageContent;
        },
    };
    inner._allModulePages.addAll(modulePages);
  }
}
