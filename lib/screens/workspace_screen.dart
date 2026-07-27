import 'package:flutter/material.dart';
import '../widgets/custom_hub_logo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/reasoning_engine.dart';
import '../core/intent_engine.dart';
import '../tools/tool_router.dart';
import '../workflow/workflow_engine.dart';
import '../ui_engine/generative_ui_renderer.dart';
import '../widgets/ai_command_bar.dart';
import '../widgets/ai_loading_screen.dart';
import '../core/error_handler.dart';
import 'dart:convert';

class WorkspaceScreen extends ConsumerStatefulWidget {
  static final GlobalKey<WorkspaceScreenState> stateKey =
      GlobalKey<WorkspaceScreenState>();
  const WorkspaceScreen({super.key});

  @override
  ConsumerState<WorkspaceScreen> createState() => WorkspaceScreenState();
}

class WorkspaceScreenState extends ConsumerState<WorkspaceScreen>
    with AutomaticKeepAliveClientMixin {
  bool _isLoading = false;
  String? _auilData;
  String? _error;
  String? _attachedFileContext;
  String? _attachedFileName;

  @override
  bool get wantKeepAlive => true;

  final List<Map<String, dynamic>> _allSuggestions = [
    {'icon': Icons.analytics_outlined, 'text': 'Analyze my productivity'},
    {'icon': Icons.flight_takeoff, 'text': 'Plan a trip to Japan'},
    {'icon': Icons.code, 'text': 'Create a coding workspace'},
    {'icon': Icons.summarize, 'text': 'Summarize a document'},
    {'icon': Icons.calculate, 'text': 'Calculate 234 * 89'},
    {'icon': Icons.currency_bitcoin, 'text': 'Show crypto dashboard'},
    {'icon': Icons.edit_note, 'text': 'Write a blog post about AI'},
    {'icon': Icons.fitness_center, 'text': 'Create a workout plan'},
    {'icon': Icons.shopping_basket, 'text': 'Plan my grocery list'},
    {'icon': Icons.auto_stories, 'text': 'Summarize my research'},
  ];

  void handleExternalQuery(String query) {
    _handleIntent(query);
  }

  void _handleIntent(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final workflowEngine = ref.read(workflowEngineProvider);

      // Try workflow engine first (detects complexity and routes to agents)
      final workflowResult = await workflowEngine.execute(
        query,
        fileContext: _attachedFileContext,
      );

      if (workflowResult.usedAgents && workflowResult.auilJson != null) {
        // Complex request handled by agent pipeline
        setState(() {
          _auilData = workflowResult.auilJson;
          _isLoading = false;
          _attachedFileContext = null;
          _attachedFileName = null;
        });
        return;
      }

      // Simple request: use direct reasoning pipeline
      final intentEngine = ref.read(intentEngineProvider);
      final toolRouter = ref.read(toolRouterProvider);
      final reasoningEngine = ref.read(reasoningEngineProvider);

      final intentJsonStr = await intentEngine.analyzeIntent(query);

      List<String> toolsToRun = [];
      try {
        final decoded = jsonDecode(intentJsonStr);
        if (decoded['tools_needed'] != null) {
          toolsToRun = List<String>.from(decoded['tools_needed']);
        }
      } catch (_) {}

      final toolResults = await toolRouter.executeTools(
        toolsToRun,
        intentJsonStr,
      );

      final auilSchema = await reasoningEngine.evaluateAndGenerateAUIL(
        query,
        toolResults,
        fileContext: _attachedFileContext,
      );

      setState(() {
        _auilData = auilSchema;
        _isLoading = false;
        _attachedFileContext = null;
        _attachedFileName = null;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onFileAttached(String fileName, String fileContext) {
    setState(() {
      _attachedFileName = fileName;
      _attachedFileContext = fileContext;
    });
  }

  void _removeAttachment() {
    setState(() {
      _attachedFileName = null;
      _attachedFileContext = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      key: WorkspaceScreen.stateKey,
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Anything',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          if (_attachedFileName != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.blueAccent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.attach_file,
                    color: Colors.blueAccent,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _attachedFileName!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: _removeAttachment,
                    child: const Icon(
                      Icons.close,
                      color: Colors.white38,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildWorkspaceArea()),
          AICommandBar(
            onSubmit: _handleIntent,
            onFileAttached: _onFileAttached,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkspaceArea() {
    if (_isLoading) {
      return const AILoadingScreen();
    }
    if (_error != null) {
      return ErrorHandler.buildErrorWidget(
        _error!,
        onRetry: () => setState(() => _error = null),
      );
    }
    if (_auilData != null) {
      return GenerativeUIRenderer(rawAuilJson: _auilData!);
    }
    return _buildEmptyState();
  }

  Widget _buildEmptyState() {
    // Truly dynamic randomization on every re-render of the empty state
    final shuffled = List<Map<String, dynamic>>.from(_allSuggestions)
      ..shuffle();
    final suggestions = shuffled.take(6).toList();

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CustomHubLogo(size: 80, color: Colors.blueAccent),
            const SizedBox(height: 32),
            const Text(
              'What do you want to do today?',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Type a command, speak, or try one of these:',
              style: TextStyle(color: Colors.white30, fontSize: 14),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: suggestions.map((s) {
                return InkWell(
                  onTap: () => _handleIntent(s['text'] as String),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          s['icon'] as IconData,
                          color: Colors.blueAccent,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          s['text'] as String,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
