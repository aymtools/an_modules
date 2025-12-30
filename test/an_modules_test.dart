import 'package:an_modules/an_modules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tt', () {
    // App 容器（root）
    final app = Module.app;

    app.register(Module(name: 'network'));
    Module.registerModule(
      module: Module(name: 'logger'),
    );

    Module.registerModule(
      containerId: 'feature',
      module: Module(
        name: 'auth',
        requiredDependencies: ['network'],
      ),
    );

    Module.registerModule(
      containerId: 'feature',
      module: Module(
        name: 'analytics',
        optionalDependencies: ['network'],
      ),
    );

    Module.registerModule(
      containerId: 'feature',
      module: Module(
        name: 'user',
        requiredDependencies: ['auth'],
        optionalDependencies: ['analytics'],
      ),
    );
    app.generateRouters;
    expect(app.hasModule('logger'), isTrue);
  });
}
