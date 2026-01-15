part of 'modules.dart';

class MIContext {
  BuildContext? _context;
  final int count;
  final Object? lastError;

  MIContext({
    required this.count,
    this.lastError,
  });

  bool get isRetry => count > 0;

  BuildContext get context => _context!;

  MIContext copyWith({
    int? count,
    Object? lastError,
  }) {
    return MIContext(
      count: count ?? this.count,
      lastError: lastError ?? this.lastError,
    );
  }
}

enum MIState {
  idle,
  running,
  waitingUser,
  success,
}

class MIController {
  MIController._(this._manager, this._taskId);

  final _ModuleContainerMInitializers _manager;
  final String _taskId;

  void retry() => _manager.retry(_taskId);

  void ignore() => _manager.ignore(_taskId);
}

typedef MInitializerExecutor = FutureOr<void> Function(
  MIContext attempt,
);

typedef MInitializerErrorBuilder = Widget Function(
  BuildContext context,
  Object error,
  MIContext attempt,
  MIController controller,
);

class _MITask {
  final Module task;
  MIContext attempt;
  MIState state;

  String get id => task.name;

  _MITask(this.task)
      : attempt = MIContext(count: 0),
        state = MIState.idle;

  List<String> get requiredDependencies => task.requiredDependencies;

  List<String> get optionalDependencies => task.optionalDependencies;

  List<String> get dependencies =>
      [...requiredDependencies, ...optionalDependencies];

  MInitializerErrorBuilder? get errorBuilder => task.initializerErrorBuilder;

  MInitializerExecutor? get executor => task.initializerExecutor;
}

mixin _ModuleContainerMInitializers
    on _ModuleContainerBase, _ModuleContainerSorted {
  final Map<String, _MITask> _tasks = {};

  final StreamController<void> _changed = StreamController.broadcast();

  BuildContext? _context;

  Stream<void> get changes => _changed.stream;

  @override
  void _onInitialized(List<Module> modules) {
    super._onInitialized(modules);
    for (final module in modules) {
      _tasks[module.name] = _MITask(module);
    }
  }

  bool get isDone {
    return _tasks.isEmpty ||
        _tasks.values.map((e) => e.state).every((s) => s == MIState.success);
  }

  bool get hasNext {
    return _tasks.isNotEmpty &&
        _tasks.values.map((e) => e.state).any((s) => s != MIState.success);
  }

  _MITask? get firstWaitingTask {
    for (final task in _tasks.values) {
      if (task.state == MIState.waitingUser) {
        return task;
      }
    }
    return null;
  }

  void attachContext(BuildContext context) {
    _context = context;
  }

  void detachContext() {
    _context = null;
  }

  Future<void> runAll() async {
    _schedule();

    while (hasNext) {
      await _changed.stream.first;
      _schedule();
    }
  }

  void retry(String id) {
    final task = _tasks[id]!;
    task.attempt =
        task.attempt.copyWith(count: task.attempt.count + 1, lastError: null);
    task.state = MIState.idle;
    _changed.add(null);
    _schedule();
  }

  void ignore(String id) {
    final task = _tasks[id]!;
    task.state = MIState.success;
    _changed.add(null);
    _schedule();
  }

  MIController controllerOf(String id) {
    return MIController._(this, id);
  }

  void _schedule() {
    for (final task in _tasks.values) {
      if (_canRun(task)) {
        _run(task);
      }
    }
    if (isDone) {
      _context = null;
    }
  }

  bool _depForParent(String dep) {
    final parent = _parentContainer;
    if (parent == null) return false;
    if (parent.hasModule(dep)) return true;

    return parent._depForParent(dep);
  }

  bool _canRun(_MITask task) {
    if (task.state != MIState.idle) return false;

    for (final dep in task.requiredDependencies) {
      if (_depForParent(dep)) continue;
      if (_tasks[dep]?.state != MIState.success) return false;
    }
    for (final dep in task.optionalDependencies) {
      if (_depForParent(dep)) continue;
      if (!_tasks.containsKey(dep)) continue;
      if (_tasks[dep]?.state != MIState.success) return false;
    }
    return true;
  }

  void _run(_MITask task) async {
    final executor = task.executor;
    if (executor == null) {
      task.state = MIState.success;
      _changed.add(null);
      _schedule();
      return;
    }

    task.state = MIState.running;
    _changed.add(null);

    final attempt = task.attempt;
    attempt._context = _context;

    try {
      await executor(attempt);
      task.state = MIState.success;
      _changed.add(null);
      _schedule();
    } catch (error) {
      if (task.errorBuilder != null) {
        task.attempt = attempt.copyWith(lastError: error);
        task.state = MIState.waitingUser;
        _changed.add(null);
      } else {
        task.state = MIState.success;
        _changed.add(null);
        _schedule();
      }
    } finally {
      attempt._context = null;
    }
  }

  MIState state(String id) {
    return _tasks[id]!.state;
  }
}

class _MInitializer extends StatefulWidget {
  final _ModuleContainerMInitializers _manager;
  final WidgetBuilder onSuccess;

  final WidgetBuilder loading;

  const _MInitializer({
    required ModuleContainer moduleContainer,
    required this.onSuccess,
    required this.loading,
  }) : _manager = moduleContainer as _ModuleContainerMInitializers;

  @override
  State<_MInitializer> createState() => _MInitializerState();
}

class _MInitializerState extends State<_MInitializer> {
  bool _isInitialized = false;

  Future<void> _initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;
    final ctx = context;

    // ignore: use_build_context_synchronously
    widget._manager.attachContext(ctx);
    widget._manager.runAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initialize();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: widget._manager.changes,
      builder: (context, _) {
        final allDone = widget._manager.isDone;

        if (allDone) {
          return widget.onSuccess(context);
        }

        final firstWaiting = widget._manager.firstWaitingTask;
        if (firstWaiting != null) {
          return firstWaiting.task.initializerErrorBuilder!(
            context,
            firstWaiting.attempt.lastError!,
            firstWaiting.attempt,
            widget._manager.controllerOf(firstWaiting.id),
          );
        }

        return widget.loading(context);
      },
    );
  }

  @override
  void dispose() {
    widget._manager.detachContext();
    super.dispose();
  }
}
