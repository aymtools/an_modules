import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'modules.dart';

class ModulePackage {
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
      for (var parser in _allModuleRouteParsers) {
        config = parser(settings);
        if (config != null) {
          break;
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

  final GlobalKey _initializeModulesKey = GlobalKey();
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

class ModulesInitializer extends StatelessWidget {
  final ModulePackage modulePackage;
  final Widget loading;
  final Widget child;

  ModulesInitializer(
      {GlobalKey? key,
      required this.modulePackage,
      required this.loading,
      required this.child})
      : super(key: key ?? modulePackage._initializeModulesKey);

  @override
  Widget build(BuildContext context) {
    final mci = List.unmodifiable(modulePackage._allModuleInitializers);
    var result = child;
    for (final wrapper in mci) {
      result = _ModuleInitializerWrapper(
          key: ValueKey(wrapper),
          wrapper: wrapper,
          loading: modulePackage._loadingWidget(loading),
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
