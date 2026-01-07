part of 'modules.dart';

/// 全局容器注册表
final Map<String, _ModuleContainer> _registry = {};

mixin _ModuleContainerSorted on _ModuleContainerBase {
  /// 父容器 id
  /// App 容器使用 kAppContainerId
  final String parentId = kAppContainerId;

  final Map<String, Module> _modules = {};

// -------------------------
  // Registration
  // -------------------------

  @override
  void register(Module module) {
    if (_isInitialized) {
      throw StateError('ModuleContainer already initialized: $id');
    }
    if (_modules.containsKey(module.name)) {
      throw StateError('Module already registered: ${module.name}');
    }
    _modules[module.name] = module;
  }

  /// 对当前容器内的 Module 进行排序
  @override
  List<Module> sortModules() {
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

  _ModuleContainer? get _parentContainer {
    if (id == kAppContainerId) return null;
    if (parentId == kAppContainerId || parentId.isEmpty) {
      return _app;
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
  @override
  bool hasModule(String moduleName) {
    return _modules.containsKey(moduleName);
  }
}
