# knowledge/

WebWeaveX boundary and knowledge providers: managing external knowledge and data sources.

## What belongs here

- Knowledge provider implementations
- WebWeaveX integration boundary
- Knowledge graph and indexing
- External data source connectors
- Knowledge caching and refresh

## What does NOT belong here

- Core knowledge interfaces (use `core/contracts/`)
- Kernel knowledge consumption (use `kernel/`)
- Storage/persistence (use `storage/`)

## Key interfaces

- `KnowledgeProvider` (from `core/contracts/`)
- `WebWeaveXBoundary`
- `KnowledgeGraph`
- `DataSourceConnector`
