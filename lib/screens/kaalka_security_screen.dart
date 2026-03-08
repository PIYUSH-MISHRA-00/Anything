import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../security/encryption_manager.dart';

class KaalkaSecurityScreen extends ConsumerStatefulWidget {
  const KaalkaSecurityScreen({super.key});

  @override
  ConsumerState<KaalkaSecurityScreen> createState() => _KaalkaSecurityScreenState();
}

class _KaalkaSecurityScreenState extends ConsumerState<KaalkaSecurityScreen> {
  bool _enableEncryption = true;
  bool _useLiveTime = false;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 0, minute: 5);
  int _selectedSeconds = 30;

  void _saveSettings() {
    final manager = ref.read(encryptionManagerProvider);
    manager.configureTimeSeed(
      hours: _selectedTime.hour, 
      minutes: _selectedTime.minute, 
      seconds: _selectedSeconds,
      useLiveTime: _useLiveTime,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Kaalka security settings saved.'), backgroundColor: Colors.blueAccent),
    );
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              surface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() {
        _selectedTime = time;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String timeStr = '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}:${_selectedSeconds.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Kaalka Security', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Kaalka Time-Key Security', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 8),
            const Text('Time-derived encryption keys', style: TextStyle(fontSize: 16, color: Colors.white54)),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Enable time-key encryption', style: TextStyle(color: Colors.white)),
                    value: _enableEncryption,
                    onChanged: (val) => setState(() => _enableEncryption = val),
                    activeThumbColor: Colors.blueAccent,
                  ),
                  const Divider(color: Colors.white24),
                  SwitchListTile(
                    title: const Text('Use live system time', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Generates continuously varying encryption keys.', style: TextStyle(color: Colors.white54)),
                    value: _useLiveTime,
                    onChanged: _enableEncryption ? (val) => setState(() => _useLiveTime = val) : null,
                    activeThumbColor: Colors.blueAccent,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (!_useLiveTime && _enableEncryption) ...[
              const Center(child: Text('Key Seed Time', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
              const SizedBox(height: 24),
              Center(
                child: GestureDetector(
                  onTap: _pickTime,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.5), width: 2),
                      boxShadow: [
                        BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 5),
                      ],
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.access_time, size: 40, color: Colors.blueAccent),
                          const SizedBox(height: 12),
                          Text(
                            '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Seconds:', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  Slider(
                    value: _selectedSeconds.toDouble(),
                    min: 0,
                    max: 59,
                    divisions: 59,
                    label: _selectedSeconds.toString(),
                    activeColor: Colors.blueAccent,
                    onChanged: (val) => setState(() => _selectedSeconds = val.toInt()),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Kaalka key seed: $timeStr',
                    style: const TextStyle(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: const Text('Save Security Settings', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
