import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

import 'common.dart';

extension PackageInfoExtension on PackageInfo {
  // The FIRST token must be a recognised clash-meta client name: Marzban (and
  // most sub backends) pick the clash-meta config format by the leading UA
  // token. A 'RadarShield/...' lead is unknown to them → they return a base64
  // vless list, which our clash core can't parse ("yaml: unmarshal errors").
  // So lead with 'clash-meta', keep the brand/version as later tokens.
  String get ua => [
        'clash-meta/v$version',
        '$appName/v$version',
        'clash-verge',
        'Platform/${Platform.operatingSystem}',
      ].join(' ');
}
