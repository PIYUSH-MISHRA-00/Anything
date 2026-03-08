import 'package:flutter/material.dart';
import 'groq_settings_screen.dart';
import 'kaalka_security_screen.dart';
import 'personal_context_screen.dart';
import 'skills_marketplace_screen.dart';

class AISettingsScreen extends StatelessWidget {
  const AISettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingsCard(
            context,
            title: 'Groq AI Configuration',
            subtitle: 'Manage API keys and AI models',
            icon: Icons.memory,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GroqSettingsScreen())),
          ),
          const SizedBox(height: 12),
          _buildSettingsCard(
            context,
            title: 'Kaalka Security',
            subtitle: 'Time-derived encryption keys',
            icon: Icons.security,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KaalkaSecurityScreen())),
          ),
          // Additional mock settings
          const SizedBox(height: 12),
          _buildSettingsCard(
            context,
            title: 'Personal Context',
            subtitle: 'Manage what the AI learns about you',
            icon: Icons.person_outline,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PersonalContextScreen())),
          ),
          const SizedBox(height: 12),
          _buildSettingsCard(
            context,
            title: 'Skills Marketplace',
            subtitle: 'Discover and install AI skills',
            icon: Icons.extension_outlined,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SkillsMarketplaceScreen())),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return Card(
      color: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blueAccent.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.blueAccent),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
        onTap: onTap,
      ),
    );
  }
}
