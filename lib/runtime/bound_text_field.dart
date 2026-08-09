/// Text field that keeps Experience state and controller in sync across rebuilds.
///
/// Plain [TextField] with only [onChanged] loses typed text when the parent
/// rebuilds (e.g. loading state flips), which made Search look broken.
library;

import 'package:flutter/material.dart';

import 'state_engine.dart';

/// Bound input for Experience state variables.
class BoundTextField extends StatefulWidget {
  final ExperienceStateEngine stateEngine;
  final String stateId;
  final String? label;
  final String? hint;
  final TextInputAction textInputAction;
  final void Function(String value)? onSubmitted;

  const BoundTextField({
    super.key,
    required this.stateEngine,
    required this.stateId,
    this.label,
    this.hint,
    this.textInputAction = TextInputAction.search,
    this.onSubmitted,
  });

  @override
  State<BoundTextField> createState() => _BoundTextFieldState();
}

class _BoundTextFieldState extends State<BoundTextField> {
  late final TextEditingController _controller;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.stateEngine.read(widget.stateId)?.toString() ?? '';
    _controller = TextEditingController(text: initial);
  }

  @override
  void didUpdateWidget(covariant BoundTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_editing) return;
    final next = widget.stateEngine.read(widget.stateId)?.toString() ?? '';
    if (_controller.text != next) {
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: widget.textInputAction,
      decoration: InputDecoration(
        labelText: widget.label?.isEmpty == true ? null : widget.label,
        hintText: widget.hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onChanged: (value) {
        _editing = true;
        widget.stateEngine.write(widget.stateId, value);
      },
      onSubmitted: (value) {
        _editing = false;
        widget.stateEngine.write(widget.stateId, value);
        widget.onSubmitted?.call(value);
      },
      onEditingComplete: () {
        _editing = false;
      },
      onTapOutside: (_) {
        _editing = false;
        widget.stateEngine.write(widget.stateId, _controller.text);
      },
    );
  }
}
