import 'package:flutter/material.dart';
import '../ui_engine/generative_ui_renderer.dart';

/// A styled container for rendered workspaces.
class WorkspaceContainer extends StatelessWidget {
  final String title;
  final String auilJson;

  const WorkspaceContainer({
    super.key,
    required this.title,
    required this.auilJson,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.dashboard, color: Colors.blueAccent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.fullscreen, color: Colors.white38, size: 20),
                onPressed: () {},
                tooltip: 'Expand',
              ),
            ],
          ),
        ),
        // Content
        Expanded(
          child: GenerativeUIRenderer(rawAuilJson: auilJson),
        ),
      ],
    );
  }
}
