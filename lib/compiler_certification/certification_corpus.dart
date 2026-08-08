/// CertificationCorpus — Implementation Milestone R23. Real, hand-built
/// `SemanticApp` fixtures (exactly the same construction style R19-R22's
/// own test files already use — `_fieldLogApp`/`_taskBoardApp`-shaped),
/// covering the categories R23's spec names. Never LLM-generated: every
/// fixture here is authored test data, run through the real Kernel to
/// produce a real `blueprint` + `CanonicalImplementationModel`, exactly
/// like every prior milestone's fixtures.
///
/// "Composite applications" (R23) is interpreted honestly, per R21's own
/// finding: `SemanticView.sections`/composite-view rendering has no real
/// signal in either pipeline (legacy never reads `sections`). "Composite"
/// here means a real, already-supported thing — one app mixing CRUD +
/// dashboard + settings views — never a fabricated section/sub-component
/// concept.
library;

import '../synthesis/app_blueprint.dart';
import '../synthesis/application_reasoner.dart';

class CertificationFixture {
  final String category;
  final SemanticApp app;
  final List<String> requiredCapabilityIds;

  const CertificationFixture({
    required this.category,
    required this.app,
    this.requiredCapabilityIds = const [],
  });
}

class CertificationCorpus {
  const CertificationCorpus();

  List<CertificationFixture> get fixtures => [
    CertificationFixture(category: 'crud', app: _crudApp()),
    CertificationFixture(category: 'offline_first', app: _offlineFirstApp()),
    CertificationFixture(category: 'dashboard', app: _dashboardApp()),
    CertificationFixture(category: 'calendar', app: _calendarApp()),
    CertificationFixture(category: 'settings', app: _settingsApp()),
    CertificationFixture(category: 'summary', app: _summaryApp()),
    CertificationFixture(category: 'multi_entity', app: _multiEntityApp()),
    CertificationFixture(category: 'relationships', app: _relationshipsApp()),
    CertificationFixture(
      category: 'permissions',
      app: _permissionsApp(),
      requiredCapabilityIds: ['notifications'],
    ),
    CertificationFixture(
      category: 'capabilities',
      app: _capabilitiesApp(),
      requiredCapabilityIds: ['clock'],
    ),
    CertificationFixture(category: 'navigation', app: _navigationApp()),
    CertificationFixture(
      category: 'backend_required',
      app: _backendRequiredApp(),
      requiredCapabilityIds: ['http'],
    ),
    CertificationFixture(category: 'composite', app: _compositeApp()),
  ];

  static SemanticApp _crudApp() => SemanticApp(
    name: 'Field Log',
    purpose: 'Track field log entries',
    entities: const [
      SemanticEntity(
        id: 'entry',
        name: 'Entry',
        displayField: 'title',
        fields: [
          SemanticField(
            id: 'title',
            name: 'Title',
            type: BlueprintFieldType.text,
            required: true,
          ),
        ],
      ),
    ],
    views: const [
      SemanticView(
        id: 'entries_list',
        name: 'Entries',
        purpose: 'list',
        sourceEntityId: 'entry',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
    ],
    actions: const [
      SemanticAction(
        id: 'add_entry',
        name: 'Add Entry',
        targetEntityId: 'entry',
      ),
      SemanticAction(
        id: 'update_entry',
        name: 'Update Entry',
        targetEntityId: 'entry',
        actionType: BlueprintActionType.update,
      ),
      SemanticAction(
        id: 'delete_entry',
        name: 'Delete Entry',
        targetEntityId: 'entry',
        actionType: BlueprintActionType.delete,
      ),
    ],
  );

  /// Zero `requiredCapabilities` — `OfflinePlanner` only escalates past
  /// `fullyOffline` when a capability needs `http`/`ai`/`knowledge`
  /// (`lib/software_architect/capability_security_planner.dart`), so this
  /// is genuinely, structurally offline-first, not just unlabeled CRUD.
  static SemanticApp _offlineFirstApp() => SemanticApp(
    name: 'Offline Notes',
    purpose: 'Take notes with no network dependency',
    entities: const [
      SemanticEntity(
        id: 'note',
        name: 'Note',
        displayField: 'body',
        fields: [
          SemanticField(
            id: 'body',
            name: 'Body',
            type: BlueprintFieldType.text,
            required: true,
          ),
        ],
      ),
    ],
    views: const [
      SemanticView(
        id: 'notes_list',
        name: 'Notes',
        purpose: 'list',
        sourceEntityId: 'note',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
    ],
    actions: const [
      SemanticAction(id: 'add_note', name: 'Add Note', targetEntityId: 'note'),
    ],
  );

  static SemanticApp _dashboardApp() => SemanticApp(
    name: 'Sales Dashboard',
    purpose: 'Track sales with an overview',
    entities: const [
      SemanticEntity(
        id: 'sale',
        name: 'Sale',
        displayField: 'title',
        fields: [
          SemanticField(
            id: 'title',
            name: 'Title',
            type: BlueprintFieldType.text,
            required: true,
          ),
          SemanticField(
            id: 'amount',
            name: 'Amount',
            type: BlueprintFieldType.decimal,
          ),
        ],
      ),
    ],
    views: const [
      SemanticView(
        id: 'sales_list',
        name: 'Sales',
        purpose: 'list',
        sourceEntityId: 'sale',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
      SemanticView(
        id: 'sales_overview',
        name: 'Overview',
        purpose: 'dashboard',
        sourceEntityId: 'sale',
        viewType: BlueprintViewType.dashboard,
      ),
    ],
    actions: const [
      SemanticAction(id: 'add_sale', name: 'Add Sale', targetEntityId: 'sale'),
    ],
  );

  static SemanticApp _calendarApp() => SemanticApp(
    name: 'Events',
    purpose: 'Track scheduled events on a calendar',
    entities: const [
      SemanticEntity(
        id: 'event',
        name: 'Event',
        displayField: 'title',
        fields: [
          SemanticField(
            id: 'title',
            name: 'Title',
            type: BlueprintFieldType.text,
            required: true,
          ),
        ],
      ),
    ],
    views: const [
      SemanticView(
        id: 'events_list',
        name: 'Events',
        purpose: 'list',
        sourceEntityId: 'event',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
      SemanticView(
        id: 'events_calendar',
        name: 'Calendar',
        purpose: 'calendar',
        sourceEntityId: 'event',
        viewType: BlueprintViewType.calendar,
      ),
    ],
    actions: const [
      SemanticAction(
        id: 'add_event',
        name: 'Add Event',
        targetEntityId: 'event',
      ),
    ],
  );

  static SemanticApp _settingsApp() => SemanticApp(
    name: 'Preferences',
    purpose: 'Track configurable items with a settings screen',
    entities: const [
      SemanticEntity(
        id: 'item',
        name: 'Item',
        displayField: 'name',
        fields: [
          SemanticField(
            id: 'name',
            name: 'Name',
            type: BlueprintFieldType.text,
            required: true,
          ),
        ],
      ),
    ],
    views: const [
      SemanticView(
        id: 'items_list',
        name: 'Items',
        purpose: 'list',
        sourceEntityId: 'item',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
      SemanticView(
        id: 'items_settings',
        name: 'Settings',
        purpose: 'settings',
        sourceEntityId: 'item',
        viewType: BlueprintViewType.settings,
      ),
    ],
    actions: const [
      SemanticAction(id: 'add_item', name: 'Add Item', targetEntityId: 'item'),
    ],
  );

  static SemanticApp _summaryApp() => SemanticApp(
    name: 'Expense Summary',
    purpose: 'Track expenses with a summary screen',
    entities: const [
      SemanticEntity(
        id: 'expense',
        name: 'Expense',
        displayField: 'title',
        fields: [
          SemanticField(
            id: 'title',
            name: 'Title',
            type: BlueprintFieldType.text,
            required: true,
          ),
        ],
      ),
    ],
    views: const [
      SemanticView(
        id: 'expenses_list',
        name: 'Expenses',
        purpose: 'list',
        sourceEntityId: 'expense',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
      SemanticView(
        id: 'expenses_summary',
        name: 'Summary',
        purpose: 'summary',
        sourceEntityId: 'expense',
        viewType: BlueprintViewType.summary,
      ),
    ],
    actions: const [
      SemanticAction(
        id: 'add_expense',
        name: 'Add Expense',
        targetEntityId: 'expense',
      ),
    ],
  );

  static SemanticApp _multiEntityApp() => SemanticApp(
    name: 'Projects and Tasks',
    purpose: 'Track two independent, unrelated entities',
    entities: const [
      SemanticEntity(
        id: 'project',
        name: 'Project',
        displayField: 'name',
        fields: [
          SemanticField(
            id: 'name',
            name: 'Name',
            type: BlueprintFieldType.text,
            required: true,
          ),
        ],
      ),
      SemanticEntity(
        id: 'note',
        name: 'Note',
        displayField: 'body',
        fields: [
          SemanticField(
            id: 'body',
            name: 'Body',
            type: BlueprintFieldType.text,
            required: true,
          ),
        ],
      ),
    ],
    views: const [
      SemanticView(
        id: 'projects_list',
        name: 'Projects',
        purpose: 'list',
        sourceEntityId: 'project',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
      SemanticView(
        id: 'notes_list',
        name: 'Notes',
        purpose: 'list',
        sourceEntityId: 'note',
        viewType: BlueprintViewType.list,
      ),
    ],
    actions: const [
      SemanticAction(
        id: 'add_project',
        name: 'Add Project',
        targetEntityId: 'project',
      ),
      SemanticAction(id: 'add_note', name: 'Add Note', targetEntityId: 'note'),
    ],
  );

  /// A real reference field (`author` -> `author`) — the same
  /// relationship signal `_planComponents`/`ForeignKeyConstraint` already
  /// derive from (R17).
  static SemanticApp _relationshipsApp() => SemanticApp(
    name: 'Library',
    purpose: 'Books authored by authors',
    entities: const [
      SemanticEntity(
        id: 'author',
        name: 'Author',
        displayField: 'name',
        fields: [
          SemanticField(
            id: 'name',
            name: 'Name',
            type: BlueprintFieldType.text,
            required: true,
          ),
        ],
      ),
      SemanticEntity(
        id: 'book',
        name: 'Book',
        displayField: 'title',
        fields: [
          SemanticField(
            id: 'title',
            name: 'Title',
            type: BlueprintFieldType.text,
            required: true,
          ),
          SemanticField(
            id: 'author',
            name: 'Author',
            type: BlueprintFieldType.reference,
            referenceEntityId: 'author',
          ),
        ],
      ),
    ],
    views: const [
      SemanticView(
        id: 'authors_list',
        name: 'Authors',
        purpose: 'list',
        sourceEntityId: 'author',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
      SemanticView(
        id: 'books_list',
        name: 'Books',
        purpose: 'list',
        sourceEntityId: 'book',
        viewType: BlueprintViewType.list,
      ),
    ],
    actions: const [
      SemanticAction(
        id: 'add_author',
        name: 'Add Author',
        targetEntityId: 'author',
      ),
      SemanticAction(id: 'add_book', name: 'Add Book', targetEntityId: 'book'),
    ],
  );

  /// `notifications` is a real, known capability with a real required
  /// permission (`lib/software_architect/capability_security_planner.dart`
  /// `_knownCapabilities`) — a genuine `PermissionDecision`, not a
  /// fabricated one.
  static SemanticApp _permissionsApp() => SemanticApp(
    name: 'Reminders',
    purpose: 'Reminders that need notification permission',
    entities: const [
      SemanticEntity(
        id: 'reminder',
        name: 'Reminder',
        displayField: 'title',
        fields: [
          SemanticField(
            id: 'title',
            name: 'Title',
            type: BlueprintFieldType.text,
            required: true,
          ),
        ],
      ),
    ],
    views: const [
      SemanticView(
        id: 'reminders_list',
        name: 'Reminders',
        purpose: 'list',
        sourceEntityId: 'reminder',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
    ],
    actions: const [
      SemanticAction(
        id: 'add_reminder',
        name: 'Add Reminder',
        targetEntityId: 'reminder',
      ),
    ],
    requiredCapabilities: const ['notifications'],
  );

  /// `clock` is a real, known capability with NO required permission —
  /// distinguishes "uses a real capability" from "permissions" above.
  static SemanticApp _capabilitiesApp() => SemanticApp(
    name: 'Streak Tracker',
    purpose: 'Track daily streaks using the clock capability',
    entities: const [
      SemanticEntity(
        id: 'streak',
        name: 'Streak',
        displayField: 'name',
        fields: [
          SemanticField(
            id: 'name',
            name: 'Name',
            type: BlueprintFieldType.text,
            required: true,
          ),
        ],
      ),
    ],
    views: const [
      SemanticView(
        id: 'streaks_list',
        name: 'Streaks',
        purpose: 'list',
        sourceEntityId: 'streak',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
    ],
    actions: const [
      SemanticAction(
        id: 'add_streak',
        name: 'Add Streak',
        targetEntityId: 'streak',
      ),
    ],
    requiredCapabilities: const ['clock'],
  );

  /// Three list-having entities — a real, richer bottom-navigation
  /// scenario than `multi_entity`'s two.
  static SemanticApp _navigationApp() => SemanticApp(
    name: 'Home Hub',
    purpose: 'Three independent sections navigable from one bottom bar',
    entities: const [
      SemanticEntity(
        id: 'chore',
        name: 'Chore',
        displayField: 'name',
        fields: [
          SemanticField(
            id: 'name',
            name: 'Name',
            type: BlueprintFieldType.text,
            required: true,
          ),
        ],
      ),
      SemanticEntity(
        id: 'meal',
        name: 'Meal',
        displayField: 'name',
        fields: [
          SemanticField(
            id: 'name',
            name: 'Name',
            type: BlueprintFieldType.text,
            required: true,
          ),
        ],
      ),
      SemanticEntity(
        id: 'guest',
        name: 'Guest',
        displayField: 'name',
        fields: [
          SemanticField(
            id: 'name',
            name: 'Name',
            type: BlueprintFieldType.text,
            required: true,
          ),
        ],
      ),
    ],
    views: const [
      SemanticView(
        id: 'chores_list',
        name: 'Chores',
        purpose: 'list',
        sourceEntityId: 'chore',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
      SemanticView(
        id: 'meals_list',
        name: 'Meals',
        purpose: 'list',
        sourceEntityId: 'meal',
        viewType: BlueprintViewType.list,
      ),
      SemanticView(
        id: 'guests_list',
        name: 'Guests',
        purpose: 'list',
        sourceEntityId: 'guest',
        viewType: BlueprintViewType.list,
      ),
    ],
    actions: const [
      SemanticAction(
        id: 'add_chore',
        name: 'Add Chore',
        targetEntityId: 'chore',
      ),
      SemanticAction(id: 'add_meal', name: 'Add Meal', targetEntityId: 'meal'),
      SemanticAction(
        id: 'add_guest',
        name: 'Add Guest',
        targetEntityId: 'guest',
      ),
    ],
  );

  /// `http` needs no known-permission entry, but `OfflinePlanner` treats
  /// it (with `ai`/`knowledge`) as real network signal, escalating
  /// `OfflineCapability` past `fullyOffline` and, transitively,
  /// `DeploymentSpecificationModel.requiresBackend` to `true`
  /// (`backend_engineering_planner.dart` line ~139).
  static SemanticApp _backendRequiredApp() => SemanticApp(
    name: 'Synced Contacts',
    purpose: 'Contacts synced over the network',
    entities: const [
      SemanticEntity(
        id: 'contact',
        name: 'Contact',
        displayField: 'name',
        fields: [
          SemanticField(
            id: 'name',
            name: 'Name',
            type: BlueprintFieldType.text,
            required: true,
          ),
        ],
      ),
    ],
    views: const [
      SemanticView(
        id: 'contacts_list',
        name: 'Contacts',
        purpose: 'list',
        sourceEntityId: 'contact',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
    ],
    actions: const [
      SemanticAction(
        id: 'add_contact',
        name: 'Add Contact',
        targetEntityId: 'contact',
      ),
    ],
    requiredCapabilities: const ['http'],
  );

  /// A real app mixing CRUD + dashboard + settings — "composite" in the
  /// sense both pipelines already support (multiple view kinds on one
  /// entity), never a fabricated `SemanticViewSection`/sub-component
  /// concept (R21's own honest finding: legacy never reads `sections`).
  static SemanticApp _compositeApp() => SemanticApp(
    name: 'Task Board',
    purpose: 'Track tasks with an overview and settings',
    entities: const [
      SemanticEntity(
        id: 'task',
        name: 'Task',
        displayField: 'title',
        fields: [
          SemanticField(
            id: 'title',
            name: 'Title',
            type: BlueprintFieldType.text,
            required: true,
          ),
          SemanticField(
            id: 'priority',
            name: 'Priority',
            type: BlueprintFieldType.integer,
          ),
        ],
      ),
    ],
    views: const [
      SemanticView(
        id: 'tasks_list',
        name: 'Tasks',
        purpose: 'list',
        sourceEntityId: 'task',
        viewType: BlueprintViewType.list,
        isDefault: true,
      ),
      SemanticView(
        id: 'tasks_dashboard',
        name: 'Overview',
        purpose: 'dashboard',
        sourceEntityId: 'task',
        viewType: BlueprintViewType.dashboard,
      ),
      SemanticView(
        id: 'tasks_settings',
        name: 'Settings',
        purpose: 'settings',
        sourceEntityId: 'task',
        viewType: BlueprintViewType.settings,
      ),
    ],
    actions: const [
      SemanticAction(id: 'add_task', name: 'Add Task', targetEntityId: 'task'),
      SemanticAction(
        id: 'update_task',
        name: 'Update Task',
        targetEntityId: 'task',
        actionType: BlueprintActionType.update,
      ),
    ],
  );
}
