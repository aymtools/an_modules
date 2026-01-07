part of 'modules.dart';

mixin _ModuleContainerBase on ModuleContainer {
  /// 所有的模块的路由解析器
  final List<MRouteParser> _allModuleRouteParsers = [];

  /// 所有的模块的路由页面生成器
  final Map<String, MPageBuilder> _allModulePages = {};

  /// 所有的模块的路由生成器
  final Map<String, MPageRouteBuilder> _allModuleRoutes = {};

  GlobalKey _initializeModulesKey = GlobalKey();

  final GlobalKey _initializeLoadingKey = GlobalKey();

  Widget? _moduleInitializerLoading;

  Widget _loadingWidget(Widget loading) {
    _moduleInitializerLoading ??=
        _ModuleInitializerLoading(moduleContainer: this, child: loading);
    return _moduleInitializerLoading!;
  }

  bool get _isInitialized;

  @mustCallSuper
  void _initialize() {}

  @mustCallSuper
  void _onInitialized(List<Module> modules) {}

  /// 对当前容器内的 Module 进行排序
  List<Module> sortModules();
}
