part of 'modules.dart';

class _Module implements Module {
  _Module({
    required this.name,
    List<String>? requiredDependencies,
    List<String>? optionalDependencies,
    this.initializer,
    this.simpleInitializer,
    this.onceInitializer,
    Map<String, MPageBuilder>? pages,
    this.pageWrapper,
    Map<String, MPageRouteBuilder>? routes,
    this.routeParser,
    MInitializerExecutor? initializerExecutor,
    this.initializerErrorBuilder,
  })  : requiredDependencies = requiredDependencies == null
            ? const []
            : List.unmodifiable(requiredDependencies),
        optionalDependencies = optionalDependencies == null
            ? const []
            : List.unmodifiable(optionalDependencies),
        pages = pages == null ? const {} : Map.unmodifiable(pages),
        routes = routes == null ? const {} : Map.unmodifiable(routes),
        _initializerExecutor = initializerExecutor;

  @override
  final String name;

  @override
  final List<String> optionalDependencies;

  @override
  final List<String> requiredDependencies;
  @override
  final MInitializer? initializer;

  @override
  final MSInitializer? simpleInitializer;

  @override
  final MSInitializer? onceInitializer;

  @override
  final Map<String, MPageBuilder> pages;

  @override
  final MPageWrapper? pageWrapper;

  @override
  final Map<String, MPageRouteBuilder> routes;

  @override
  final MRouteParser? routeParser;

  final MInitializerExecutor? _initializerExecutor;

  bool _onceNeedCall = true;

  @override
  MInitializerExecutor? get initializerExecutor {
    if (_initializerExecutor != null) return _initializerExecutor;
    MInitializerExecutor? result;

    if (onceInitializer != null) {
      result = (attempt) async {
        if (_onceNeedCall) {
          _onceNeedCall = false;
          onceInitializer!(attempt.context);
        }
        if (simpleInitializer != null) {
          simpleInitializer!(attempt.context);
        }
      };
    } else if (simpleInitializer != null) {
      result = (attempt) async {
        simpleInitializer!(attempt.context);
      };
    }
    return result;
  }

  @override
  final MInitializerErrorBuilder? initializerErrorBuilder;
}
