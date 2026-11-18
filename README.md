# an_modules

[![pub package](https://img.shields.io/pub/v/an_modules.svg)](https://pub.dev/packages/an_modules)

A toolkit for Flutter designed for business-functionality-oriented modularization. It provides modular registration, automatic dependency resolution, asynchronous initialization, and unified routing management.

> 💡 **Recommendation:**
> - It is recommended to use [`an_modules_common`](https://pub.dev/packages/an_modules_common) for common modular utilities and base components.
> - You can also quickly generate modular code using [Mason](https://pub.dev/packages/mason_cli) with the `an_modules` brick/template.

---

## ✨ Features

- **📦 Module Declaration & Registration**: Define pages, routes, initializers, and dependencies declaratively using `Module`.
- **🔀 Dependency Resolution & Cycle Detection**: Automatically resolves required dependencies (`requiredDependencies`) and optional dependencies (`optionalDependencies`) via topological sorting with built-in circular dependency detection.
- **🚀 Asynchronous Module Initialization**: Execute async tasks sequentially or in parallel based on the dependency graph (`initializerExecutor`), complete with customizable error retry and UI fallback mechanisms (`initializerErrorBuilder`).
- **🗺️ Unified Route Management**: Seamlessly integrates with `MaterialApp.onGenerateRoute`, supporting module-scoped page wrappers (`pageWrapper`), custom `PageRoute` builders (`routes`), and global route parsers (`routeParser`).
- **🖼️ Module Asset Isolation**: Automatically scopes asset bundles for each module (`packages/packageName/assets`), eliminating the need to manually append package prefixes in asset paths.
- **🏛️ Multi-Container Architecture**: Supports hierarchical isolation and management of modules using `ModuleContainer` (e.g., primary App container and sub-containers).

---

## 📦 Installation

Add `an_modules` to your `pubspec.yaml`:

```yaml
dependencies:
  an_modules: ^1.3.2
```

Then run:

```bash
flutter pub get
```

---

## 🚀 Quick Start

### 1. Define and Register Modules

Define a `Module` within your feature module:

```dart
import 'package:an_modules/an_modules.dart';
import 'package:flutter/material.dart';

void registerUserModule() {
  Module.registerModule(
    module: Module(
      name: 'user_module',
      requiredDependencies: ['common_module'], // Explicit dependencies
      pages: {
        '/user/profile': (arguments) => const UserProfilePage(),
        '/user/settings': (arguments) => const UserSettingsPage(),
      },
      // Asynchronous module initialization logic
      initializerExecutor: (attempt) async {
        // Perform async setup (e.g., SDK initialization, local storage warming)
        await UserSDK.init();
      },
      // Error handler and retry UI callback
      initializerErrorBuilder: (context, error, attempt, controller) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('User module failed to initialize: $error'),
                ElevatedButton(
                  onPressed: () => controller.retry(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
```

### 2. Integrate with `MaterialApp`

Delegate route generation and initialization to `an_modules` in `MaterialApp`:

```dart
import 'package:an_modules/an_modules.dart';
import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Register all business modules
  registerCommonModule();
  registerUserModule();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'an_modules Demo',
      initialRoute: '/',
      // 1. Delegate route generation to an_modules
      onGenerateRoute: Module.app.generateRouteFactory,
      // 2. Wrap app with AppInitializer for automatic module initialization
      builder: AppInitializer.builder(
        initializing: const AppInitializingPage(),
      ),
    );
  }
}

class AppInitializingPage extends StatelessWidget {
  const AppInitializingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
```

---

## 🛠️ Core Concepts

### 1. Module Dependencies & Topological Execution

- **`requiredDependencies`**: Mandatory module dependencies. If a required module is missing at initialization, a `StateError` will be thrown.
- **`optionalDependencies`**: Optional dependencies. If the optional module is registered, `an_modules` guarantees it will finish initializing before the dependent module starts.
- **Topological Order**: `an_modules` builds a directed acyclic graph (DAG) of registered modules and sorts initialization tasks accordingly.

### 2. Pages, Routes & Page Wrapper

- **`pages`**: Maps route names to `MPageBuilder` (`Widget Function(Object? arguments)`).
- **`pageWrapper`**: Wraps every page inside the module with a specified Widget (useful for injecting ViewModels, Providers, or Theme overrides).
- **`routes`**: Allows registering custom `PageRoute` instances (e.g., custom transitions) via `MPageRouteBuilder`.
- **`routeParser`**: Provides global route parsing and interception per module.

> ⚠️ **Important Note:**
> If you are using the `material_ui` package (or require custom Material route transitions without importing `package:flutter/material.dart` directly in `an_modules`), you must explicitly specify `ModuleContainer.pageRouteGenerator` (e.g., `Module.app.pageRouteGenerator = (settings, content) => MaterialPageRoute(settings: settings, builder: (_) => content);`).

### 3. Module Extension Configurations (`otherConfigs`)

Modules can declare custom metadata or configs upon instantiation:

```dart
Module(
  name: 'order_module',
  otherConfigs: {
    'tab_index': 2,
    'tab_icon': Icons.shopping_cart,
  },
  pages: { ... },
);
```

Retrieve registered module configurations globally across the app container:

```dart
final configs = Module.app.getAllModulesOtherConfigByKey<int>('tab_index');
```

---

## 🔗 Related Ecosystem

- [an_modules_common](https://pub.dev/packages/an_modules_common) - Recommended common utilities and base configurations for `an_modules`.
- [Mason](https://pub.dev/packages/mason_cli) - Code generator for quickly scaffolding `an_modules` template bricks.
- [anlifecycle](https://pub.dev/packages/anlifecycle) - Lifecycle awareness and management for Flutter.
- [cancellable](https://pub.dev/packages/cancellable) - Cancellable async operation management.
- [an_lifecycle_cancellable](https://pub.dev/packages/an_lifecycle_cancellable) - Automatic cancellation bound to lifecycle states.
- [an_viewmodel](https://pub.dev/packages/an_viewmodel) - Lifecycle-aware ViewModel state management.
