part of 'modules.dart';

mixin _ModuleContainerInitializers on _ModuleContainerBase {
  // /// 简单快速初始化时 注册这里
  // final List<MSInitializer> _allModuleSimpleInitializers = [];
  //
  // /// 单次初始化 注册这里
  // final List<MSInitializer> _allModuleOnceInitializers = [];

  /// 当模块需要自定义全局初始化时注册这里
  final List<MInitializer> _allModuleInitializers = [];

  @override
  bool _isInitialized = false;

  @override
  void _initialize() {
    super._initialize();
    if (_isInitialized) return;
    _isInitialized = true;

    final modules = sortModules();
    for (final module in modules) {
      module._initialize(this);
    }
    _onInitialized(modules);
  }


// bool _onceInitialized = false;
//
// void _callOnceInitializer(BuildContext context) {
//   if (_onceInitialized) return;
//   _onceInitialized = true;
//   final mis = List.unmodifiable(_allModuleOnceInitializers);
//   for (final i in mis) {
//     i.call(context);
//   }
// }
}

extension on Module {
  void _initialize(_ModuleContainerInitializers container) {
    // if (onceInitializer != null) {
    //   container._allModuleOnceInitializers.add(onceInitializer!);
    // }
    // if (simpleInitializer != null) {
    //   container._allModuleSimpleInitializers.add(simpleInitializer!);
    // }
    if (initializer != null) {
      container._allModuleInitializers.add(initializer!);
    }

    if (routeParser != null) {
      container._allModuleRouteParsers.add(routeParser!);
    }

    container._allModuleRoutes.addAll(routes);

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
    container._allModulePages.addAll(modulePages);
  }
}
