import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../memory/memory_manager.dart';

class MemoryDashboardScreen extends ConsumerStatefulWidget {
  const MemoryDashboardScreen({super.key});

  @override
  ConsumerState<MemoryDashboardScreen> createState() =>
      _MemoryDashboardScreenState();
}

class _MemoryDashboardScreenState extends ConsumerState<MemoryDashboardScreen> {
  List<Map<String, dynamic>> _memories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMemory();
  }

  Future<void> _loadMemory() async {
    final manager = ref.read(memoryManagerProvider);
    final data = await manager.getConversations();
    setState(() {
      _memories = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Memory Dashboard',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : _memories.isEmpty
          ? const Center(
              child: Text(
                'No memories stored yet.',
                style: TextStyle(color: Colors.white54),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _memories.length,
              itemBuilder: (itemContext, index) {
                final item = _memories[index];
                final date = DateTime.fromMillisecondsSinceEpoch(
                  item['timestamp'] as int,
                );
                return Card(
                  color: Colors.white.withValues(alpha: 0.05),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    title: Text(
                      item['content'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      '${date.year}-${date.month}-${date.day} ${date.hour}:${date.minute}',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () async {
                        final success = await showDialog<bool>(
                          context: itemContext,
                          builder: (dialogContext) => AlertDialog(
                            backgroundColor: const Color(0xFF1E293B),
                            title: const Text(
                              'Delete Memory',
                              style: TextStyle(color: Colors.white),
                            ),
                            content: const Text(
                              'Are you sure you want to delete this memory?',
                              style: TextStyle(color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, false),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.pop(dialogContext, true),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.redAccent),
                                ),
                              ),
                            ],
                          ),
                        );

                        if (success != true) return;
                        if (!mounted) return;
                        final manager = ref.read(memoryManagerProvider);
                        await manager.deleteConversation(item['id'] as int);
                        if (!mounted) return;
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(showCloseIcon: true, 
                            content: Text('Memory deleted'),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}
