import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'container.dart';
part 'container_inner.dart';
part 'modular.dart';
part 'routes.dart';
part 'widgets.dart';

/// 路由页面
typedef MPageBuilder = Widget Function(Object? arguments);

/// 统一的路由页面的 wrapper  必须由 [MPageBuilder] 生成的 直接生成route的无效
typedef MPageWrapper = Widget Function(Widget pageContent);

/// 直接定义路由信息 [pageContent] 继续由 [MPageBuilder] 提供
typedef MPageRouteBuilder<T> = PageRoute<T> Function(
    Object? arguments, Widget pageContent);

/// 当前模块需要进行 ui 等待式的初始化 会插入在 生成 Navigator 之前
/// [loading] 是加载时的 Widget 提供统一的样式
typedef MInitializer = Widget Function(Widget loading, Widget child);

/// 简易快速初始化器 只支持同步初始化
typedef MSInitializer = void Function(BuildContext context);

/// 路由解析器 返回 [null] 时，表示非当前模块内的路由 当前不关注
/// 非常小心 注意死循环
/// [context] 是通过ModulesInitializer获取的 非Navigator 或者 Route 相关的 请勿使用相关功能
typedef MRouteParser = RouteSettings? Function(
    BuildContext context, RouteSettings settings);

/// page content widget 默认的 的路由生成器
typedef MPageRouteGenerator<T> = PageRoute<T> Function(
    RouteSettings settings, Widget content);

/// Modularization 模块抽象类
abstract class Module {
  /// 模块名称
  String get name;

  /// 必须依赖
  List<String> get requiredDependencies => [];

  /// 可选依赖
  List<String> get optionalDependencies => [];

  /// 模块所有页面
  Map<String, MPageBuilder> get pages;

  /// 当前模块内的页面包装器
  MPageWrapper? get pageWrapper => null;

  /// 模块内自定义路由页面
  Map<String, MPageRouteBuilder> get routes => {};

  /// 模块初始化器
  MInitializer? get initializer;

  /// 模块初始化器 简易版
  MSInitializer? get simpleInitializer;

  /// 模块初始化器  只会调用一次
  MSInitializer? get onceInitializer;

  /// 指定当前模块内的路由解析器 仅仅对[routes] 生效
  MRouteParser? get routeParser => null;

  /// 模块的所有信息
  /// - [name] packageName 会自动替换assets
  /// - [requiredDependencies] 必须依赖的模块
  /// - [optionalDependencies] 可选依赖的模块
  /// - [pages] 模块内所包含的页面信息
  /// - [pageWrapper] 对模块内的page 增加一个转换器可以统一的注入所需的 内容
  /// - [routes] 模块内所包含的路由信息
  /// - [initializer] 如果模块需要异步化的初始化
  /// - [simpleInitializer] 模块简单的同步化的初始器
  /// - [onceInitializer] 整个app内只会调用一次从初始化器
  /// - [routeParser] 模块内的路由解析器
  factory Module({
    required String name,
    List<String>? requiredDependencies,
    List<String>? optionalDependencies,
    Map<String, MPageBuilder>? pages,
    MPageWrapper? pageWrapper,
    Map<String, MPageRouteBuilder>? routes,
    MInitializer? initializer,
    MSInitializer? simpleInitializer,
    MSInitializer? onceInitializer,
    MRouteParser? routeParser,
  }) =>
      _Module(
          name: name,
          requiredDependencies: requiredDependencies,
          optionalDependencies: optionalDependencies,
          initializer: initializer,
          simpleInitializer: simpleInitializer,
          onceInitializer: onceInitializer,
          pages: pages,
          pageWrapper: pageWrapper,
          routes: routes,
          routeParser: routeParser);

  /// 注册一个模块
  static void registerModule({required Module module, String? containerId}) {
    ModuleContainer._getOrCreate(containerId ?? kAppContainerId)
        .register(module);
  }

  /// 注册一个子模块 不会自动合并到 app 中 需要自行管理 sub的处理
  /// 已过时，使用 [registerModule] 指定 [containerId]
  @Deprecated('use registerModule')
  static void registerSubModule(
      {required String subModuleName, required Module module}) {
    assert(subModuleName.isNotEmpty, 'Use registerModule');
    ModuleContainer._getOrCreate(subModuleName).register(module);
  }

  /// 获取已注册是子模块的管理包
  @Deprecated('use getModuleContainer')
  static ModuleContainer? getSubModule(String subModuleName) =>
      getModuleContainer(subModuleName);

  /// 获取已注册是子模块的管理包
  static ModuleContainer? getModuleContainer(String containerId) {
    return ModuleContainer._getOrNull(containerId);
  }

  /// 判断子模块是否已经注册
  @Deprecated('use hasModuleContainer')
  static bool hasSubModule(String subModuleName) =>
      hasModuleContainer(subModuleName);

  /// 判断子模块是否已经注册
  static bool hasModuleContainer(String containerId) {
    return ModuleContainer._hasContainer(containerId);
  }

  /// 获取app的 模块化的配置 内容
  static ModuleContainer get app => _app;
}

/// 保持旧版兼容 但是由于存在冲突的可能行较大 所以调整为从 [Module.app] 来获取
@Deprecated('use Module.app')
ModuleContainer get app => _app;
