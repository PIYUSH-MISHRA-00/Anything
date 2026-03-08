import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/reasoning_engine.dart';
import '../core/intent_engine.dart';
import '../tools/tool_router.dart';
import '../ui_engine/generative_ui_renderer.dart';
import '../widgets/ai_command_bar.dart';
import '../widgets/ai_loading_screen.dart';
import 'dart:convert'; // Added for jsonDecode

class WorkspaceScreen extends ConsumerStatefulWidget {
  const WorkspaceScreen({super.key});

  @override
  ConsumerState<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends ConsumerState<WorkspaceScreen> {
  bool _isLoading = false;
  String? _auilData;
  String? _error;

  void _handleIntent(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final intentEngine = ref.read(intentEngineProvider);
      final toolRouter = ref.read(toolRouterProvider);
      final reasoningEngine = ref.read(reasoningEngineProvider);

      // Phase 1: Intent Analysis
      final intentJsonStr = await intentEngine.analyzeIntent(query);
      
      // Attempt generic extraction of tools out of the intent json
      // In production, robust JSON bounds checking is essential
      List<String> toolsToRun = [];
      try {
          final decoded = jsonDecode(intentJsonStr);
          if (decoded['tools_needed'] != null) {
              toolsToRun = List<String>.from(decoded['tools_needed']);
          }
      } catch (e) {
          // Fallback if the AI fails to deliver strict JSON
      }

      // Phase 2: Tool Execution
      final toolResults = await toolRouter.executeTools(toolsToRun, intentJsonStr);

      // Phase 3: Reasoning & AUIL Generation
      final auilSchema = await reasoningEngine.evaluateAndGenerateAUIL(query, toolResults);

      setState(() {
        _auilData = auilSchema;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('What do you want to do today?', style: TextStyle(color: Colors.white70, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildWorkspaceArea(),
          ),
          AICommandBar(
            onSubmit: _handleIntent,
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              const SizedBox(height: 16),
              Text(
                'Workflow Failed:\n$_error',
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    if (_auilData != null) {
      return GenerativeUIRenderer(rawAuilJson: _auilData!);
    }
    return const Center(
      child: Text(
        'Empty Workspace',
        style: TextStyle(color: Colors.white30, fontSize: 18),
      ),
    );
  }
}
