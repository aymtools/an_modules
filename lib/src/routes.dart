part of 'modules.dart';

/// 所有的模块组成的一个包管理器
class ModulePackage {
  /// 简单快速初始化时 注册这里
  final List<MSInitializer> _allModuleSimpleInitializers = [];

  /// 当模块需要自定义全局初始化时注册这里
  final List<MInitializer> _allModuleInitializers = [];

  /// 所有的模块的路由解析器
  final List<MRouteParser> _allModuleRouteParsers = [];

  /// 所有的模块的路由页面生成器
  final Map<String, MPageBuilder> _allModulePages = {};

  /// 所有的模块的路由生成器
  final Map<String, MPageRouteBuilder> _allModuleRoutes = {};

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

// /// 一般使用这个  模块页面生成器
// Map<String, WidgetBuilder> get generateRouters {
//   final Map<String, WidgetBuilder> routes = {};
//   for (final module in _allModulePages.entries) {
//     routes[module.key] = (_) => Builder(builder: (context) => module.value(ModalRoute.of(context)?.settings.arguments));
//   }
//   return routes;
// }

  /// 模块路由生成器
  /// 使用这个时无需使用 [generateRouters] 内部已经包含
  RouteFactory get generateRouteFactory {
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

  /// 仅在debug下有意义
  final Map<String, Module> _allModules = {};

  /// 添加一个新的模块
  void registerModule(Module module) {
    assert(() {
      /// 一般用来组 package内部的 模块化
      if (module.name.isEmpty) {
        return true;
      }

      /// debug时严格限制 只能添加一次
      if (_allModules.containsKey(module.name)) {
        return false;
      }
      _allModules[module.name] = module;
      return true;
    }(), 'Module with name ${module.name} already exists.');
    module._initialize(this);
  }

  GlobalKey _initializeModulesKey = GlobalKey();
  final GlobalKey _initializeLoadingKey = GlobalKey();

  Widget? _moduleInitializerLoading;

  Widget _loadingWidget(Widget loading) {
    _moduleInitializerLoading ??=
        _ModuleInitializerLoading(modulePackage: this, child: loading);
    return _moduleInitializerLoading!;
  }
}

extension on Module {
  void _initialize(ModulePackage package) {
    if (simpleInitializer != null) {
      package._allModuleSimpleInitializers.add(simpleInitializer!);
    }
    if (initializer != null) {
      package._allModuleInitializers.add(initializer!);
    }

    if (routeParser != null) {
      package._allModuleRouteParsers.add(routeParser!);
    }

    package._allModuleRoutes.addAll(routes);

    final wrapper = pageWrapper;
    final modulePages = <String, Widget Function(Object? arguments)>{
      for (var page in pages.entries)
        page.key: (arg) {
          if (name.isEmpty) {
            /// 一般是指 module 内部页面
            var pageContent = page.value.call(arg);
            if (wrapper != null) {
              pageContent = wrapper(pageContent);
            }
            return pageContent;
          } else {
            return Builder(builder: (context) {
              var pageContent = page.value.call(arg);
              if (wrapper != null) {
                pageContent = wrapper(pageContent);
              }
              return DefaultAssetBundle(
                bundle:
                    _ExtModuleAssetBundle(DefaultAssetBundle.of(context), name),
                child: pageContent,
              );
            });
          }
        },
    };
    package._allModulePages.addAll(modulePages);
  }
}

class _ExtModuleAssetBundle extends CachingAssetBundle {
  final String _package;
  final AssetBundle _parent;

  _ExtModuleAssetBundle(this._parent, this._package);

  @override
  Future<ByteData> load(String key) {
    if (key.startsWith('asset')) {
      try {
        return _parent.load('packages/$_package/$key');
      } catch (_) {
        return _parent.load(key);
      }
    }
    return _parent.load(key);
  }
}

/// App的初始化管理器 用以自动化初始各个的模块配置信息 可能需要异步初始化
class AppInitializer extends ModulesInitializer {
  /// [loading] 执行异步初始化时 展示的UI信息
  AppInitializer({super.key, required super.loading, required super.child})
      : super(modulePackage: _app);

  /// 直接用在 AppBuilder的快速函数
  /// ignore: non_constant_identifier_names
  static Widget Function(BuildContext, Widget?) builder(
          {required Widget initializing, TransitionBuilder? builder}) =>
      (context, child) => AppInitializer(
            loading: initializing,
            child: builder == null
                ? child!
                : Builder(
                    builder: (context) => builder(context, child),
                  ),
          );
}

/// 模块集成包的初始化管理器
class ModulesInitializer extends StatefulWidget {
  final ModulePackage modulePackage;
  final Widget loading;
  final Widget child;

  /// [modulePackage] 指定模块配置信息
  /// [loading] 执行异步初始化时 展示的UI信息
  ModulesInitializer(
      {GlobalKey? key,
      required this.modulePackage,
      required this.loading,
      required this.child})
      : super(key: key ?? modulePackage._initializeModulesKey);

  @override
  State<ModulesInitializer> createState() => _ModulesInitializerState();

  /// 直接用在 builder的快速函数
  /// ignore: non_constant_identifier_names
  static Widget Function(BuildContext, Widget?) builder(
          {required ModulePackage modulePackage,
          required Widget initializing,
          TransitionBuilder? builder}) =>
      (context, child) => ModulesInitializer(
            modulePackage: modulePackage,
            loading: initializing,
            child: builder == null
                ? child!
                : Builder(
                    builder: (context) => builder(context, child),
                  ),
          );

  /// 直接用在 AppBuilder的快速函数
  /// ignore: non_constant_identifier_names
  static Widget Function(BuildContext, Widget?) builderApp(
          {required Widget initializing, TransitionBuilder? builder}) =>
      AppInitializer.builder(initializing: initializing, builder: builder);
}

class _ModulesInitializerState extends State<ModulesInitializer> {
  bool _isNotFirst = false;

  void _firstBuild(BuildContext context) {
    if (_isNotFirst) return;
    _isNotFirst = true;

    final msis =
        List.unmodifiable(widget.modulePackage._allModuleSimpleInitializers);
    for (final i in msis) {
      final Object? debugCheckForReturnedFuture = i.call(context) as dynamic;

      assert(() {
        if (debugCheckForReturnedFuture is Future) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary('${i.runtimeType} returned a Future.'),
            ErrorDescription(
                '${i.runtimeType} must be a void method without an `async` keyword.'),
          ]);
        }
        return true;
      }());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.key != widget.modulePackage._initializeModulesKey) {
      widget.modulePackage._initializeModulesKey = widget.key as GlobalKey;
    }
    _firstBuild(context);
    final mis = List.unmodifiable(widget.modulePackage._allModuleInitializers);
    var result = widget.child;
    for (final wrapper in mis) {
      result = _ModuleInitializerWrapper(
          key: ValueKey(wrapper),
          wrapper: wrapper,
          loading: widget.modulePackage._loadingWidget(widget.loading),
          child: result);
    }
    return result;
  }
}

class _ModuleInitializerWrapper extends StatelessWidget {
  final Widget child;
  final Widget loading;

  final Widget Function(Widget child, Widget loading) wrapper;

  const _ModuleInitializerWrapper(
      {super.key,
      required this.wrapper,
      required this.loading,
      required this.child});

  @override
  Widget build(BuildContext context) {
    return wrapper(loading, child);
  }
}

class _ModuleInitializerLoading extends StatelessWidget {
  final ModulePackage modulePackage;
  final Widget child;

  _ModuleInitializerLoading({required this.modulePackage, required this.child})
      : super(key: modulePackage._initializeLoadingKey);

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
