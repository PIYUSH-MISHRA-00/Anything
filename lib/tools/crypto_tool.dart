import 'tool_registry.dart';

class CryptoTool extends BaseTool {
  @override
  String get name => 'crypto_tool';

  @override
  Future<dynamic> execute(String contextPayload) async {
    // Stub: In production, integrate with a real crypto API (CoinGecko, etc.)
    return {
      'bitcoin': {
        'price': '\$67,234.50',
        'change_24h': '+2.3%',
        'market_cap': '\$1.32T',
      },
      'ethereum': {
        'price': '\$3,521.80',
        'change_24h': '+1.8%',
        'market_cap': '\$423B',
      },
      'source': 'mock_data',
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
}
