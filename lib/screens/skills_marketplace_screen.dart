import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../memory/memory_manager.dart';

class SkillsMarketplaceScreen extends ConsumerStatefulWidget {
  const SkillsMarketplaceScreen({super.key});

  @override
  ConsumerState<SkillsMarketplaceScreen> createState() =>
      _SkillsMarketplaceScreenState();
}

class _SkillsMarketplaceScreenState
    extends ConsumerState<SkillsMarketplaceScreen> {
  final List<String> _installedSkills = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInstalledSkills();
  }

  Future<void> _loadInstalledSkills() async {
    final manager = ref.read(memoryManagerProvider);
    final installedStr = await manager.getPreference('installed_skills') ?? '';
    setState(() {
      _installedSkills.addAll(
        installedStr.split(',').where((s) => s.isNotEmpty),
      );
      _isLoading = false;
    });
  }

  Future<void> _toggleSkill(String skillName) async {
    final manager = ref.read(memoryManagerProvider);
    setState(() {
      if (_installedSkills.contains(skillName)) {
        _installedSkills.remove(skillName);
      } else {
        _installedSkills.add(skillName);
      }
    });
    await manager.savePreference(
      'installed_skills',
      _installedSkills.join(','),
    );
  }

  @override
  Widget build(BuildContext context) {
    final skills = [
      _Skill(
        'Coding Assistant',
        'AI-powered code generation and debugging',
        Icons.code,
        Colors.blueAccent,
      ),
      _Skill(
        'Travel Planner',
        'Trip planning, itineraries, and budgeting',
        Icons.flight,
        Colors.cyanAccent,
      ),
      _Skill(
        'Finance Advisor',
        'Investment analysis and portfolio tracking',
        Icons.account_balance,
        Colors.greenAccent,
      ),
      _Skill(
        'Writing Coach',
        'Grammar, style, and content improvement',
        Icons.edit,
        Colors.purpleAccent,
      ),
      _Skill(
        'Data Analyst',
        'CSV analysis, chart generation, insights',
        Icons.analytics,
        Colors.orangeAccent,
      ),
      _Skill(
        'Health Tracker',
        'Fitness, nutrition, and wellness monitoring',
        Icons.favorite,
        Colors.redAccent,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Skills',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enhance your AI with specialized skills',
                    style: TextStyle(color: Colors.white54, fontSize: 15),
                  ),
                  const SizedBox(height: 24),
                  ...skills.map((skill) => _buildSkillCard(skill)),
                ],
              ),
            ),
    );
  }

  Widget _buildSkillCard(_Skill skill) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: skill.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(skill.icon, color: skill.color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  skill.description,
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: () => _toggleSkill(skill.name),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _installedSkills.contains(skill.name)
                    ? Colors.greenAccent.withValues(alpha: 0.15)
                    : Colors.blueAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _installedSkills.contains(skill.name) ? 'Installed' : 'Install',
                style: TextStyle(
                  color: _installedSkills.contains(skill.name)
                      ? Colors.greenAccent
                      : Colors.blueAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Skill {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  const _Skill(this.name, this.description, this.icon, this.color);
}
