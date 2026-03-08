import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaalka/kaalka.dart';

final kaalkaServiceProvider = Provider<KaalkaService>((ref) {
  return KaalkaService();
});

class KaalkaService {

  /// Generates a seed string from time
  String generateSeed(int hours, int minutes, int seconds) {
    return '${hours.toString().padLeft(2, '0')}:'
           '${minutes.toString().padLeft(2, '0')}:'
           '${seconds.toString().padLeft(2, '0')}';
  }

  /// Generates seed from current system time
  String generateLiveSeed() {
    final now = DateTime.now();
    return generateSeed(now.hour, now.minute, now.second);
  }

  /// Creates a Kaalka encryption instance
  Kaalka createCipher() {
    return Kaalka();
  }

}