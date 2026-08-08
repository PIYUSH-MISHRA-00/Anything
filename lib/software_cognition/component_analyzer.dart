/// ComponentAnalyzer / WidgetAnalyzer — understands the UI shape of
/// acquired software. ComponentAnalyzer reuses WebWeaveX's own exported
/// `Soup` HTML parser directly (`package:webweavex`'s bs4-parity engine)
/// to count real semantic HTML5 elements — never a second HTML parser.
/// WidgetAnalyzer reads class names WebWeaveX's own repository IR already
/// extracted (`RepositoryModel.classNames`, sourced from
/// `compileRepository`'s `symbols.classes`) and applies a small, named,
/// Flutter-specific naming heuristic — it does not re-parse source.
library;

import 'package:webweavex/webweavex.dart' as wwx;

import 'component_model.dart';
import 'semantic_software_graph.dart';
import 'software_identity.dart';
import 'software_node.dart';
import 'software_types.dart';

/// Semantic HTML5 tags whose presence is a real, checkable structural
/// signal (navigation, forms, tabular data, etc).
const List<String> _semanticTags = [
  'nav',
  'form',
  'table',
  'header',
  'footer',
  'aside',
  'section',
  'button',
];

class ComponentAnalyzer {
  const ComponentAnalyzer();

  ComponentGraph analyzeHtml(String html) {
    final soup = wwx.Soup(html);
    final nodes = <SoftwareNode>[];
    for (final tag in _semanticTags) {
      final count = soup.findAll(tag).length;
      if (count == 0) continue;
      nodes.add(
        SoftwareNode(
          identity: SoftwareIdentity.stable(SoftwareNodeKind.component, tag),
          kind: SoftwareNodeKind.component,
          label: '$tag ($count)',
        ),
      );
    }
    return ComponentGraph(SemanticSoftwareGraph(nodes: nodes));
  }
}

/// Class names whose shape strongly suggests a Flutter widget/screen —
/// a small, documented, non-exhaustive naming heuristic (WebWeaveX has no
/// Flutter-widget-specific classifier to reuse).
bool _looksLikeWidget(String className) =>
    className.endsWith('Widget') ||
    className.endsWith('Screen') ||
    className.endsWith('Page') ||
    className.endsWith('View');

class WidgetAnalyzer {
  const WidgetAnalyzer();

  WidgetGraph fromClassNames(List<String> classNames) {
    final widgetNames = classNames.where(_looksLikeWidget).toList();
    final nodes = widgetNames
        .map(
          (name) => SoftwareNode(
            identity: SoftwareIdentity.stable(SoftwareNodeKind.widget, name),
            kind: SoftwareNodeKind.widget,
            label: name,
          ),
        )
        .toList();
    return WidgetGraph(SemanticSoftwareGraph(nodes: nodes));
  }
}
