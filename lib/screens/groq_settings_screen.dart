import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/groq_service.dart';

class GroqSettingsScreen extends ConsumerStatefulWidget {
  const GroqSettingsScreen({super.key});

  @override
  ConsumerState<GroqSettingsScreen> createState() => _GroqSettingsScreenState();
}

class _GroqSettingsScreenState extends ConsumerState<GroqSettingsScreen> {
  final TextEditingController _keyController = TextEditingController();
  bool _isTesting = false;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final groq = ref.read(groqServiceProvider);
    final key = await groq.getApiKey();
    if (key != null) {
      _keyController.text = key;
    }
  }

  Future<void> _testKey() async {
    setState(() {
      _isTesting = true;
      _testResult = null;
    });

    final groq = ref.read(groqServiceProvider);
    final key = _keyController.text.trim();
    if (key.isEmpty) {
      setState(() {
        _isTesting = false;
        _testResult = 'Please enter an API Key first.';
      });
      return;
    }

    final success = await groq.testApiKey(key);
    if (success) {
      await groq.saveApiKey(key);
      setState(() {
        _testResult = 'Success! Key saved.';
      });
    } else {
      setState(() {
        _testResult = 'Failed to authenticate. Check the key and try again.';
      });
    }

    setState(() {
      _isTesting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Groq AI Configuration', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To use the "Anything" app, you need a free Groq API key.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 24),
            _buildInstructionStep('Step 1', 'Visit https://console.groq.com'),
            _buildInstructionStep('Step 2', 'Create an account or log in.'),
            _buildInstructionStep('Step 3', 'Navigate to API Keys.'),
            _buildInstructionStep('Step 4', 'Generate a new API key.'),
            _buildInstructionStep('Step 5', 'Paste the key into the field below.'),
            const SizedBox(height: 32),
            TextField(
              controller: _keyController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Groq API Key',
                labelStyle: const TextStyle(color: Colors.white54),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.white24),
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.blueAccent),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isTesting ? null : _testKey,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: _isTesting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Test & Save API Key', style: TextStyle(fontSize: 16)),
              ),
            ),
            if (_testResult != null) ...[
              const SizedBox(height: 16),
              Center(
                child: Text(
                  _testResult!,
                  style: TextStyle(
                    color: _testResult!.startsWith('Success') ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 16,
                  ),
                ),
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String step, String instruction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$step: ',
            style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Text(
              instruction,
              style: const TextStyle(color: Colors.white70),
            ),
          )
        ],
      ),
    );
  }
}
