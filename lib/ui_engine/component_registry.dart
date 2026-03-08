import 'package:flutter/material.dart';
import '../models/auil_schema_model.dart';
import 'package:fl_chart/fl_chart.dart';

class ComponentRegistry {
  static Widget buildComponent(AUILComponent component) {
    switch (component.type) {
      case 'header':
        return HeaderWidget(content: component.content ?? '');
      case 'text_block':
      case 'text':
        return TextBlockWidget(content: component.content ?? '');
      case 'metric_card':
        return MetricCardWidget(data: component.data);
      case 'chart':
        return ChartWidget(data: component.data);
      case 'table':
        return TableWidget(data: component.data);
      case 'kanban_board':
      case 'kanban':
        return KanbanWidget(data: component.data);
      case 'form':
        return FormWidget(data: component.data);
      case 'notes':
        return NotesWidget(data: component.data);
      case 'progress_bar':
        return ProgressBarWidget(data: component.data);
      case 'container':
        return ContainerWidget(data: component.data);
      case 'button':
        return ButtonWidget(data: component.data);
      case 'input':
        return InputWidget(data: component.data);
      case 'list':
        return ListWidget(data: component.data);
      case 'calendar':
        return CalendarWidget(data: component.data);
      case 'grid':
        return GridWidget(data: component.data);
      case 'chat':
        return ChatWidget(data: component.data);
      case 'activity_feed':
        return ActivityFeedWidget(data: component.data);
      default:
        return FallbackWidget(type: component.type);
    }
  }
}

// ─── Header ──────────────────────────────────────────────

class HeaderWidget extends StatelessWidget {
  final String content;
  const HeaderWidget({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Text(
        content,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
      ),
    );
  }
}

// ─── Text Block ──────────────────────────────────────────

class TextBlockWidget extends StatelessWidget {
  final String content;
  const TextBlockWidget({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(content, style: const TextStyle(fontSize: 15, color: Colors.white70, height: 1.5)),
    );
  }
}

// ─── Metric Card ─────────────────────────────────────────

class MetricCardWidget extends StatelessWidget {
  final dynamic data;
  const MetricCardWidget({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data?['title'] ?? 'Metric', style: const TextStyle(color: Colors.white54, fontSize: 13)),
          const SizedBox(height: 8),
          Text(data?['value']?.toString() ?? '--',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
        ],
      ),
    );
  }
}

// ─── Chart ───────────────────────────────────────────────

class ChartWidget extends StatelessWidget {
  final dynamic data;
  const ChartWidget({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: const [FlSpot(0, 1), FlSpot(1, 1.5), FlSpot(2, 1.4), FlSpot(3, 3.4), FlSpot(4, 2), FlSpot(5, 2.2), FlSpot(6, 1.8)],
              isCurved: true,
              color: Colors.blueAccent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: Colors.blueAccent.withValues(alpha: 0.15)),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Table ───────────────────────────────────────────────

class TableWidget extends StatelessWidget {
  final dynamic data;
  const TableWidget({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: const Center(child: Text('Data Table', style: TextStyle(color: Colors.white54))),
    );
  }
}

// ─── Kanban Board ────────────────────────────────────────

class KanbanWidget extends StatelessWidget {
  final dynamic data;
  const KanbanWidget({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    final columns = ['To Do', 'In Progress', 'Done'];
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: columns.map((col) {
          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(col, style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('Sample task', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Form ────────────────────────────────────────────────

class FormWidget extends StatelessWidget {
  final dynamic data;
  const FormWidget({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Form', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 16),
          TextField(
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter value...',
              hintStyle: const TextStyle(color: Colors.white30),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Notes ───────────────────────────────────────────────

class NotesWidget extends StatelessWidget {
  final dynamic data;
  const NotesWidget({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.sticky_note_2, color: Colors.blueAccent.withValues(alpha: 0.7), size: 18),
            const SizedBox(width: 8),
            const Text('Notes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 12),
          Text(data?['content'] ?? 'Your notes here...', style: const TextStyle(color: Colors.white60, fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}

// ─── Progress Bar ────────────────────────────────────────

class ProgressBarWidget extends StatelessWidget {
  final dynamic data;
  const ProgressBarWidget({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    final progress = (data?['value'] ?? 0.5).toDouble();
    final label = data?['label'] ?? 'Progress';

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500)),
            Text('${(progress * 100).toInt()}%', style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueAccent),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Container ───────────────────────────────────────────

class ContainerWidget extends StatelessWidget {
  final dynamic data;
  const ContainerWidget({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(data?['content'] ?? '', style: const TextStyle(color: Colors.white70, fontSize: 14)),
    );
  }
}

// ─── Button ──────────────────────────────────────────────

class ButtonWidget extends StatelessWidget {
  final dynamic data;
  const ButtonWidget({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton(
        onPressed: () {},
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
        child: Text(data?['label'] ?? 'Action', style: const TextStyle(fontSize: 15)),
      ),
    );
  }
}

// ─── Input ───────────────────────────────────────────────

class InputWidget extends StatelessWidget {
  final dynamic data;
  const InputWidget({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: data?['placeholder'] ?? 'Enter text...',
          hintStyle: const TextStyle(color: Colors.white30),
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.05),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}

// ─── List ────────────────────────────────────────────────

class ListWidget extends StatelessWidget {
  final dynamic data;
  const ListWidget({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    final items = (data?['items'] as List?)?.cast<String>() ?? ['Item 1', 'Item 2', 'Item 3'];
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: items.map((item) {
          return ListTile(
            leading: Icon(Icons.circle, size: 8, color: Colors.blueAccent.withValues(alpha: 0.7)),
            title: Text(item, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Calendar ────────────────────────────────────────────

class CalendarWidget extends StatelessWidget {
  final dynamic data;
  const CalendarWidget({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.calendar_month, color: Colors.blueAccent, size: 20),
            const SizedBox(width: 8),
            const Text('Calendar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ]),
          const SizedBox(height: 12),
          const Text('Today', style: TextStyle(color: Colors.white54)),
          const SizedBox(height: 8),
          Text(DateTime.now().toString().split(' ')[0], style: const TextStyle(color: Colors.white70, fontSize: 18)),
        ],
      ),
    );
  }
}

// ─── Grid ────────────────────────────────────────────────

class GridWidget extends StatelessWidget {
  final dynamic data;
  const GridWidget({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: GridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(6, (i) {
          return Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Center(child: Text('${i + 1}', style: const TextStyle(color: Colors.white38))),
          );
        }),
      ),
    );
  }
}

// ─── Chat ────────────────────────────────────────────────

class ChatWidget extends StatelessWidget {
  final dynamic data;
  const ChatWidget({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          _chatBubble('AI', 'How can I help you?', true),
          _chatBubble('You', data?['message'] ?? 'Hello!', false),
        ],
      ),
    );
  }

  Widget _chatBubble(String sender, String message, bool isAI) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: isAI ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
            child: Icon(isAI ? Icons.smart_toy : Icons.person, size: 14, color: isAI ? Colors.blueAccent : Colors.white54),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(message, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Activity Feed ───────────────────────────────────────

class ActivityFeedWidget extends StatelessWidget {
  final dynamic data;
  const ActivityFeedWidget({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _activityItem(Icons.check_circle, 'Task completed', '2 min ago', Colors.greenAccent),
          _activityItem(Icons.upload_file, 'File uploaded', '15 min ago', Colors.blueAccent),
          _activityItem(Icons.analytics, 'Analysis done', '1 hr ago', Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _activityItem(IconData icon, String text, String time, Color color) {
    return ListTile(
      leading: Icon(icon, color: color, size: 20),
      title: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 14)),
      trailing: Text(time, style: const TextStyle(color: Colors.white38, fontSize: 12)),
    );
  }
}

// ─── Fallback ────────────────────────────────────────────

class FallbackWidget extends StatelessWidget {
  final String type;
  const FallbackWidget({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
      ),
      child: Text('Unsupported component: $type', style: const TextStyle(color: Colors.redAccent)),
    );
  }
}
