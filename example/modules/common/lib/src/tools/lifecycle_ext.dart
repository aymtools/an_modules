import 'package:an_lifecycle_cancellable/an_lifecycle_cancellable.dart';
import 'package:anlifecycle/anlifecycle.dart';
import 'package:common/src/tools/navigator_ext.dart';
import 'package:flutter/material.dart';

LifecycleAppOwnerState? _appLifecycleOwner;

set _appOwner(LifecycleAppOwnerState appLifecycleOwner) {
  _appLifecycleOwner = appLifecycleOwner;
  appLifecycleOwner.launchWhenLifecycleEventDestroy(
      block: (_) => _appLifecycleOwner = null);
}

void launchWithAppOwner(
    void Function(LifecycleAppOwnerState appLifecycleOwner) block) {
  if (_appLifecycleOwner != null) {
    block(_appLifecycleOwner!);
    return;
  }

  late final LifecycleOwnerAttachCallback callback;
  callback = (parent, childOwner) {
    if (parent == null && childOwner is LifecycleAppOwnerState) {
      LifecycleCallbacks.instance.removeOwnerAttachCallback(callback);
      block(childOwner);
      _appOwner = childOwner;
    } else if (parent != null) {
      final owner = parent.findLifecycleOwner<LifecycleAppOwnerState>(
          test: (owner) => owner.lifecycle.parent == null);
      if (owner != null) {
        LifecycleCallbacks.instance.removeOwnerAttachCallback(callback);
        block(owner);
        _appOwner = owner;
      } else {
        assert(false, 'WTF ?');
      }
    } else {
      var owner = parent?.findLifecycleOwner<LifecycleAppOwnerState>(
          test: (owner) => owner.lifecycle.parent == null);
      owner ??= childOwner.findLifecycleOwner<LifecycleAppOwnerState>(
          test: (owner) => owner.lifecycle.parent == null);

      if (owner != null) {
        LifecycleCallbacks.instance.removeOwnerAttachCallback(callback);
        block(owner);
        _appOwner = owner;
      } else {
        assert(false, 'WTF ?');
      }
    }
  };

  LifecycleCallbacks.instance.addOwnerAttachCallback(callback);
}

extension CommonLifecycleExt on Lifecycle {
  /// 获取导航器
  NavigatorState get navigator =>
      findLifecycleOwner<LifecycleRouteOwnerState>()!.context.navigator;
}
