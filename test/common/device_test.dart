import 'package:fl_clash/common/device.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('loadDeviceIdentity', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('hwid matches the format Remnawave accepts', () async {
      final identity = await loadDeviceIdentity();

      // Панель валидирует заголовок как /^[a-zA-Z0-9=-]{10,64}$/ — не пройдёт
      // валидацию → подписка отдаётся без учёта устройства.
      expect(RegExp(r'^[a-zA-Z0-9=-]{10,64}$').hasMatch(identity.hwid), isTrue);
    });

    test('hwid is stable across calls', () async {
      final first = await loadDeviceIdentity();
      final second = await loadDeviceIdentity();

      // Иначе каждый апдейт подписки выглядел бы новым устройством.
      expect(second.hwid, first.hwid);
    });

    test('headers carry the device id', () async {
      final identity = await loadDeviceIdentity();

      expect(identity.headers['x-hwid'], identity.hwid);
      expect(identity.headers.containsKey('x-device-os'), isTrue);
    });
  });
}
