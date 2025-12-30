part of 'modules.dart';

/// App（根）ModuleContainer 的 id
const String kAppContainerId = "";

/// 全局容器注册表
final Map<String, ModuleContainer> _registry = {};

/// app包 全局唯一
final ModuleContainer _app = ModuleContainer._(id: kAppContainerId);

// =========================
// ModuleContainer definition
// =========================

class ModuleContainer {
  /// 当前容器唯一标识
  final String id;

  /// 父容器 id
  /// App 容器使用 kAppContainerId
  final String parentId;

  final Map<String, Module> _modules = {};

  ModuleContainer._({
    required this.id,
    this.parentId = kAppContainerId,
  }) {
    if (_registry.containsKey(id)) {
      throw StateError('ModuleContainer already exists: $id');
    }
    _registry[id] = this;
  }

  // -------------------------
  // Registration
  // -------------------------

  void register(Module module) {
    if (_inner._isInitialized) {
      throw StateError('ModuleContainer already initialized: $id');
    }
    if (_modules.containsKey(module.name)) {
      throw StateError('Module already registered: ${module.name}');
    }
    _modules[module.name] = module;
  }

  /// 对当前容器内的 Module 进行排序
  List<Module> _sortModules() {
    final cycle = _detectCycleInCurrentContainer();
    if (cycle != null) {
      throw StateError(
        'Circular dependency detected:\n'
        '${cycle.join(' -> ')}',
      );
    }
    return _topologicalSort();
  }

  // -------------------------
  // Container helpers
  // -------------------------

  ModuleContainer? get _parentContainer {
    if (parentId == kAppContainerId || parentId.isEmpty) {
      return null;
    }
    return _registry[parentId];
  }

  bool _existsInCurrentContainer(String moduleName) {
    return _modules.containsKey(moduleName);
  }

  /// 向父容器 / App 容器递归查找
  bool _existsInHierarchy(String moduleName) {
    if (_modules.containsKey(moduleName)) return true;
    return _parentContainer?._existsInHierarchy(moduleName) ?? false;
  }

  // -------------------------
  // Cycle detection (DFS)
  // 仅检测当前容器
  // -------------------------

  List<String>? _detectCycleInCurrentContainer() {
    final visited = <String>{};
    final visiting = <String>{};
    final path = <String>[];

    List<String>? dfs(String name) {
      if (visiting.contains(name)) {
        final index = path.indexOf(name);
        return [...path.sublist(index), name];
      }

      if (visited.contains(name)) return null;

      visiting.add(name);
      path.add(name);

      final module = _modules[name]!;

      final deps = [
        ...module.requiredDependencies.where(_existsInCurrentContainer),
        ...module.optionalDependencies.where(_existsInCurrentContainer),
      ];

      for (final dep in deps) {
        final result = dfs(dep);
        if (result != null) return result;
      }

      visiting.remove(name);
      path.removeLast();
      visited.add(name);
      return null;
    }

    for (final name in _modules.keys) {
      final result = dfs(name);
      if (result != null) return result;
    }

    return null;
  }

  // -------------------------
  // Topological sort (Kahn)
  // -------------------------

  List<Module> _topologicalSort() {
    final inDegree = <String, int>{};
    final graph = <String, List<String>>{};

    for (final name in _modules.keys) {
      inDegree[name] = 0;
      graph[name] = [];
    }

    for (final module in _modules.values) {
      // ===== required dependencies =====
      for (final dep in module.requiredDependencies) {
        // 当前容器内
        if (_existsInCurrentContainer(dep)) {
          graph[dep]!.add(module.name);
          inDegree[module.name] = inDegree[module.name]! + 1;
          continue;
        }

        // 父容器 / App 容器（特殊规则允许）
        if (_parentContainer != null &&
            _parentContainer!._existsInHierarchy(dep)) {
          continue;
        }

        throw StateError(
          'Missing required dependency: '
          '${module.name} depends on $dep',
        );
      }

      // ===== optional dependencies =====
      for (final dep in module.optionalDependencies) {
        if (_existsInCurrentContainer(dep)) {
          graph[dep]!.add(module.name);
          inDegree[module.name] = inDegree[module.name]! + 1;
        }
      }
    }

    final queue = <String>[
      for (final e in inDegree.entries)
        if (e.value == 0) e.key
    ];

    final result = <Module>[];

    while (queue.isNotEmpty) {
      final name = queue.removeAt(0);
      result.add(_modules[name]!);

      for (final next in graph[name]!) {
        inDegree[next] = inDegree[next]! - 1;
        if (inDegree[next] == 0) {
          queue.add(next);
        }
      }
    }

    return result;
  }

  /// 是否存在 module
  bool hasModule(String moduleName) {
    return _modules.containsKey(moduleName);
  }

  late final _ModuleContainerInner _inner =
      _ModuleContainerInner(container: this);

  ///  设置默认的路由生成器
  set pageRouteGenerator(MPageRouteGenerator generator) =>
      _inner.pageRouteGenerator = generator;

  /// 当无法使用[generateRouteFactory]时使用，将会无法自定义路由和路由解析拦截   模块页面生成器
  Map<String, WidgetBuilder> get generateRouters => _inner.generateRouters;

  /// 模块路由生成器
  /// 使用这个时无需使用 [generateRouters] 内部已经包含
  RouteFactory get generateRouteFactory => _inner.generateRouteFactory;

  static ModuleContainer _getOrCreate(String id) {
    if (id.isEmpty) return _app;
    return _registry.putIfAbsent(id, () => ModuleContainer._(id: id));
  }

  static ModuleContainer? _getOrNull(String id) {
    if (id.isEmpty) return _app;
    return _registry[id];
  }

  static bool _hasContainer(String id) {
    if (id.isEmpty) return true;
    return _registry.containsKey(id);
  }
}
