import 'package:an_dialogs/an_dialogs.dart';
import 'package:an_dialogs/pop_intercept.dart';
import 'package:an_lifecycle_cancellable/an_lifecycle_cancellable.dart';
import 'package:an_viewmodel/an_viewmodel.dart';
import 'package:anlifecycle/anlifecycle.dart';
import 'package:cancellable/cancellable.dart';
import 'package:flutter/material.dart';

initDialogs() {
  final dConfigs = DialogsConfig.instance;
  dConfigs.onBackPressedIntercept = (child) => PopScopeCompat(child: child);

  final lConfigs = LoadingConfig.instance;
  lConfigs.onBackPressedIntercept = (child) => PopScopeCompat(child: child);
}

extension DialogForLifecycleExt on Lifecycle {
  ///  将一个loading 关联到 ValueNotifier&lt;AsyncData&lt;T>> 的一个数据源上 自动展示
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
              showLoading(cancellable: cancellable, message: message ?? '');
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
            showLoading(cancellable: cancellable, message: message ?? '');
          },
        );
        asyncNotifier
            .firstWhereValue((value) => !value.isLoading,
                cancellable: loadingAble)
            .then((_) => loadingAble?.cancel());
      }
    }
  }
}
