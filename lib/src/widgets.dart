part of 'modules.dart';

class _ModuleAssetBundleManager extends StatefulWidget {
  final String packageName;
  final Widget child;

  const _ModuleAssetBundleManager(
      {required this.packageName, required this.child});

  @override
  State<_ModuleAssetBundleManager> createState() =>
      _ModuleAssetBundleManagerState();
}

class _ModuleAssetBundleManagerState extends State<_ModuleAssetBundleManager> {
  _ModuleAssetBundle? _assetBundle;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant _ModuleAssetBundleManager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.packageName != oldWidget.packageName) {
      _assetBundle = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    _assetBundle ??=
        _ModuleAssetBundle(DefaultAssetBundle.of(context), widget.packageName);
    return DefaultAssetBundle(
      bundle: _assetBundle!,
      child: widget.child,
    );
  }

  @override
  void dispose() {
    super.dispose();
    _assetBundle?.clear();
  }
}

class _ModuleAssetBundle extends AssetBundle {
  final String _package;
  final AssetBundle _parent;

  _ModuleAssetBundle(this._parent, this._package);

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

  @override
  Future<T> loadStructuredData<T>(
      String key, Future<T> Function(String value) parser) async {
    return parser(await loadString(key));
  }
}

/// App的初始化管理器 用以自动化初始各个的模块配置信息 可能需要异步初始化
class AppInitializer extends ModuleContainerInitializer {
  /// [loading] 执行异步初始化时 展示的UI信息
  AppInitializer({super.key, required super.loading, required super.child})
      : super(moduleContainer: _app);

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

_ModuleContainer _container(
  ModuleContainer? modulePackage,
  ModuleContainer? moduleContainer,
) {
  if (modulePackage != null && modulePackage is _ModuleContainer) {
    return modulePackage;
  }
  return moduleContainer as _ModuleContainer;
}

@Deprecated('use ModuleContainerInitializer')
typedef ModulesInitializer = ModuleContainerInitializer;

/// 模块集成包的初始化管理器
class ModuleContainerInitializer extends StatelessWidget {
  final ModuleContainer moduleContainer;
  final Widget loading;
  final Widget child;

  /// [modulePackage] 指定模块配置信息
  /// [loading] 执行异步初始化时 展示的UI信息
  ModuleContainerInitializer(
      {GlobalKey? key,
      @Deprecated('use moduleContainer') ModuleContainer? modulePackage,
      ModuleContainer? moduleContainer,
      required this.loading,
      required this.child})
      : assert(!(modulePackage == null && moduleContainer == null)),
        moduleContainer = _container(modulePackage, moduleContainer),
        super(
            key: key ??
                _container(modulePackage, moduleContainer)
                    ._initializeModulesKey) {
    final container = (this.moduleContainer as _ModuleContainer);
    container._initialize();
    if (key != null && key != container._initializeModulesKey) {
      container._initializeModulesKey = key;
    }
  }

  /// 直接用在 builder的快速函数
  /// ignore: non_constant_identifier_names
  static Widget Function(BuildContext, Widget?) builder(
          {@Deprecated('use moduleContainer') ModuleContainer? modulePackage,
          ModuleContainer? moduleContainer,
          required Widget initializing,
          TransitionBuilder? builder}) =>
      (context, child) => ModuleContainerInitializer(
            moduleContainer: _container(modulePackage, moduleContainer),
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

  @override
  Widget build(BuildContext context) {
    final container = (moduleContainer as _ModuleContainer);
    final loading = container._loadingWidget(this.loading);
    return _MInitializer(
      loading: (_) => loading,
      onSuccess: (_) => _ModuleContainerInitializer(
        moduleContainer: container,
        loading: loading,
        child: child,
      ),
      moduleContainer: container,
    );
  }
}

class _ModuleContainerInitializer extends StatefulWidget {
  final _ModuleContainer moduleContainer;
  final Widget loading;
  final Widget child;

  const _ModuleContainerInitializer(
      {required this.moduleContainer,
      required this.loading,
      required this.child});

  @override
  State<_ModuleContainerInitializer> createState() =>
      _ModuleContainerInitializerState();
}

class _ModuleContainerInitializerState
    extends State<_ModuleContainerInitializer> {
  // bool _isNotFirst = false;

  _ModuleContainer get _container => widget.moduleContainer;

  // void _firstBuild(BuildContext context) {
  //   if (_isNotFirst) return;
  //   _isNotFirst = true;
  //
  //   _container._callOnceInitializer(context);
  //
  //   final msis = List.unmodifiable(_container._allModuleSimpleInitializers);
  //   for (final i in msis) {
  //     final Object? debugCheckForReturnedFuture = i.call(context) as dynamic;
  //
  //     assert(() {
  //       if (debugCheckForReturnedFuture is Future) {
  //         throw FlutterError.fromParts(<DiagnosticsNode>[
  //           ErrorSummary('${i.runtimeType} returned a Future.'),
  //           ErrorDescription(
  //               '${i.runtimeType} must be a void method without an `async` keyword.'),
  //         ]);
  //       }
  //       return true;
  //     }());
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    // _firstBuild(context);
    final mis = List.unmodifiable(_container._allModuleInitializers.reversed);
    var result = widget.child;
    for (final wrapper in mis) {
      result = _ModuleInitializerWrapper(
          key: ValueKey(wrapper),
          wrapper: wrapper,
          loading: widget.loading,
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
  final _ModuleContainerBase moduleContainer;
  final Widget child;

  _ModuleInitializerLoading(
      {required this.moduleContainer, required this.child})
      : super(key: moduleContainer._initializeLoadingKey);

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
