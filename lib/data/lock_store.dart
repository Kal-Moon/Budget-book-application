import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// 잠금 정보를 넣어 두는 보안 저장소. 테스트에서는 메모리 저장소로 바꿔 끼운다.
abstract class SecretStore {
  Future<Map<String, String>> readAll();
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

class _DeviceSecretStore implements SecretStore {
  static const _storage = FlutterSecureStorage();

  @override
  Future<Map<String, String>> readAll() => _storage.readAll();

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

final secretStoreProvider = Provider<SecretStore>(
  (ref) => _DeviceSecretStore(),
);

/// 지문·얼굴 인식. 인식 자체는 휴대폰이 하고, 앱은 성공/실패만 받는다.
abstract class BiometricAuth {
  /// 이 기기에서 쓸 수 있는지(센서가 있고 등록돼 있는지).
  Future<bool> isAvailable();

  /// 인식 창을 띄운다. 성공하면 true, 취소·실패·오류는 false.
  Future<bool> authenticate(String reason);
}

class _DeviceBiometricAuth implements BiometricAuth {
  final _auth = LocalAuthentication();

  @override
  Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException {
      return false;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (_) {
      // 취소, 여러 번 실패해 잠김, 센서 없음 등은 모두 "실패"로 본다(PIN으로 넘어간다).
      return false;
    }
  }
}

final biometricAuthProvider = Provider<BiometricAuth>(
  (ref) => _DeviceBiometricAuth(),
);
