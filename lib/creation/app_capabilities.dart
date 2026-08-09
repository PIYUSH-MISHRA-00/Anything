/// Open-world application capabilities — describe WHAT an app needs, not its name.
///
/// Primary path: structured capability ids from the model/blueprint.
/// Lexical cues are a bounded fallback only when the structured plan under-
/// specifies primary purpose — they must not be the sole application selector.
library;

import '../core/contracts/intent.dart';
import '../synthesis/app_archetype.dart';
import '../synthesis/app_blueprint.dart';
import 'experience_package.dart';

/// Canonical capability identifiers the generation stack understands.
abstract final class AppCapabilityIds {
  static const input = 'input';
  static const form = 'form';
  static const entity = 'entity';
  static const collection = 'collection';
  static const crud = 'crud';
  static const search = 'search';
  static const filter = 'filter';
  static const sort = 'sort';
  static const navigation = 'navigation';
  static const calculation = 'calculation';
  /// Calculation mode with scientific / trig / log operations.
  static const scientificCalculation = 'scientificCalculation';
  static const networkData = 'networkData';
  static const webData = 'webData';
  /// Structured weather observations — NOT generic web knowledge.
  static const weatherData = 'weatherData';
  /// Structured news articles — NOT generic web knowledge.
  static const newsData = 'newsData';
  /// Explicit web-knowledge / research (WebWeaveX path).
  static const webKnowledge = 'webKnowledge';
  static const refresh = 'refresh';
  static const authentication = 'authentication';
  static const persistence = 'persistence';
  static const notifications = 'notifications';
  static const charts = 'charts';
  static const maps = 'maps';
  static const media = 'media';
  static const files = 'files';
  static const sharing = 'sharing';
  static const settings = 'settings';
  static const timers = 'timers';
  static const scheduling = 'scheduling';
  static const location = 'location';
  static const camera = 'camera';
  static const microphone = 'microphone';
  static const offlineCache = 'offlineCache';
  static const synchronization = 'synchronization';
  static const secureStorage = 'secureStorage';
  static const loadingState = 'loadingState';
  static const errorState = 'errorState';
  static const resultDisplay = 'resultDisplay';

  /// Vocabulary advertised to the model reasoner (open-world, not app names).
  static const List<String> vocabulary = [
    input,
    form,
    entity,
    collection,
    crud,
    search,
    filter,
    sort,
    navigation,
    calculation,
    scientificCalculation,
    networkData,
    webData,
    weatherData,
    newsData,
    webKnowledge,
    refresh,
    authentication,
    persistence,
    notifications,
    charts,
    maps,
    media,
    files,
    sharing,
    settings,
    timers,
    scheduling,
    location,
    camera,
    microphone,
    offlineCache,
    synchronization,
    secureStorage,
    loadingState,
    errorState,
    resultDisplay,
  ];
}

/// Infers required capabilities from blueprint structure + optional intent.
class AppCapabilityInferrer {
  const AppCapabilityInferrer();

  /// Infer capabilities without hard-coding product domain names.
  Set<String> infer({required AppBlueprint blueprint, Intent? intent}) {
    final caps = <String>{...blueprint.requiredCapabilities.map(_normalize)};

    // IS-P12: `utility` is NOT calculation. Calculators, timers, and other
    // local tools all use the utility archetype. Inferring calculation from
    // utility alone caused stopwatch → calculator substitution.
    // Calculation / timers are inferred from explicit caps or structure below.

    if (blueprint.archetypes.contains(AppArchetype.reference) ||
        blueprint.networkConfig != null ||
        blueprint.offlinePolicy == OfflinePolicy.networkRequired) {
      caps.add(AppCapabilityIds.networkData);
      caps.add(AppCapabilityIds.webData);
      caps.add(AppCapabilityIds.refresh);
      caps.add(AppCapabilityIds.loadingState);
      caps.add(AppCapabilityIds.errorState);
      caps.add(AppCapabilityIds.input);
      caps.add(AppCapabilityIds.resultDisplay);
    }

    if (blueprint.archetypes.contains(AppArchetype.dashboard)) {
      caps.add(AppCapabilityIds.charts);
      caps.add(AppCapabilityIds.resultDisplay);
    }

    if (blueprint.archetypes.contains(AppArchetype.planner) ||
        blueprint.archetypes.contains(AppArchetype.tracker)) {
      caps.add(AppCapabilityIds.scheduling);
      caps.add(AppCapabilityIds.persistence);
    }

    final hasEntities = blueprint.entities.isNotEmpty;
    final hasCrud = blueprint.actions.any(
      (a) =>
          a.actionType == BlueprintActionType.create ||
          a.actionType == BlueprintActionType.update ||
          a.actionType == BlueprintActionType.delete,
    );
    // Reference/network-primary blueprints may carry decorative entities from
    // the model; do not force a CRUD install gate unless collection/tracker
    // archetypes explicitly ask for durable records.
    final expressionHint = intent?.expression.toLowerCase() ?? '';
    final looksNetworkFromIntent =
        expressionHint.contains('dashboard') ||
        expressionHint.contains('live') ||
        expressionHint.contains('online') ||
        expressionHint.contains('lookup') ||
        expressionHint.contains('reference');
    final networkPrimary =
        blueprint.archetypes.contains(AppArchetype.reference) ||
        looksNetworkFromIntent ||
        (blueprint.networkConfig != null &&
            !blueprint.archetypes.contains(AppArchetype.collection) &&
            !blueprint.archetypes.contains(AppArchetype.tracker));

    if (hasEntities && !networkPrimary) {
      caps.add(AppCapabilityIds.entity);
      caps.add(AppCapabilityIds.form);
    }
    if (hasEntities && hasCrud && !networkPrimary) {
      caps.add(AppCapabilityIds.crud);
      caps.add(AppCapabilityIds.collection);
      caps.add(AppCapabilityIds.persistence);
      caps.add(AppCapabilityIds.input);
    }

    if (blueprint.views.any((v) => v.viewType == BlueprintViewType.list)) {
      caps.add(AppCapabilityIds.collection);
      caps.add(AppCapabilityIds.search);
    }

    if (blueprint.views.length > 1) {
      caps.add(AppCapabilityIds.navigation);
    }

    // Structural calculation: numeric/category operand form without a
    // durable collection workflow → treat as calculation utility.
    if (!caps.contains(AppCapabilityIds.calculation) &&
        _looksLikeCalculationUtility(blueprint)) {
      caps.add(AppCapabilityIds.calculation);
      caps.add(AppCapabilityIds.input);
      caps.add(AppCapabilityIds.resultDisplay);
    }

    // Structural timing: elapsed/duration/lap-shaped fields + start/pause/reset
    // style actions, or an explicit timers capability from the model.
    if (!caps.contains(AppCapabilityIds.timers) &&
        _looksLikeTimingUtility(blueprint)) {
      caps.add(AppCapabilityIds.timers);
      caps.add(AppCapabilityIds.input);
      caps.add(AppCapabilityIds.resultDisplay);
    }

    final expression = intent?.expression.toLowerCase() ?? '';
    // Structured plan wins. Lexical cues only fill gaps when the model/
    // blueprint omitted a primary capability surface.
    final hasPrimarySurface =
        caps.contains(AppCapabilityIds.calculation) ||
        caps.contains(AppCapabilityIds.scientificCalculation) ||
        caps.contains(AppCapabilityIds.timers) ||
        caps.contains(AppCapabilityIds.weatherData) ||
        caps.contains(AppCapabilityIds.newsData) ||
        caps.contains(AppCapabilityIds.webKnowledge) ||
        caps.contains(AppCapabilityIds.crud);

    if (expression.isNotEmpty) {
      if (expression.contains('offline') || expression.contains('sync')) {
        caps.add(AppCapabilityIds.offlineCache);
        caps.add(AppCapabilityIds.synchronization);
      }

      if (!hasPrimarySurface) {
        // Bounded lexical FALLBACK (under-specified plans only).
        final looksLive =
            expression.contains('live') ||
            expression.contains('online') ||
            expression.contains('dashboard') ||
            expression.contains('api') ||
            expression.contains('fetch') ||
            expression.contains('realtime') ||
            expression.contains('real-time');
        final looksLookup =
            expression.contains('search') ||
            expression.contains('web') ||
            expression.contains('lookup') ||
            expression.contains('reference');
        if (looksLive || looksLookup) {
          caps.add(AppCapabilityIds.networkData);
          caps.add(AppCapabilityIds.webData);
          caps.add(AppCapabilityIds.refresh);
          caps.add(AppCapabilityIds.loadingState);
          caps.add(AppCapabilityIds.errorState);
          caps.add(AppCapabilityIds.input);
          caps.add(AppCapabilityIds.resultDisplay);
        }

        final looksTiming =
            expression.contains('stopwatch') ||
            expression.contains('timer') ||
            expression.contains('countdown') ||
            expression.contains('chronometer') ||
            expression.contains('elapsed') ||
            RegExp(r'\blap\b').hasMatch(expression);
        if (looksTiming && !caps.contains(AppCapabilityIds.calculation)) {
          caps.add(AppCapabilityIds.timers);
          caps.add(AppCapabilityIds.input);
          caps.add(AppCapabilityIds.resultDisplay);
          caps.remove(AppCapabilityIds.calculation);
        }

        final looksArithmetic =
            expression.contains('calculator') ||
            expression.contains('arithmetic') ||
            expression.contains('calculate');
        if (looksArithmetic && !caps.contains(AppCapabilityIds.timers)) {
          caps.add(AppCapabilityIds.calculation);
          caps.add(AppCapabilityIds.input);
          caps.add(AppCapabilityIds.resultDisplay);
          if (expression.contains('scientific') ||
              expression.contains('trig') ||
              expression.contains('engineering')) {
            caps.add(AppCapabilityIds.scientificCalculation);
          }
        }

        // Durable-record cues beat weather/news lexical shells — otherwise
        // "articles" / "temperature" hijack management apps into domain shells.
        final looksManagedRecords =
            expression.contains('manage') ||
            expression.contains('manager') ||
            expression.contains('operations') ||
            expression.contains('maintenance') ||
            expression.contains('inventory') ||
            expression.contains('schedule') ||
            expression.contains('records') ||
            expression.contains('members') ||
            expression.contains('recipes') ||
            expression.contains('batches') ||
            expression.contains('track') ||
            expression.contains('planner');

        final looksWeather =
            !looksManagedRecords &&
            (expression.contains('weather') ||
                expression.contains('forecast') ||
                (expression.contains('temperature') &&
                    !expression.contains('manage')) ||
                expression.contains('humidity'));
        final looksNews =
            !looksManagedRecords &&
            (RegExp(r'\bnews\b').hasMatch(expression) ||
                expression.contains('headline') ||
                expression.contains('headlines') ||
                (expression.contains('articles') &&
                    !expression.contains('manage')));
        final looksResearch =
            !looksManagedRecords &&
            (expression.contains('research') ||
                expression.contains('explain') ||
                expression.contains('wikipedia') ||
                expression.contains('who founded') ||
                expression.contains('history of'));

        if (looksWeather) {
          caps.add(AppCapabilityIds.weatherData);
          caps.add(AppCapabilityIds.input);
          caps.add(AppCapabilityIds.refresh);
          caps.add(AppCapabilityIds.loadingState);
          caps.add(AppCapabilityIds.errorState);
          caps.add(AppCapabilityIds.resultDisplay);
          caps.remove(AppCapabilityIds.networkData);
          caps.remove(AppCapabilityIds.webData);
          caps.remove(AppCapabilityIds.webKnowledge);
          caps.remove(AppCapabilityIds.crud);
          caps.remove(AppCapabilityIds.form);
          caps.remove(AppCapabilityIds.entity);
          caps.remove(AppCapabilityIds.collection);
        } else if (looksNews) {
          caps.add(AppCapabilityIds.newsData);
          caps.add(AppCapabilityIds.input);
          caps.add(AppCapabilityIds.refresh);
          caps.add(AppCapabilityIds.loadingState);
          caps.add(AppCapabilityIds.errorState);
          caps.add(AppCapabilityIds.resultDisplay);
          caps.remove(AppCapabilityIds.networkData);
          caps.remove(AppCapabilityIds.webData);
          caps.remove(AppCapabilityIds.webKnowledge);
          caps.remove(AppCapabilityIds.crud);
          caps.remove(AppCapabilityIds.form);
          caps.remove(AppCapabilityIds.entity);
          caps.remove(AppCapabilityIds.collection);
        } else if (looksResearch) {
          caps.add(AppCapabilityIds.webKnowledge);
          caps.add(AppCapabilityIds.networkData);
          caps.add(AppCapabilityIds.webData);
          caps.add(AppCapabilityIds.refresh);
          caps.add(AppCapabilityIds.loadingState);
          caps.add(AppCapabilityIds.errorState);
          caps.add(AppCapabilityIds.input);
          caps.add(AppCapabilityIds.resultDisplay);
        }
      } else if (caps.contains(AppCapabilityIds.calculation) &&
          !caps.contains(AppCapabilityIds.scientificCalculation) &&
          (expression.contains('scientific') ||
              expression.contains('trig') ||
              expression.contains('engineering'))) {
        // Mode refinement when calculation already structured.
        caps.add(AppCapabilityIds.scientificCalculation);
      }
    }

    // Never install both primary pads from ambiguous utility blueprints.
    if (caps.contains(AppCapabilityIds.timers) &&
        caps.contains(AppCapabilityIds.calculation)) {
      if (_looksLikeTimingUtility(blueprint) ||
          (expression.contains('timer') ||
              expression.contains('stopwatch') ||
              expression.contains('countdown'))) {
        caps.remove(AppCapabilityIds.calculation);
        caps.remove(AppCapabilityIds.scientificCalculation);
      } else if (_looksLikeCalculationUtility(blueprint)) {
        caps.remove(AppCapabilityIds.timers);
      } else {
        // Prefer neither false product over the wrong one: drop calculation
        // (historically the unsafe default).
        caps.remove(AppCapabilityIds.calculation);
        caps.remove(AppCapabilityIds.scientificCalculation);
      }
    }

    return caps;
  }

  bool _looksLikeCalculationUtility(AppBlueprint blueprint) {
    if (blueprint.entities.isEmpty) return false;
    if (_looksLikeTimingUtility(blueprint)) return false;
    if (blueprint.actions.any(
      (a) =>
          a.actionType == BlueprintActionType.create ||
          a.actionType == BlueprintActionType.delete,
    )) {
      // Durable records — not a pure calculator.
      if (blueprint.views.any((v) => v.viewType == BlueprintViewType.list)) {
        return false;
      }
    }

    final fields = blueprint.entities.expand((e) => e.fields).toList();
    final numeric = fields.where(
      (f) =>
          f.type == BlueprintFieldType.integer ||
          f.type == BlueprintFieldType.decimal,
    );
    final hasOperator = fields.any(
      (f) =>
          f.type == BlueprintFieldType.category ||
          f.allowedValues.any(
            (v) => const ['+', '-', '*', '/', '×', '÷'].contains(v),
          ),
    );
    final hasResultish = fields.any(
      (f) =>
          f.id.contains('result') ||
          f.name.toLowerCase().contains('result') ||
          f.name.toLowerCase().contains('total'),
    );
    return numeric.length >= 2 && (hasOperator || hasResultish);
  }

  /// Structural timing cue — field/action shape, not a product name map.
  bool _looksLikeTimingUtility(AppBlueprint blueprint) {
    final fields = blueprint.entities.expand((e) => e.fields).toList();
    final fieldText = fields
        .map((f) => '${f.id} ${f.name}'.toLowerCase())
        .join(' ');
    final timingField = RegExp(
      r'elapsed|duration|lap|centisecond|millisecond|stopwatch|timer',
    ).hasMatch(fieldText);

    final actionText = blueprint.actions
        .map((a) => '${a.id} ${a.name}'.toLowerCase())
        .join(' ');
    final timingActions = RegExp(
      r'\b(start|pause|resume|reset|lap|stop)\b',
    ).hasMatch(actionText);

    final hasDurableCrud = blueprint.actions.any(
      (a) =>
          a.actionType == BlueprintActionType.create ||
          a.actionType == BlueprintActionType.delete,
    );

    if (timingField && timingActions) return true;
    if (timingField &&
        !hasDurableCrud &&
        blueprint.archetypes.contains(AppArchetype.utility)) {
      return true;
    }
    if (timingActions &&
        !hasDurableCrud &&
        fields.length <= 4 &&
        blueprint.archetypes.contains(AppArchetype.utility)) {
      return true;
    }
    return false;
  }

  String _normalize(String raw) {
    final id = raw.trim();
    // Accept common aliases from models without inventing new domains.
    switch (id.toLowerCase()) {
      case 'network':
      case 'network_data':
      case 'external_data':
        return AppCapabilityIds.networkData;
      case 'web':
      case 'web_data':
        return AppCapabilityIds.webData;
      case 'calc':
      case 'math':
      case 'arithmetic':
        return AppCapabilityIds.calculation;
      case 'scientific_calculation':
      case 'scientific-calc':
      case 'scientific_calculator':
        return AppCapabilityIds.scientificCalculation;
      case 'timer':
      case 'timing':
      case 'stopwatch':
      case 'countdown':
      case 'elapsed_time':
        return AppCapabilityIds.timers;
      case 'weather':
      case 'weather_data':
      case 'forecast':
        return AppCapabilityIds.weatherData;
      case 'news':
      case 'news_data':
      case 'headlines':
        return AppCapabilityIds.newsData;
      case 'web_knowledge':
      case 'research':
        return AppCapabilityIds.webKnowledge;
      case 'crud_ops':
        return AppCapabilityIds.crud;
      default:
        return id;
    }
  }
}

/// Presence helpers for package inspection (used by validator + repair).
class PackageCapabilityProbe {
  const PackageCapabilityProbe(this.package);

  final ExperiencePackage package;

  Iterable<InterfaceNode> get _nodes sync* {
    for (final screen in package.interface.screens) {
      yield* _walk(screen.children);
    }
  }

  static Iterable<InterfaceNode> _walk(List<InterfaceNode> roots) sync* {
    for (final n in roots) {
      yield n;
      yield* _walk(n.children);
    }
  }

  bool get hasEntityForm => _nodes.any((n) => n.type == 'entityForm');

  bool get hasEntityList => _nodes.any((n) => n.type == 'entityList');

  bool get hasTextInput => _nodes.any(
    (n) =>
        n.type == 'input' || n.type == 'searchField' || n.type == 'entityForm',
  );

  bool get hasResultDisplay => _nodes.any(
    (n) =>
        n.stateBinding == 'display' ||
        n.stateBinding == 'result' ||
        n.stateBinding == 'resultText' ||
        n.id.contains('result') ||
        n.id.contains('display'),
  );

  bool get hasCalculationPad {
    final actions = _nodes
        .map((n) => n.actionBinding?.actionId)
        .whereType<String>()
        .toSet();
    final hasDigit = actions.any(
      (a) =>
          a == 'calc.digit' ||
          a == 'numberPressed' ||
          a.startsWith('calc.digit'),
    );
    final hasOp = actions.any(
      (a) =>
          a == 'calc.operator' ||
          a == 'operationPressed' ||
          a.startsWith('calc.operator'),
    );
    final hasEquals =
        actions.contains('calc.equals') || actions.contains('equalsPressed');
    final hasClear =
        actions.contains('calc.clear') || actions.contains('clearPressed');
    return hasDigit && hasOp && hasEquals && hasClear;
  }

  /// Scientific ops present (unary functions / constants) — not just basic pad.
  bool get hasScientificOps {
    final actions = _nodes
        .map((n) => n.actionBinding?.actionId)
        .whereType<String>()
        .toSet();
    return actions.contains('calc.unary') || actions.contains('calc.constant');
  }

  /// Timing surface: start + pause/reset + elapsed display binding.
  bool get hasTimingControls {
    final actions = _nodes
        .map((n) => n.actionBinding?.actionId)
        .whereType<String>()
        .toSet();
    final hasStart =
        actions.contains('timer.start') ||
        actions.any((a) => a.toLowerCase() == 'start');
    final hasPauseOrReset =
        actions.contains('timer.pause') ||
        actions.contains('timer.reset') ||
        actions.any((a) => a.toLowerCase() == 'pause') ||
        actions.any((a) => a.toLowerCase() == 'reset');
    final hasDisplay = _nodes.any(
      (n) =>
          n.stateBinding == 'display' ||
          n.id.contains('display') ||
          n.id.contains('elapsed'),
    );
    return hasStart && hasPauseOrReset && hasDisplay;
  }

  bool get hasRefreshAction => _nodes.any((n) {
    final id = n.actionBinding?.actionId.toLowerCase() ?? '';
    // SearchAction is the generic refresh/query entry point (P15).
    return id == 'refreshdata' ||
        id == 'refresh' ||
        id.contains('refresh') ||
        id == 'search' ||
        id == 'searchaction';
  });

  bool get hasLoadingState => package.state.variables.any(
    (v) => v.id == 'loading' || v.id.endsWith('_loading'),
  );

  bool get hasErrorState => package.state.variables.any(
    (v) => v.id == 'error' || v.id.endsWith('_error'),
  );

  bool get hasKnowledgeService => package.services.any(
    (s) => s.type == 'knowledgeRetrieval' || s.type == 'httpClient',
  );

  bool get hasWeatherService =>
      package.services.any((s) => s.type == 'weatherData');

  bool get hasNewsService =>
      package.services.any((s) => s.type == 'newsData');

  bool get hasPersistence =>
      package.data != null && package.data!.entities.isNotEmpty;
}
