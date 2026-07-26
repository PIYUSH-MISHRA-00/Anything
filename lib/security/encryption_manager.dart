import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'kaalka_service.dart';

final encryptionManagerProvider = Provider<EncryptionManager>((ref) {
  final kaalkaService = ref.watch(kaalkaServiceProvider);
  return EncryptionManager(kaalkaService);
});

class EncryptionManager {
  final KaalkaService _kaalkaService;

  int _seedHours = 0;
  int _seedMinutes = 0;
  int _seedSeconds = 0;
  bool _useLiveTime = false;

  EncryptionManager(this._kaalkaService);

  void configureTimeSeed({
    required int hours,
    required int minutes,
    required int seconds,
    bool useLiveTime = false,
  }) {
    _seedHours = hours;
    _seedMinutes = minutes;
    _seedSeconds = seconds;
    _useLiveTime = useLiveTime;
  }

  String _currentSeed() {
    if (_useLiveTime) {
      return _kaalkaService.generateLiveSeed();
    }
    return _kaalkaService.generateSeed(_seedHours, _seedMinutes, _seedSeconds);
  }

  Future<String> encryptData(String plainText) async {
    final seed = _currentSeed();
    return await _kaalkaService.encryptText(plainText, timeKey: seed);
  }

  Future<String> decryptData(String cipherText) async {
    final seed = _currentSeed();
    return await _kaalkaService.decryptText(cipherText, timeKey: seed);
  }
}
