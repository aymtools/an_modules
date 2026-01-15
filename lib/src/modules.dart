import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'container.dart';
part 'container_base.dart';
part 'container_core.dart';
part 'container_initializer.dart';
part 'container_module_initializer.dart';
part 'container_routes.dart';
part 'container_sorted.dart';
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
/// [context] 是通过ModulesInitializer获取的 非Navigator 或者 Route 相关的context 请勿使用相关功能
typedef MRouteParser = RouteSettings? Function(
    BuildContext context, RouteSettings settings);

/// page content widget 默认的 的路由生成器
typedef MPageRouteGenerator<T> = PageRoute<T> Function(
    RouteSettings settings, Widget content);

/// Modularization 模块抽象类
/// - [name] 模块名称
/// - [requiredDependencies] 必须依赖的模块
/// - [optionalDependencies] 可选依赖的模块
/// - [pages] 模块内所包含的页面信息
/// - [pageWrapper] 对模块内的page 增加一个转换器可以统一的注入所需的 内容
/// - [routes] 模块内所包含的路由页面信息
/// - [routeParser] 路由解析器 所有模块都会被调用执行
/// - [initializer] **已过时** 如果模块需要异步化的初始化 会串行执行 最晚执行
/// - [simpleInitializer] **已过时** 简易初始化器 [initializerExecutor]存在时不会执行
/// - [onceInitializer] **已过时**  单次快速初始化器 [initializerExecutor]存在时不会执行
/// - [initializerExecutor] 可以以Future的定义一个函数进行初始化 会解析依赖关系 按照依赖自动排序执行
/// - [initializerErrorBuilder] 定义初始化失败时如何处理 可选重试或拦截  为空时 忽略错误 继续执行后续的初始化
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

  /// 块初始化器，提供一个[FutureOr&lt;void>],
  MInitializerExecutor? get initializerExecutor;

  /// 未设置时为忽略错误 继续初始化
  MInitializerErrorBuilder? get initializerErrorBuilder;

  /// 模块的所有信息
  /// - [name] packageName 会自动替换assets
  /// - [requiredDependencies] 必须依赖的模块
  /// - [optionalDependencies] 可选依赖的模块
  /// - [pages] 模块内所包含的页面信息
  /// - [pageWrapper] 对模块内的page 增加一个转换器可以统一的注入所需的 内容
  /// - [routes] 模块内所包含的路由信息
  /// - [routeParser] 模块内的路由解析器 执行路由解析时  所有模块都会被调用执行
  /// - [initializer] **已过时** 如果模块需要异步化的初始化 会串行执行
  /// - [simpleInitializer] **已过时** 模块简单的同步化的初始器 [initializerExecutor]存在时不会执行
  /// - [onceInitializer] **已过时** 整个app内只会调用一次从初始化器 [initializerExecutor]存在时不会执行
  /// - [initializerExecutor] 模块初始化器，提供一个[FutureOr&lt;void>],
  /// 如果设置了 [initializerErrorBuilder] 的重试，则要允许重试执行。
  /// 如果没有依赖则并行future 如果存在依赖，按照依赖顺序执行
  /// - [initializerErrorBuilder] 初始化失败时如何处理
  factory Module({
    required String name,
    List<String>? requiredDependencies,
    List<String>? optionalDependencies,
    Map<String, MPageBuilder>? pages,
    MPageWrapper? pageWrapper,
    Map<String, MPageRouteBuilder>? routes,
    @Deprecated('use initializerExecutor, v1.2.0') MInitializer? initializer,
    @Deprecated('use initializerExecutor, v1.2.0')
    MSInitializer? simpleInitializer,
    @Deprecated('use initializerExecutor, v1.2.0')
    MSInitializer? onceInitializer,
    MRouteParser? routeParser,
    MInitializerExecutor? initializerExecutor,
    MInitializerErrorBuilder? initializerErrorBuilder,
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
          routeParser: routeParser,
          initializerExecutor: initializerExecutor,
          initializerErrorBuilder: initializerErrorBuilder);

  /// 注册一个模块
  static void registerModule(
      {required Module module, String containerId = kAppContainerId}) {
    _ModuleContainer._getOrCreate(containerId).register(module);
  }

  /// 注册一个子模块 不会自动合并到 app 中 需要自行管理 sub的处理
  /// 已过时，使用 [registerModule] 指定 [containerId]
  @Deprecated('use registerModule')
  static void registerSubModule(
      {required String subModuleName, required Module module}) {
    assert(subModuleName.isNotEmpty, 'Use registerModule');
    registerModule(module: module, containerId: subModuleName);
  }

  /// 获取已注册是子模块的管理包
  @Deprecated('use getModuleContainer')
  static ModuleContainer? getSubModule(String subModuleName) =>
      getModuleContainer(subModuleName);

  /// 获取已注册是子模块的管理包
  static ModuleContainer? getModuleContainer(String containerId) {
    return _ModuleContainer._getOrNull(containerId);
  }

  /// 判断子模块是否已经注册
  @Deprecated('use hasModuleContainer')
  static bool hasSubModule(String subModuleName) =>
      hasModuleContainer(subModuleName);

  /// 判断子模块是否已经注册
  static bool hasModuleContainer(String containerId) {
    return _ModuleContainer._hasContainer(containerId);
  }

  /// 获取app的 模块化的配置 内容
  static ModuleContainer get app => _app;
}

/// 保持旧版兼容 但是由于存在冲突的可能行较大 所以调整为从 [Module.app] 来获取
@Deprecated('use Module.app')
ModuleContainer get app => _app;

/// App（根）ModuleContainer 的 id
const String kAppContainerId = "app";

/// 记录和管理模块合集
abstract class ModuleContainer {
  String get id;

  void register(Module module);

  /// 是否存在 module
  bool hasModule(String moduleName);

  ///  设置默认的路由生成器
  set pageRouteGenerator(MPageRouteGenerator generator);

  /// 当无法使用[generateRouteFactory]时使用，将会无法自定义路由和路由解析拦截   模块页面生成器
  Map<String, WidgetBuilder> get generateRouters;

  /// 模块路由生成器
  /// 使用这个时无需使用 [generateRouters] 内部已经包含
  RouteFactory get generateRouteFactory;

  ModuleContainer._();

  @Deprecated('will remove')
  factory ModuleContainer({String id = kAppContainerId}) =>
      _ModuleContainer._(id: id);

  /// 保持兼容性
  void registerModule(Module module) => register(module);

  set parentContainerId(String containerId);
}
