import 'package:flutter/material.dart';
import '../models/auil_schema_model.dart';
import 'package:fl_chart/fl_chart.dart'; // From plan.md requirements

class ComponentRegistry {
  static Widget buildComponent(AUILComponent component) {
    switch (component.type) {
      case 'text_block':
        return TextBlockWidget(content: component.content ?? '');
      case 'metric_card':
        return MetricCardWidget(data: component.data);
      case 'chart':
        return ChartWidget(data: component.data);
      case 'table':
        return TableWidget(data: component.data);
      default:
        return FallbackWidget(type: component.type);
    }
  }
}

class TextBlockWidget extends StatelessWidget {
  final String content;
  const TextBlockWidget({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        content,
        style: const TextStyle(fontSize: 16, color: Colors.white70),
      ),
    );
  }
}

class MetricCardWidget extends StatelessWidget {
  final dynamic data;
  const MetricCardWidget({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(data?['title'] ?? 'Metric', style: const TextStyle(color: Colors.white54)),
          const SizedBox(height: 8),
          Text(
            data?['value']?.toString() ?? '--', 
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)
          ),
        ],
      ),
    );
  }
}

class ChartWidget extends StatelessWidget {
  final dynamic data;
  const ChartWidget({super.key, this.data});

  @override
  Widget build(BuildContext context) {
    // Demonstrating fl_chart usage for mock generative responses
    return Container(
      height: 200,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      alignment: Alignment.center,
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: const [
                FlSpot(0, 1),
                FlSpot(1, 1.5),
                FlSpot(2, 1.4),
                FlSpot(3, 3.4),
                FlSpot(4, 2),
                FlSpot(5, 2.2),
                FlSpot(6, 1.8),
              ],
              isCurved: true,
              color: Colors.blueAccent,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blueAccent.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: const Center(child: Text('Data Table Placeholder', style: TextStyle(color: Colors.white54))),
    );
  }
}

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
      child: Text('Unsupported component type: $type', style: const TextStyle(color: Colors.redAccent)),
    );
  }
}
