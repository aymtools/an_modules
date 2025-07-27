import 'dart:async';
import 'dart:collection';

import 'package:an_lifecycle_cancellable/an_lifecycle_cancellable.dart';
import 'package:an_viewmodel/an_viewmodel.dart';
import 'package:anlifecycle/anlifecycle.dart';
import 'package:cancellable/cancellable.dart';
import 'package:common/src/tools/lifecycle_ext.dart';
import 'package:flutter/material.dart';

/// 例如在这里定义符合视觉样式的 对话框等内容

class _MessageLoadingEntity {
  final Cancellable cancellable;
  final String message;

  _MessageLoadingEntity(this.cancellable, this.message);
}

class _MessageLoadingQueue with ChangeNotifier {
  final Queue<_MessageLoadingEntity> _queue = ListQueue();

  late final Cancellable _manager = () {
    return Cancellable()
      ..onCancel.then((reason) {
        for (var c in [..._queue]) {
          c.cancellable.cancel(reason);
        }
        _queue.clear();
      });
  }();

  void add(Cancellable cancellable, String message) {
    if (cancellable.isUnavailable) return;
    final entity = _MessageLoadingEntity(cancellable, message);
    _queue.add(entity);
    cancellable.onCancel.then((reason) => _check());
    notifyListeners();
  }

  _check() {
    _queue.removeWhere((e) => e.cancellable.isUnavailable);
    if (_queue.isEmpty) {
      _manager.cancel();
      return;
    }
    notifyListeners();
  }
}

/// 定制你自己的 loading 对话框 允许带一个消息的loading
class _MessageLoading extends StatelessWidget {
  final _MessageLoadingQueue queue;

  const _MessageLoading({super.key, required this.queue});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: queue,
      builder: (context, child) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: 10,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(),
                ),
                if (queue._queue.isNotEmpty &&
                    queue._queue.first.message.isNotEmpty)
                  Text(
                    queue._queue.first.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final _keyLifecycleLoadingExt = Object();

extension DialogForLifecycleExt on Lifecycle {
  /// 一个基于路由页面的 loading 如果当前页面是不可见时 需要等待可见才会触发 loading
  void showMessageLoading({required Cancellable cancellable, String? message}) {
    cancellable = makeLiveCancellable(other: cancellable);
    if (cancellable.isUnavailable) return;
    final routeState = findLifecycleOwner<LifecycleRouteOwnerState>();
    assert(routeState != null, 'LifecycleRouteOwnerState not found');

    final extData = routeState!.extData;
    _MessageLoadingQueue loading = extData.getOrPut(
        key: _keyLifecycleLoadingExt,
        ifAbsent: (lifecycle) {
          _MessageLoadingQueue result = _MessageLoadingQueue();
          lifecycle.launchWhenLifecycleEventDestroy(
              block: (_) => result._manager.cancel());
          result._manager.onCancel.then((value) => extData
              .remove<_MessageLoadingQueue>(key: _keyLifecycleLoadingExt));
          lifecycle.launchWhenLifecycleStateResumed(
            cancellable: result._manager,
            block: (_) => lifecycle.navigator.pushCancellableRoute(
              DialogRoute<void>(
                context: routeState.context,
                barrierColor: Colors.black54,
                barrierDismissible: false,
                useSafeArea: false,
                builder: (_) => _MessageLoading(queue: result),
              ),
              result._manager,
            ),
          );
          return result;
        });
    loading.add(cancellable, message ?? '');
  }

  ///  将一个loading 关联到 ValueNotifier<AsyncData<T>> 的一个数据源上 自动展示
  void showLoadingForAsyncNotifier<T extends Object>(
      {required ValueNotifier<AsyncData<T>> asyncNotifier,
      bool repeat = false,
      Cancellable? cancellable,
      String? message}) {
    Cancellable? loadingAble;
    if (repeat) {
      asyncNotifier
          .asStream()
          .bindCancellable(makeLiveCancellable(other: cancellable))
          .listen((event) {
        if (event.isLoading) {
          loadingAble = makeLiveCancellable(other: cancellable);
          repeatOnLifecycleStarted(
            cancellable: loadingAble,
            runWithDelayed: true,
            block: (cancellable) {
              showMessageLoading(cancellable: cancellable, message: message);
            },
          );
        } else {
          loadingAble?.cancel();
        }
      });
    } else {
      if (asyncNotifier.isLoading) {
        loadingAble = makeLiveCancellable(other: cancellable);
        repeatOnLifecycleStarted(
          cancellable: loadingAble,
          runWithDelayed: true,
          block: (cancellable) {
            showMessageLoading(cancellable: cancellable, message: message);
          },
        );
        asyncNotifier
            .firstWhereValue((value) => !value.isLoading,
                cancellable: loadingAble)
            .then((_) => loadingAble?.cancel());
      }
    }
  }

  /// 定义统一视觉的 AlertDialog
  Future<void> showAlert(
      {Widget? title,
      String? titleLabel,
      Widget? content,
      String? message,
      Widget? ok,
      String? okLabel,
      Cancellable? cancellable,
      LifecycleState runAtLeastState = LifecycleState.started}) {
    cancellable = makeLiveCancellable(other: cancellable);
    if (content == null && message == null) {
      throw Exception('content and message cannot be null at the same time');
    }
    if (runAtLeastState < LifecycleState.created) {
      throw Exception(
          'runAtLeastState must be greater than LifecycleState.created');
    }
    content ??= Text(
      message!,
      textAlign: TextAlign.center,
    );
    if (title == null && titleLabel != null) {
      title = Text(
        titleLabel,
        textAlign: TextAlign.center,
      );
    }
    if (ok == null && okLabel != null) {
      ok = Text(
        okLabel,
        textAlign: TextAlign.center,
      );
    }

    Completer<void> completer = Completer();
    if (cancellable.isUnavailable) return completer.future;

    final routeState = findLifecycleOwner<LifecycleRouteOwnerState>();
    assert(routeState != null, 'LifecycleRouteOwnerState not found');
    launchWhenLifecycleStateAtLeast(
        targetState: runAtLeastState,
        cancellable: cancellable,
        block: (_) async {
          await routeState!.lifecycle.navigator.pushCancellableRoute(
            DialogRoute<bool?>(
              context: routeState.context,
              builder: (BuildContext context) => WillPopScope(
                child: _DialogContent(
                  content: content!,
                  title: title,
                  confirm: ok,
                ),
                onWillPop: () async => false,
              ),
              barrierColor: Colors.black54,
              barrierDismissible: false,
              useSafeArea: false,
            ),
            cancellable,
          );
          completer.complete();
        });
    return completer.future;
  }

  /// 定义统一视觉的 ConfirmDialog
  Future<bool> showConfirm(
      {Widget? title,
      String? titleStr,
      Widget? content,
      String? message,
      Widget? ok,
      String? okLabel,
      Widget? cancel,
      String? cancelLabel,
      Cancellable? cancellable,
      LifecycleState runAtLeastState = LifecycleState.started}) {
    cancellable = makeLiveCancellable(other: cancellable);

    if (content == null && message == null) {
      throw Exception('content and message cannot be null at the same time');
    }
    if (runAtLeastState < LifecycleState.created) {
      throw Exception(
          'runAtLeastState must be greater than LifecycleState.created');
    }
    content ??= Text(message!);
    if (title == null && titleStr != null) {
      title = Text(
        titleStr,
        textAlign: TextAlign.center,
      );
    }
    if (ok == null && okLabel != null) {
      ok = Text(
        okLabel,
        textAlign: TextAlign.center,
      );
    }
    if (cancel == null && cancelLabel != null) {
      cancel = Text(
        cancelLabel,
        textAlign: TextAlign.center,
      );
    }

    assert(ok != null);
    assert(cancel != null);

    Completer<bool> completer = Completer();
    if (cancellable.isUnavailable) return completer.future;
    final routeState = findLifecycleOwner<LifecycleRouteOwnerState>();
    assert(routeState != null, 'LifecycleRouteOwnerState not found');
    launchWhenLifecycleStateAtLeast(
      targetState: runAtLeastState,
      cancellable: cancellable,
      block: (_) async {
        final select =
            await routeState!.lifecycle.navigator.pushCancellableRoute(
          DialogRoute<bool?>(
            context: routeState.context,
            builder: (BuildContext context) => WillPopScope(
              child: _DialogContent(
                content: content!,
                title: title,
                confirm: ok,
                cancel: cancel,
              ),
              onWillPop: () async => false,
            ),
            barrierColor: Colors.black54,
            barrierDismissible: false,
            useSafeArea: false,
          ),
          cancellable,
        );

        if (select != null) completer.complete(select);
      },
    );
    return completer.future;
  }
}

class _DialogContent extends StatelessWidget {
  final Widget? title;
  final Widget content;
  final Widget? confirm;
  final Widget? cancel;

  const _DialogContent(
      {super.key,
      this.title,
      required this.content,
      this.confirm,
      this.cancel});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: title,
      content: content,
      actions: [
        if (cancel != null)
          TextButton(
            child: cancel!,
            onPressed: () {
              Navigator.of(context).pop(false);
            },
          ),
        if (confirm != null)
          TextButton(
            child: confirm!,
            onPressed: () {
              Navigator.of(context).pop(true);
            },
          ),
      ],
    );
  }
}
