/// The AI provider catalogue — Implementation Specification IS-P06.
///
/// WHY THIS EXISTS.
///
/// Before IS-P06 the app knew about exactly one provider, hardcoded in three
/// places: a `GroqModelProvider` registered in `AnythingProviderRegistry`, a
/// `createGroqConfig()` method on that registry, and a hand-written list of
/// four "not available" names in the settings screen. Adding a provider meant
/// editing all three, and the settings list could — and did — drift out of
/// step with what the app could actually do.
///
/// THE INSIGHT THAT KEEPS THIS SMALL.
///
/// Groq's own base URL is `https://api.groq.com/openai/v1`. Groq, xAI,
/// Mistral, Together, Fireworks, OpenRouter, Cerebras, SambaNova, Nebius,
/// DeepInfra, Ollama, LM Studio, LocalAI, llama.cpp and vLLM all speak the
/// SAME OpenAI-compatible wire protocol. They differ by base URL and by which
/// models they host — not by code.
///
/// So this file is DATA, and `OpenAiCompatibleProvider` is the one adapter
/// that serves every row in it. A provider is added by adding a row, which is
/// what "no provider should exist as a one-off implementation" has to mean in
/// practice.
///
/// OWNERSHIP: this module DECLARES. It performs no I/O and makes no
/// decisions. `AnythingProviderRegistry` decides what to instantiate from it.
library;

/// How a provider is positioned, for grouping in the UI.
enum ProviderCategory {
  /// Hosted frontier/commercial APIs.
  commercial,

  /// Hosted inference for open-weight models.
  openWeight,

  /// Runs on the user's own machine or network.
  local,

  /// User-supplied OpenAI-compatible endpoint.
  generic;

  String get label => switch (this) {
    ProviderCategory.commercial => 'Commercial',
    ProviderCategory.openWeight => 'Open-weight',
    ProviderCategory.local => 'Local',
    ProviderCategory.generic => 'Custom',
  };
}

/// Whether a provider can be used, and if not, honestly why not.
enum ProviderStatus {
  /// An adapter exists and the protocol is supported.
  available,

  /// Usable, but the integration has not been exercised against a live
  /// endpoint by the maintainers.
  experimental,

  /// Declared deliberately, not yet implemented. Carries a real reason.
  comingSoon;

  String get label => switch (this) {
    ProviderStatus.available => 'Available',
    ProviderStatus.experimental => 'Experimental',
    ProviderStatus.comingSoon => 'Coming soon',
  };
}

/// How the provider authenticates.
enum ProviderAuth {
  /// `Authorization: Bearer <key>`.
  bearerToken,

  /// No credential — typically a local server.
  none;

  String get label => switch (this) {
    ProviderAuth.bearerToken => 'API key (Bearer token)',
    ProviderAuth.none => 'No key required',
  };
}

/// What a provider can do.
///
/// These are PROTOCOL-level facts (does the API expose `/models`, does it
/// support SSE streaming). Whether a *particular model* has vision or tools is
/// a property of the model, and model discovery is the authority on that —
/// this class does not attempt to mirror per-model capability matrices,
/// because a hardcoded one would be wrong within a month.
class ProviderCapabilities {
  /// `GET /models` returns the hosted model list.
  final bool modelDiscovery;

  /// Server-sent-event streaming on chat completions.
  final bool streaming;

  /// Function/tool calling is offered by at least some hosted models.
  final bool tools;

  /// Image input is offered by at least some hosted models.
  final bool vision;

  /// An embeddings endpoint is offered.
  final bool embeddings;

  /// Speech-to-text or text-to-speech is offered.
  final bool audio;

  /// Image generation is offered.
  final bool imageGeneration;

  /// Inference runs on the user's own hardware.
  final bool localExecution;

  const ProviderCapabilities({
    this.modelDiscovery = true,
    this.streaming = true,
    this.tools = false,
    this.vision = false,
    this.embeddings = false,
    this.audio = false,
    this.imageGeneration = false,
    this.localExecution = false,
  });

  /// Short human-readable capability names, for the detail sheet.
  List<String> get labels => [
    if (modelDiscovery) 'Model discovery',
    if (streaming) 'Streaming',
    if (tools) 'Tools',
    if (vision) 'Vision',
    if (embeddings) 'Embeddings',
    if (audio) 'Audio',
    if (imageGeneration) 'Image generation',
    if (localExecution) 'Runs locally',
  ];
}

/// Everything the app knows about one provider, declaratively.
class ProviderDescriptor {
  /// Stable identifier. Persisted in configuration — never change one.
  final String id;

  final String name;
  final ProviderCategory category;
  final ProviderStatus status;
  final ProviderAuth auth;

  /// OpenAI-compatible base URL, without a trailing slash.
  ///
  /// `null` when the user must supply it (local servers, custom endpoints).
  final String? baseUrl;

  /// Whether the user must enter an endpoint before the provider can be used.
  bool get requiresEndpoint => baseUrl == null;

  /// Whether the user must enter an API key.
  bool get requiresApiKey => auth != ProviderAuth.none;

  final ProviderCapabilities capabilities;

  /// Model used when the user has not chosen one.
  ///
  /// Deliberately nullable: for providers whose hosted set is unknown ahead of
  /// time (anything local or custom), guessing a default produces exactly the
  /// decommissioned-model failure IS-P06 exists to fix. Those providers
  /// require an explicit choice.
  final String? defaultModel;

  /// One sentence on what this provider is, shown before a key is entered.
  final String summary;

  /// Where to get a key, or read the docs.
  final String? consoleUrl;

  /// Expected key prefix, shown as a hint. Never used for validation — a
  /// provider may change its format at any time.
  final String? keyHint;

  /// For [ProviderStatus.comingSoon], the REAL reason. Required, so a
  /// deferred provider can never appear as unexplained dead UI.
  final String? unavailableReason;

  /// Whether this integration has been exercised against a live endpoint by
  /// the maintainers, as opposed to being protocol-compatible in principle.
  final bool verified;

  const ProviderDescriptor({
    required this.id,
    required this.name,
    required this.category,
    required this.status,
    required this.auth,
    required this.summary,
    this.baseUrl,
    this.capabilities = const ProviderCapabilities(),
    this.defaultModel,
    this.consoleUrl,
    this.keyHint,
    this.unavailableReason,
    this.verified = false,
  });

  /// Whether the app can actually instantiate an adapter for this provider.
  bool get isImplemented => status != ProviderStatus.comingSoon;
}

/// The catalogue.
///
/// Ordered within each category by how likely a user is to want it.
abstract final class ProviderCatalogue {
  // ---------------------------------------------------------------- commercial

  static const ProviderDescriptor groq = ProviderDescriptor(
    id: 'groq',
    name: 'Groq',
    category: ProviderCategory.commercial,
    status: ProviderStatus.available,
    auth: ProviderAuth.bearerToken,
    baseUrl: 'https://api.groq.com/openai/v1',
    // Production model as of this milestone. `gemma2-9b-it` was the previous
    // default and was DECOMMISSIONED on 2025-10-08 — the direct cause of the
    // HTTP 400 that IS-P06 was raised to fix. See GROQ_ROOT_CAUSE_ANALYSIS.md.
    defaultModel: 'llama-3.3-70b-versatile',
    summary:
        'Very fast inference for open-weight models. The provider Anything '
        'has been tested against.',
    consoleUrl: 'https://console.groq.com/keys',
    keyHint: 'gsk_...',
    verified: true,
    capabilities: ProviderCapabilities(tools: true, audio: true),
  );

  static const ProviderDescriptor openai = ProviderDescriptor(
    id: 'openai',
    name: 'OpenAI',
    category: ProviderCategory.commercial,
    status: ProviderStatus.experimental,
    auth: ProviderAuth.bearerToken,
    baseUrl: 'https://api.openai.com/v1',
    defaultModel: 'gpt-4o-mini',
    summary: 'GPT models, direct from OpenAI.',
    consoleUrl: 'https://platform.openai.com/api-keys',
    keyHint: 'sk-...',
    capabilities: ProviderCapabilities(
      tools: true,
      vision: true,
      embeddings: true,
      audio: true,
      imageGeneration: true,
    ),
  );

  static const ProviderDescriptor xai = ProviderDescriptor(
    id: 'xai',
    name: 'xAI',
    category: ProviderCategory.commercial,
    status: ProviderStatus.experimental,
    auth: ProviderAuth.bearerToken,
    baseUrl: 'https://api.x.ai/v1',
    defaultModel: 'grok-2-latest',
    summary: 'Grok models, through an OpenAI-compatible API.',
    consoleUrl: 'https://console.x.ai',
    keyHint: 'xai-...',
    capabilities: ProviderCapabilities(tools: true, vision: true),
  );

  static const ProviderDescriptor mistral = ProviderDescriptor(
    id: 'mistral',
    name: 'Mistral AI',
    category: ProviderCategory.commercial,
    status: ProviderStatus.experimental,
    auth: ProviderAuth.bearerToken,
    baseUrl: 'https://api.mistral.ai/v1',
    defaultModel: 'mistral-small-latest',
    summary: 'Mistral’s hosted models, European infrastructure.',
    consoleUrl: 'https://console.mistral.ai/api-keys',
    capabilities: ProviderCapabilities(tools: true, embeddings: true),
  );

  static const ProviderDescriptor anthropic = ProviderDescriptor(
    id: 'anthropic',
    name: 'Anthropic',
    category: ProviderCategory.commercial,
    status: ProviderStatus.comingSoon,
    auth: ProviderAuth.bearerToken,
    summary: 'Claude models.',
    consoleUrl: 'https://console.anthropic.com/settings/keys',
    keyHint: 'sk-ant-...',
    unavailableReason:
        'The Messages API is not OpenAI-compatible: system prompts sit '
        'outside the message list and the response shape differs, so it '
        'needs its own adapter rather than a base URL.',
  );

  static const ProviderDescriptor gemini = ProviderDescriptor(
    id: 'gemini',
    name: 'Google Gemini',
    category: ProviderCategory.commercial,
    status: ProviderStatus.comingSoon,
    auth: ProviderAuth.bearerToken,
    summary: 'Gemini models from Google AI Studio.',
    consoleUrl: 'https://aistudio.google.com/apikey',
    unavailableReason:
        'Uses `generateContent` with its own request shape and passes the key '
        'as a query parameter, so it needs its own adapter.',
  );

  static const ProviderDescriptor cohere = ProviderDescriptor(
    id: 'cohere',
    name: 'Cohere',
    category: ProviderCategory.commercial,
    status: ProviderStatus.comingSoon,
    auth: ProviderAuth.bearerToken,
    summary: 'Command models, strong at retrieval and reranking.',
    consoleUrl: 'https://dashboard.cohere.com/api-keys',
    unavailableReason:
        'The v2 Chat API differs from the OpenAI shape, so it needs its own '
        'adapter.',
  );

  // --------------------------------------------------------------- open-weight

  static const ProviderDescriptor openrouter = ProviderDescriptor(
    id: 'openrouter',
    name: 'OpenRouter',
    category: ProviderCategory.openWeight,
    status: ProviderStatus.experimental,
    auth: ProviderAuth.bearerToken,
    baseUrl: 'https://openrouter.ai/api/v1',
    summary:
        'One key, hundreds of models from many providers. Useful for trying '
        'models Anything does not list directly.',
    consoleUrl: 'https://openrouter.ai/keys',
    keyHint: 'sk-or-...',
    capabilities: ProviderCapabilities(tools: true, vision: true),
  );

  static const ProviderDescriptor together = ProviderDescriptor(
    id: 'together',
    name: 'Together AI',
    category: ProviderCategory.openWeight,
    status: ProviderStatus.experimental,
    auth: ProviderAuth.bearerToken,
    baseUrl: 'https://api.together.xyz/v1',
    summary: 'Hosted inference for a broad open-weight catalogue.',
    consoleUrl: 'https://api.together.ai/settings/api-keys',
    capabilities: ProviderCapabilities(
      tools: true,
      embeddings: true,
      imageGeneration: true,
    ),
  );

  static const ProviderDescriptor fireworks = ProviderDescriptor(
    id: 'fireworks',
    name: 'Fireworks AI',
    category: ProviderCategory.openWeight,
    status: ProviderStatus.experimental,
    auth: ProviderAuth.bearerToken,
    baseUrl: 'https://api.fireworks.ai/inference/v1',
    summary: 'Fast hosted open-weight inference.',
    consoleUrl: 'https://fireworks.ai/account/api-keys',
    capabilities: ProviderCapabilities(tools: true, embeddings: true),
  );

  static const ProviderDescriptor cerebras = ProviderDescriptor(
    id: 'cerebras',
    name: 'Cerebras',
    category: ProviderCategory.openWeight,
    status: ProviderStatus.experimental,
    auth: ProviderAuth.bearerToken,
    baseUrl: 'https://api.cerebras.ai/v1',
    summary: 'Wafer-scale hardware, very high token throughput.',
    consoleUrl: 'https://cloud.cerebras.ai',
    capabilities: ProviderCapabilities(tools: true),
  );

  static const ProviderDescriptor sambanova = ProviderDescriptor(
    id: 'sambanova',
    name: 'SambaNova',
    category: ProviderCategory.openWeight,
    status: ProviderStatus.experimental,
    auth: ProviderAuth.bearerToken,
    baseUrl: 'https://api.sambanova.ai/v1',
    summary: 'Hosted open-weight inference on SambaNova hardware.',
    consoleUrl: 'https://cloud.sambanova.ai',
    capabilities: ProviderCapabilities(tools: true),
  );

  static const ProviderDescriptor nebius = ProviderDescriptor(
    id: 'nebius',
    name: 'Nebius AI Studio',
    category: ProviderCategory.openWeight,
    status: ProviderStatus.experimental,
    auth: ProviderAuth.bearerToken,
    baseUrl: 'https://api.studio.nebius.ai/v1',
    summary: 'Hosted open-weight models, European infrastructure.',
    consoleUrl: 'https://studio.nebius.ai',
    capabilities: ProviderCapabilities(embeddings: true),
  );

  static const ProviderDescriptor deepinfra = ProviderDescriptor(
    id: 'deepinfra',
    name: 'DeepInfra',
    category: ProviderCategory.openWeight,
    status: ProviderStatus.experimental,
    auth: ProviderAuth.bearerToken,
    baseUrl: 'https://api.deepinfra.com/v1/openai',
    summary: 'Pay-per-token hosting for open-weight models.',
    consoleUrl: 'https://deepinfra.com/dash/api_keys',
    capabilities: ProviderCapabilities(embeddings: true),
  );

  static const ProviderDescriptor huggingface = ProviderDescriptor(
    id: 'huggingface',
    name: 'Hugging Face',
    category: ProviderCategory.openWeight,
    status: ProviderStatus.comingSoon,
    auth: ProviderAuth.bearerToken,
    summary: 'Inference Providers, routing to many hosted backends.',
    consoleUrl: 'https://huggingface.co/settings/tokens',
    unavailableReason:
        'The router needs a provider chosen per model and its model listing '
        'is not the OpenAI `/models` shape, so discovery needs its own '
        'adapter.',
  );

  // --------------------------------------------------------------------- local

  static const ProviderDescriptor ollama = ProviderDescriptor(
    id: 'ollama',
    name: 'Ollama',
    category: ProviderCategory.local,
    status: ProviderStatus.experimental,
    auth: ProviderAuth.none,
    // Not localhost: the phone is not the machine running Ollama. The user
    // must supply their computer's address on the local network.
    summary:
        'Runs models on your own computer. Nothing leaves your network — but '
        'your phone must be able to reach that computer.',
    consoleUrl: 'https://ollama.com',
    capabilities: ProviderCapabilities(
      localExecution: true,
      tools: true,
      embeddings: true,
    ),
  );

  static const ProviderDescriptor lmstudio = ProviderDescriptor(
    id: 'lmstudio',
    name: 'LM Studio',
    category: ProviderCategory.local,
    status: ProviderStatus.experimental,
    auth: ProviderAuth.none,
    summary:
        'Desktop app that serves local models over an OpenAI-compatible API.',
    consoleUrl: 'https://lmstudio.ai',
    capabilities: ProviderCapabilities(localExecution: true, embeddings: true),
  );

  static const ProviderDescriptor localai = ProviderDescriptor(
    id: 'localai',
    name: 'LocalAI',
    category: ProviderCategory.local,
    status: ProviderStatus.experimental,
    auth: ProviderAuth.none,
    summary: 'Self-hosted, OpenAI-compatible inference server.',
    consoleUrl: 'https://localai.io',
    capabilities: ProviderCapabilities(
      localExecution: true,
      embeddings: true,
      imageGeneration: true,
    ),
  );

  static const ProviderDescriptor llamacpp = ProviderDescriptor(
    id: 'llamacpp',
    name: 'llama.cpp',
    category: ProviderCategory.local,
    status: ProviderStatus.experimental,
    auth: ProviderAuth.none,
    summary:
        'Any llama.cpp server started with its OpenAI-compatible endpoint.',
    consoleUrl: 'https://github.com/ggml-org/llama.cpp',
    capabilities: ProviderCapabilities(
      localExecution: true,
      // llama-server exposes /v1/models, but with a single loaded model.
      modelDiscovery: true,
    ),
  );

  static const ProviderDescriptor vllm = ProviderDescriptor(
    id: 'vllm',
    name: 'vLLM',
    category: ProviderCategory.local,
    status: ProviderStatus.experimental,
    auth: ProviderAuth.none,
    summary: 'High-throughput self-hosted serving, OpenAI-compatible.',
    consoleUrl: 'https://docs.vllm.ai',
    capabilities: ProviderCapabilities(localExecution: true, tools: true),
  );

  // ------------------------------------------------------------------- generic

  static const ProviderDescriptor custom = ProviderDescriptor(
    id: 'custom',
    name: 'OpenAI-compatible endpoint',
    category: ProviderCategory.generic,
    status: ProviderStatus.experimental,
    auth: ProviderAuth.bearerToken,
    summary:
        'Any service that implements the OpenAI chat-completions API. Use '
        'this for a provider Anything does not list.',
    capabilities: ProviderCapabilities(tools: true),
  );

  /// Every declared provider, in display order.
  static const List<ProviderDescriptor> all = [
    // Commercial
    groq, openai, anthropic, gemini, xai, mistral, cohere,
    // Open-weight
    openrouter, together, fireworks, cerebras, sambanova, nebius, deepinfra,
    huggingface,
    // Local
    ollama, lmstudio, localai, llamacpp, vllm,
    // Generic
    custom,
  ];

  /// Providers the app can actually instantiate an adapter for.
  static List<ProviderDescriptor> get implemented =>
      all.where((p) => p.isImplemented).toList();

  static ProviderDescriptor? byId(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  static List<ProviderDescriptor> byCategory(ProviderCategory category) =>
      all.where((p) => p.category == category).toList();

  /// Case-insensitive search over name and summary.
  static List<ProviderDescriptor> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              p.id.contains(q) ||
              p.summary.toLowerCase().contains(q),
        )
        .toList();
  }
}
