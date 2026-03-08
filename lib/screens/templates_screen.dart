import 'package:flutter/material.dart';
import 'app_shell.dart';
import 'workspace_screen.dart';

class TemplatesScreen extends StatelessWidget {
  const TemplatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Templates', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Start with a template',
              style: TextStyle(color: Colors.white54, fontSize: 15),
            ),
            const SizedBox(height: 24),
            _buildCategory(context, 'Productivity', [
              _TemplateItem(Icons.rocket_launch, 'Startup Planner', 'Business plan, pitch deck, market analysis', Colors.blueAccent),
              _TemplateItem(Icons.school, 'Study Dashboard', 'Notes, flashcards, progress tracking', Colors.purpleAccent),
              _TemplateItem(Icons.task_alt, 'Project Manager', 'Kanban boards, timelines, team tasks', Colors.tealAccent),
            ]),
            const SizedBox(height: 24),
            _buildCategory(context, 'Finance', [
              _TemplateItem(Icons.currency_bitcoin, 'Crypto Tracker', 'Live prices, portfolio, alerts', Colors.orangeAccent),
              _TemplateItem(Icons.account_balance, 'Budget Planner', 'Income, expenses, savings goals', Colors.greenAccent),
            ]),
            const SizedBox(height: 24),
            _buildCategory(context, 'Health & Lifestyle', [
              _TemplateItem(Icons.fitness_center, 'Fitness Tracker', 'Workouts, nutrition, progress', Colors.redAccent),
              _TemplateItem(Icons.flight, 'Travel Planner', 'Itineraries, budget, packing list', Colors.cyanAccent),
            ]),
            const SizedBox(height: 24),
            _buildCategory(context, 'Creative', [
              _TemplateItem(Icons.edit_note, 'Content Calendar', 'Social media, blog posts, scheduling', Colors.pinkAccent),
              _TemplateItem(Icons.auto_stories, 'Research Assistant', 'Sources, notes, citations', Colors.indigoAccent),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildCategory(BuildContext context, String title, List<_TemplateItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ...items.map((item) => _buildTemplateCard(context, item)),
      ],
    );
  }

  void _useTemplate(BuildContext context, _TemplateItem item) {
    // Switch to Home tab
    AppShell.stateKey.currentState?.setIndex(0);
    // Trigger intent in WorkspaceScreen
    WorkspaceScreen.stateKey.currentState?.handleExternalQuery('Create a ${item.title}');
  }

  Widget _buildTemplateCard(BuildContext context, _TemplateItem item) {
    return InkWell(
      onTap: () => _useTemplate(context, item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
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
                color: item.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  Text(item.description, style: const TextStyle(color: Colors.white38, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }
}

class _TemplateItem {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  const _TemplateItem(this.icon, this.title, this.description, this.color);
}
