import 'dart:io';
import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';

import 'common.dart';

/// Идентификатор устройства для учёта числа устройств на одну подписку.
///
/// Шлётся в заголовке `x-hwid` при загрузке подписки (см. [Request]) — их
/// читает и наш лендинг-прокси, и HWID-лимит Remnawave, если его включат.
///
/// Это НЕ отпечаток железа: Android/iOS не отдают стабильный аппаратный id без
/// привилегий, а собирать его по крупицам — и хрупко, и лишние данные. Вместо
/// этого — случайный uuid, созданный один раз и сохранённый в prefs: он
/// переживает обновление приложения (нам этого достаточно) и сбрасывается при
/// переустановке/очистке данных. То есть считает установки, а не корпуса.
class DeviceIdentity {
  final String hwid;
  final String os;
  final String osVersion;
  final String model;

  const DeviceIdentity({
    required this.hwid,
    required this.os,
    required this.osVersion,
    required this.model,
  });

  /// Заголовки в том виде, в каком их ждёт Remnawave (и логирует наш лендинг).
  Map<String, String> get headers => {
        'x-hwid': hwid,
        'x-device-os': os,
        'x-ver-os': osVersion,
        'x-device-model': model,
      };
}

/// uuid v4 из криптостойкого источника — отдельного пакета ради этого не тянем.
String _generateHwid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // версия 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // вариант RFC 4122
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

Future<DeviceIdentity> loadDeviceIdentity() async {
  var hwid = await preferences.getHwid();
  if (hwid == null || hwid.isEmpty) {
    hwid = _generateHwid();
    await preferences.setHwid(hwid);
  }

  var osVersion = '';
  var model = '';
  try {
    final info = DeviceInfoPlugin();
    if (Platform.isAndroid) {
      final android = await info.androidInfo;
      osVersion = android.version.release;
      model = '${android.manufacturer} ${android.model}'.trim();
    } else if (Platform.isIOS) {
      final ios = await info.iosInfo;
      osVersion = ios.systemVersion;
      model = ios.utsname.machine;
    } else if (Platform.isWindows) {
      final windows = await info.windowsInfo;
      osVersion = windows.displayVersion;
      model = windows.productName;
    } else if (Platform.isMacOS) {
      final macos = await info.macOsInfo;
      osVersion = macos.osRelease;
      model = macos.model;
    } else if (Platform.isLinux) {
      final linux = await info.linuxInfo;
      osVersion = linux.versionId ?? '';
      model = linux.prettyName;
    }
  } catch (e) {
    // Модель/версия — необязательная телеметрия для панели; учёт устройств
    // держится на hwid, поэтому падать здесь нельзя.
    commonPrint.log('loadDeviceIdentity error ${e.toString()}');
  }

  return DeviceIdentity(
    hwid: hwid,
    os: Platform.operatingSystem,
    osVersion: osVersion,
    model: model,
  );
}
