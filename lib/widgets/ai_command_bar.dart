import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/voice_service.dart';
import '../services/file_context_service.dart';

class AICommandBar extends ConsumerStatefulWidget {
  final Function(String) onSubmit;
  final Function(String fileName, String fileContext)? onFileAttached;

  const AICommandBar({super.key, required this.onSubmit, this.onFileAttached});

  @override
  ConsumerState<AICommandBar> createState() => _AICommandBarState();
}

class _AICommandBarState extends ConsumerState<AICommandBar>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  bool _isRecording = false;
  bool _isTranscribing = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_controller.text.trim().isNotEmpty) {
      widget.onSubmit(_controller.text.trim());
      _controller.clear();
    }
  }

  Future<void> _toggleRecording() async {
    final voiceService = ref.read(voiceServiceProvider);

    if (_isRecording) {
      // Stop recording and transcribe
      setState(() {
        _isRecording = false;
        _isTranscribing = true;
      });
      try {
        final transcription = await voiceService.stopAndTranscribe();
        if (transcription.isNotEmpty) {
          _controller.text = transcription;
          _controller.selection = TextSelection.fromPosition(
            TextPosition(offset: _controller.text.length),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
      setState(() => _isTranscribing = false);
    } else {
      // Start recording
      try {
        await voiceService.startRecording();
        setState(() => _isRecording = true);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString().replaceAll('Exception: ', '')),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _cancelRecording() async {
    final voiceService = ref.read(voiceServiceProvider);
    await voiceService.cancelRecording();
    setState(() => _isRecording = false);
  }

  Future<void> _pickFile() async {
    try {
      final fileService = ref.read(fileContextServiceProvider);
      final result = await fileService.pickAndProcessFile();
      if (result != null && widget.onFileAttached != null) {
        widget.onFileAttached!(result.name, result.context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: SafeArea(
        child: _isRecording ? _buildRecordingBar() : _buildInputBar(),
      ),
    );
  }

  Widget _buildRecordingBar() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.close, color: Colors.redAccent),
          tooltip: 'Cancel',
          onPressed: _cancelRecording,
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              const Text(
                'Listening...',
                style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 32),
          tooltip: 'Done',
          onPressed: _toggleRecording,
        ),
      ],
    );
  }

  Widget _buildInputBar() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.attach_file, color: Colors.white38),
          tooltip: 'Attach file',
          onPressed: _pickFile,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TextField(
              controller: _controller,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Ask Anything...',
                hintStyle: TextStyle(color: Colors.white30),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _submit(),
            ),
          ),
        ),
        const SizedBox(width: 4),
        _isTranscribing
            ? const Padding(
                padding: EdgeInsets.all(12.0),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.blueAccent,
                    strokeWidth: 2.5,
                  ),
                ),
              )
            : IconButton(
                icon: Icon(
                  Icons.mic,
                  color: _isRecording ? Colors.redAccent : Colors.white38,
                ),
                tooltip: 'Voice command',
                onPressed: _toggleRecording,
              ),
        IconButton(
          icon: const Icon(Icons.send, color: Colors.blueAccent),
          tooltip: 'Send',
          onPressed: _submit,
        ),
      ],
    );
  }
}
