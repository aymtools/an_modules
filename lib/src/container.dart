part of 'modules.dart';

/// app包 全局唯一
final _ModuleContainer _app = _ModuleContainer._(id: kAppContainerId);

// =========================
// ModuleContainer definition
// =========================
class _ModuleContainer extends ModuleContainer
    with
        _ModuleContainerBase,
        _ModuleContainerRoutes,
        _ModuleContainerSorted,
        _ModuleContainerMInitializers,
        _ModuleContainerInitializers {
  /// 当前容器唯一标识
  @override
  final String id;

  _ModuleContainer._({
    required this.id,
  }) : super._() {
    if (_registry.containsKey(id)) {
      throw StateError('ModuleContainer already exists: $id');
    }
    _registry[id] = this;
  }

  static _ModuleContainer _getOrCreate(String id) {
    if (id.isEmpty) return throw StateError('ModuleContainer id is empty');
    if (id == kAppContainerId) return _app;
    if (id == kCoreContainerId) return _core;
    return _registry.putIfAbsent(id, () => _ModuleContainer._(id: id));
  }

  static _ModuleContainer? _getOrNull(String id) {
    if (id.isEmpty) return null;
    if (id == kAppContainerId) return _app;
    if (id == kCoreContainerId) return _core;
    return _registry[id];
  }

  static bool _hasContainer(String id) {
    if (id.isEmpty) return false;
    if (id == kAppContainerId) return true;
    if (id == kCoreContainerId) return true;
    return _registry.containsKey(id);
  }
}
