/// Kaalka adapter — wraps published `package:kaalka` behind ProtectionProvider.
///
/// Architecture:
///   Anything domain → ProtectionProvider → KaalkaProtectionProvider → package:kaalka → Kaalka
///
/// Only this adapter should import `package:kaalka/...`.
library;

import '../core/contracts/protection_provider.dart';
import '../security/kaalka_service.dart';

/// Kaalka implementation of the [ProtectionProvider] contract.
///
/// Wraps the published Kaalka package behind the provider abstraction
/// so that business logic never depends on Kaalka-specific types.
class KaalkaProtectionProvider implements ProtectionProvider {
  final KaalkaService _kaalkaService;
  ProtectionConfig _config;

  KaalkaProtectionProvider({
    KaalkaService? kaalkaService,
    ProtectionConfig? config,
  }) : _kaalkaService = kaalkaService ?? KaalkaService(),
       _config = config ?? const ProtectionConfig();

  @override
  String get providerId => 'kaalka';

  @override
  bool get isEnabled => _config.enabled;

  @override
  ProtectionConfig get config => _config;

  @override
  Future<void> updateConfig(ProtectionConfig config) async {
    _config = config;
  }

  @override
  Future<String> encrypt(String plainText) async {
    final seed = getCurrentSeed();
    return await _kaalkaService.encryptText(
      plainText,
      timeKey: seed.toSeedString(),
    );
  }

  @override
  Future<String> decrypt(String cipherText) async {
    final seed = getCurrentSeed();
    return await _kaalkaService.decryptText(
      cipherText,
      timeKey: seed.toSeedString(),
    );
  }

  @override
  String generateSeed(int hours, int minutes, int seconds) {
    return _kaalkaService.generateSeed(hours, minutes, seconds);
  }

  @override
  String generateLiveSeed() {
    return _kaalkaService.generateLiveSeed();
  }

  @override
  TimeSeed getCurrentSeed() {
    if (_config.timeSeedMode == TimeSeedMode.live) {
      return TimeSeed.now();
    }
    return _config.customTimeSeed ?? TimeSeed.now();
  }
}
