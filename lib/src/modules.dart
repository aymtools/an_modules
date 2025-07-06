import 'package:flutter/widgets.dart';

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

/// 路由解析器 返回 [null] 时，表示非当前模块内的路由
typedef MRouteParser = RouteSettings? Function(RouteSettings settings);

/// page content widget 默认的 的路由生成器
typedef MPageRouteGenerator<T> = PageRoute<T> Function(
    RouteSettings settings, Widget content);

/// 模块抽象类
abstract class Module {
  /// 模块名称
  String get name;

  /// 模块所有页面
  Map<String, MPageBuilder> get pages;

  /// 当前模块内的页面包装器
  MPageWrapper? get pageWrapper => null;

  /// 模块内自定义路由页面
  Map<String, MPageRouteBuilder> get routes => {};

  /// 模块初始化器
  MInitializer? get initializer;

  /// 指定当前模块内的路由解析器 仅仅对[routes] 生效
  MRouteParser? get routeParser => null;

  factory Module({
    required String name,
    Map<String, MPageBuilder> pages = const {},
    MPageWrapper? pageWrapper,
    Map<String, MPageRouteBuilder> routes = const {},
    MInitializer? initializer,
    MRouteParser? routeParser,
  }) =>
      _Module(
          name: name,
          initializer: initializer,
          pages: pages,
          pageWrapper: pageWrapper,
          routes: routes,
          routeParser: routeParser);
}

class _Module implements Module {
  _Module({
    required this.name,
    this.initializer,
    this.pages = const {},
    this.pageWrapper,
    this.routes = const {},
    this.routeParser,
  });

  @override
  final String name;

  @override
  final MInitializer? initializer;

  @override
  final Map<String, MPageBuilder> pages;

  @override
  final MPageWrapper? pageWrapper;

  @override
  final Map<String, MPageRouteBuilder> routes;

  @override
  final MRouteParser? routeParser;
}
