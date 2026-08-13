import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/encryption_manager.dart';
import '../widgets/analogue_clock_picker.dart';

class KaalkaSecurityScreen extends ConsumerStatefulWidget {
  const KaalkaSecurityScreen({super.key});

  @override
  ConsumerState<KaalkaSecurityScreen> createState() =>
      _KaalkaSecurityScreenState();
}

class _KaalkaSecurityScreenState extends ConsumerState<KaalkaSecurityScreen> {
  bool _enableEncryption = true;
  bool _useLiveTime = false;
  int _hours = 0;
  int _minutes = 5;
  int _seconds = 30;

  void _saveSettings() {
    final manager = ref.read(encryptionManagerProvider);
    manager.configureTimeSeed(
      hours: _hours,
      minutes: _minutes,
      seconds: _seconds,
      useLiveTime: _useLiveTime,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(showCloseIcon: true, 
        content: Text('Kaalka security settings saved.'),
        backgroundColor: Colors.blueAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String timeStr =
        '${_hours.toString().padLeft(2, '0')}:${_minutes.toString().padLeft(2, '0')}:${_seconds.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Kaalka Security',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Kaalka Time-Key Security',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Time-derived encryption keys',
              style: TextStyle(fontSize: 16, color: Colors.white54),
            ),
            const SizedBox(height: 32),

            // Toggle cards
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text(
                      'Enable time-key encryption',
                      style: TextStyle(color: Colors.white),
                    ),
                    value: _enableEncryption,
                    onChanged: (val) => setState(() => _enableEncryption = val),
                    activeThumbColor: Colors.blueAccent,
                  ),
                  const Divider(color: Colors.white24),
                  SwitchListTile(
                    title: const Text(
                      'Use live system time',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'Seed = current time, continuously varying.',
                      style: TextStyle(color: Colors.white54),
                    ),
                    value: _useLiveTime,
                    onChanged: _enableEncryption
                        ? (val) => setState(() => _useLiveTime = val)
                        : null,
                    activeThumbColor: Colors.blueAccent,
                  ),
                ],
              ),
            ),

            // Clock picker (only when not using live time)
            if (!_useLiveTime && _enableEncryption) ...[
              const SizedBox(height: 32),
              const Center(
                child: Text(
                  'Key Seed Time',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Drag clock hands to set the encryption key seed.',
                  style: TextStyle(fontSize: 13, color: Colors.white38),
                ),
              ),
              const SizedBox(height: 24),

              // Analog clock
              Center(
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: AnalogueClockPicker(
                    hours: _hours,
                    minutes: _minutes,
                    seconds: _seconds,
                    onTimeChanged: (time) {
                      setState(() {
                        _hours = time.hours;
                        _minutes = time.minutes;
                        _seconds = time.seconds;
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Kaalka key seed: $timeStr',
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Save Security Settings',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
