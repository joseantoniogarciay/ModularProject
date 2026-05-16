# ModularProject

## Stack & reglas no negociables

- **UI**: UIKit. No SwiftUI.
- **Persistencia**: sin CoreData. Si se necesita persistencia, proponer alternativa antes de implementar.
- **Lenguaje**: Swift 6 (`SWIFT_VERSION = 6.0`).
- **Concurrencia**:
  - `SWIFT_STRICT_CONCURRENCY = complete` (data-race safety completo).
  - `SWIFT_APPROACHABLE_CONCURRENCY = YES` (Approachable Concurrency de Xcode 26).
  - Aplicar la skill `swift-concurrency` (`.claude/skills/swift-concurrency/`) en cualquier cambio que toque tareas, actors, `@MainActor`, `Sendable`, async/await o diagnósticos de concurrencia.
- **iOS deployment target**: 16.0.
- **Build system**: Tuist 4 (workspace generado). No editar `.xcodeproj` a mano: cambiar `Project.swift` / helpers y regenerar con `tuist generate`.

## Arquitectura modular

```
ModularProject/
├── App/              # Target app (UIKit). Composition root: cablea DI.
├── Core/             # Framework. Contratos (protocols) + modelos Sendable + utilidades puras.
├── Networking/       # Framework. Implementa APIClient (de Core) con URLSession.
├── Features/         # Una carpeta por feature. Cada feature es su propio Project.swift.
├── Tuist/
│   └── ProjectDescriptionHelpers/Module.swift   # Helper Project.framework + Settings.modular
├── Workspace.swift
└── .claude/skills/   # Skills locales para Claude Code (swift-concurrency).
```

### Reglas de dependencias

- **Core**: no depende de nadie. No importa UIKit ni Networking.
- **Networking**: depende solo de `Core`.
- **Features/<X>**: depende solo de `Core`. **Nunca** depende de `Networking` ni de otra Feature.
- **App**: depende de todo. Es el único lugar donde se instancian implementaciones concretas (DI).

### Cómo añadir una Feature

1. Crear `Features/<Nombre>/Project.swift` con `Project.framework(name: "<Nombre>", dependencies: [.project(target: "Core", path: "../../Core")])`.
2. Crear `Features/<Nombre>/Sources/`.
3. `tuist generate`.

### Cómo añadir un contrato

Va en `Core/Sources/` como `protocol X: Sendable`. La implementación vive en el módulo correspondiente (Networking, Persistence, etc.). El cableado se hace en `App`.

## Comandos habituales

```bash
tuist generate                # regenera workspace
tuist generate --no-open      # sin abrir Xcode
tuist clean                   # limpia caché de generación
xcodebuild -workspace ModularProject.xcworkspace -scheme App \
  -destination 'generic/platform=iOS Simulator' build
```

## Convenciones de código

- Mensajes de commit en inglés.
- Tipos públicos cruzando módulos: `Sendable` siempre que sea posible.
- `@MainActor` solo cuando el tipo es genuinamente UI-bound. Justificar en review.
- Preferir `actor` para estado mutable compartido sobre locks/queues.
- No usar `@unchecked Sendable` ni `nonisolated(unsafe)` sin invariante documentado y plan de retirada.
