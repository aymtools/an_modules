part of 'modules.dart';

/// core ModuleContainer 的 id
const String kCoreContainerId = "core";

/// app 内全家唯一 core 包 是所有container的必须依赖
final _ModuleContainer _core = _CoreModuleContainer._();

class _CoreModuleContainer extends _ModuleContainer {
  _CoreModuleContainer._() : super._(id: kCoreContainerId);

  bool _isRunAll = false;

  @override
  void _onInitialized(List<Module> modules) {
    super._onInitialized(modules);
    assert(() {
      for (var module in modules) {
        if (module.routes.isNotEmpty) {
          throw StateError('Core module cannot have routes: ${module.name}');
        }
        if (module.pages.isNotEmpty) {
          throw StateError('Core module cannot have pages: ${module.name}');
        }
        if (module.initializer != null) {
          throw StateError(
              'Core module cannot have initializer: ${module.name}');
        }
        if (module.routeParser != null) {
          throw StateError(
              'Core module cannot have routeParser: ${module.name}');
        }
      }
      return true;
    }());
  }

  @override
  Future<void> runAll() async {
    if (_isInitialized && isDone) return;
    if (_isRunAll) return;
    _isRunAll = true;
    _initialize();
    super.runAll();
  }

  @override
  _ModuleContainer? get _parentContainer => null;

  @override
  set parentContainerId(String containerId) {
    throw StateError('CoreModuleContainer cannot have a parent');
  }
}
