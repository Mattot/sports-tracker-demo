# SportRecord Localization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract every hardcoded user-facing string in the `SportRecord` package into a String Catalog resolved against `Bundle.module`, behind a typed `L10n` accessor, and ship **English + Czech + Slovak** with no change to the English UI.

**Architecture:** One `.xcstrings` catalog at the target root (`Sources/SportRecord/Resources/`) holding `en` (source) + `cs` + `sk`, a caseless `L10n` enum in `Presentation/Localization/` returning `String` via `String(localized:bundle:.module)`, and call-site migration in the two screens + shared enums. `Bundle.module` resolves the locale per device/scheme language, independent of the App target.

**Tech Stack:** Swift 6, SwiftUI, String Catalogs (`.xcstrings`), SwiftPM resources, Swift Testing.

---

## Conventions & assumptions

- **Repo root:** `/Users/matusselecky/Documents/Work/Etnetera/sports-tracker`. Paths below are relative to it.
- **Design source of truth:** [docs/superpowers/specs/2026-07-15-sportrecord-localization-design.md](../specs/2026-07-15-sportrecord-localization-design.md) — the full key map lives there.
- **Test runner:** `make test-sportrecord` (pins `iPhone 16 Pro, OS=18.5`). Build check: `make build`. Treat **exit code 0 as success** — the banner may be suppressed; `echo "EXIT=$?"`.
- **Swift Testing** (`import Testing`, `@Test`, `#expect`), not XCTest. New tests append to the Presentation test folder.
- **Verbatim-String rule:** every migrated call site passes an `L10n.*` `String`. SwiftUI controls render it via their `StringProtocol` (verbatim) overloads — no double-localization. Do **not** wrap `L10n.*` values in `LocalizedStringKey`.
- **Catalog is authored by hand** (the `L10n` helper hides literals from Xcode extraction). JSON for each entry is given in full.
- **Commits:** one per task. End the commit body with:
  `Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>`
- **Do NOT reword** `addRecord.saveError.remote` / `.local`: `AddRecordViewModelTests` asserts they contain `"backend"` / `"locally"`.

## File structure

```
Modules/SportRecord/
├── Package.swift                                   # + defaultLocalization, + resources
└── Sources/SportRecord/
    ├── Resources/
    │   └── Localizable.xcstrings                   # NEW — all keys, en only
    └── Presentation/
        ├── Localization/
        │   └── L10n.swift                          # NEW — typed accessor
        ├── List/View/RecordsListView.swift         # migrate call sites
        ├── List/ViewModel/RecordsListState.swift   # RecordsFilter.title → L10n
        ├── List/ViewModel/RecordsListViewModel.swift # delete-error messages → L10n
        ├── AddRecord/View/AddRecordView.swift       # migrate call sites
        ├── AddRecord/View/DurationPicker.swift      # units → L10n
        ├── AddRecord/ViewModel/AddRecordViewModel.swift # save-error messages → L10n
        └── Shared/StorageType+Style.swift           # label → L10n
Modules/SportRecord/Tests/SportRecordTests/Presentation/LocalizationTests.swift  # NEW

SportsTracker/                                        # App target — per-app language switcher (Task 5)
├── SportsTracker.xcodeproj/project.pbxproj           # + cs/sk in knownRegions, register resource
└── SportsTracker/Resources/InfoPlist.xcstrings       # NEW — declares CFBundleLocalizations en/cs/sk
```

---

## Task 1: Wire up the resource pipeline (one string, end-to-end)

Prove `Package.swift` → `.xcstrings` → `Bundle.module` → `L10n` resolves before migrating anything.

**Files:**
- Modify: `Modules/SportRecord/Package.swift`
- Create: `Modules/SportRecord/Sources/SportRecord/Resources/Localizable.xcstrings`
- Create: `Modules/SportRecord/Sources/SportRecord/Presentation/Localization/L10n.swift`
- Create: `Modules/SportRecord/Tests/SportRecordTests/Presentation/LocalizationTests.swift`

- [ ] **Step 1: Add default localization + resources to the target**

In `Modules/SportRecord/Package.swift`, add `defaultLocalization` to the `Package(...)` init (right after `name:`) and a `resources:` argument to the `SportRecord` target.

```swift
let package = Package(
    name: "SportRecord",
    defaultLocalization: "en",
    platforms: [.iOS(.v18)],
    products: [
        .library(name: "SportRecord", targets: ["SportRecord"]),
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.16.0"),
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", exact: "0.65.0"),
    ],
    targets: [
        .target(
            name: "SportRecord",
            dependencies: [
                .product(name: "Core", package: "Core"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
            ],
            resources: [.process("Resources")],
            plugins: [.plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")]
        ),
        .testTarget(
            name: "SportRecordTests",
            dependencies: ["SportRecord"]
        ),
    ]
)
```

- [ ] **Step 2: Create the catalog with the single `list.title` entry**

Create `Modules/SportRecord/Sources/SportRecord/Resources/Localizable.xcstrings`. `sourceLanguage` stays `en`; every key carries `en` + `cs` + `sk`:

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "list.title" : {
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Sport Records" } },
        "cs" : { "stringUnit" : { "state" : "translated", "value" : "Sportovní záznamy" } },
        "sk" : { "stringUnit" : { "state" : "translated", "value" : "Športové záznamy" } }
      }
    }
  },
  "version" : "1.0"
}
```

- [ ] **Step 3: Create the `L10n` accessor scaffold**

Create `Modules/SportRecord/Sources/SportRecord/Presentation/Localization/L10n.swift`:

```swift
import Foundation

/// Typed access to the package's localized strings. Every value resolves against
/// `Bundle.module` so the feature stays self-contained. Keys and English source
/// live in `Resources/Localizable.xcstrings`; this enum is the only place that
/// names them. When the module count grows, replace this hand-written file with
/// SwiftGen output generated from the catalog.
enum L10n {
    enum List {
        static var title: String { str("list.title") }
    }
}

/// Resolves a catalog key against the package bundle.
private func str(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}
```

- [ ] **Step 4: Write the failing test**

Create `Modules/SportRecord/Tests/SportRecordTests/Presentation/LocalizationTests.swift`:

```swift
import Testing
@testable import SportRecord

@Suite("Localization")
struct LocalizationTests {
    @Test func listTitleResolvesToEnglishNotKey() {
        #expect(L10n.List.title == "Sport Records")
    }
}
```

- [ ] **Step 5: Run the test — expect PASS**

Run: `make test-sportrecord`
Expected: exit code 0. (If `list.title` returned the raw key `"list.title"`, the resource wiring is wrong — recheck Step 1/2.)

- [ ] **Step 6: Commit**

```bash
git add Modules/SportRecord/Package.swift \
        Modules/SportRecord/Sources/SportRecord/Resources/Localizable.xcstrings \
        Modules/SportRecord/Sources/SportRecord/Presentation/Localization/L10n.swift \
        Modules/SportRecord/Tests/SportRecordTests/Presentation/LocalizationTests.swift
git commit -m "feat(sportrecord): add localization pipeline (catalog + L10n) with list title"
```

---

## Task 2: List screen strings

Add all `list.*`, `filter.*`, and `common.*` catalog entries + accessors, then migrate the List call sites and `RecordsFilter.title` / delete-error messages.

**Files:**
- Modify: `Modules/SportRecord/Sources/SportRecord/Resources/Localizable.xcstrings`
- Modify: `Modules/SportRecord/Sources/SportRecord/Presentation/Localization/L10n.swift`
- Modify: `Modules/SportRecord/Sources/SportRecord/Presentation/List/ViewModel/RecordsListState.swift`
- Modify: `Modules/SportRecord/Sources/SportRecord/Presentation/List/ViewModel/RecordsListViewModel.swift`
- Modify: `Modules/SportRecord/Sources/SportRecord/Presentation/List/View/RecordsListView.swift`
- Modify: `Modules/SportRecord/Tests/SportRecordTests/Presentation/LocalizationTests.swift`

- [ ] **Step 1: Write failing tests for filter titles + delete-error mapping**

Append to `LocalizationTests.swift` inside the `LocalizationTests` struct:

```swift
    @Test func filterTitlesResolve() {
        #expect(RecordsFilter.all.title == "All")
        #expect(RecordsFilter.local.title == "Local")
        #expect(RecordsFilter.remote.title == "Remote")
    }

    @Test func commonStringsResolve() {
        #expect(L10n.Common.ok == "OK")
        #expect(L10n.Common.cancel == "Cancel")
        #expect(L10n.Common.delete == "Delete")
    }

    @Test func deleteSelectionButtonInterpolatesCount() {
        #expect(L10n.List.deleteSelectionButton(3) == "Delete Records (3)")
    }
```

- [ ] **Step 2: Run — expect FAIL** (`RecordsFilter.title` still returns hardcoded values but `L10n.Common`/`L10n.List.deleteSelectionButton` don't exist → compile error).

Run: `make test-sportrecord` → Expected: build failure (unresolved `L10n.Common`, `L10n.List.deleteSelectionButton`).

- [ ] **Step 3: Add the List/filter/common entries to the catalog**

In `Localizable.xcstrings`, add these keys alongside `list.title` (inside `"strings"`). Keep valid JSON (commas between entries). Every key carries `en` + `cs` + `sk`:

```json
    "list.deleteError.title" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Delete failed" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Smazání se nezdařilo" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Odstránenie zlyhalo" } }
    } },
    "list.loadError.title" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Couldn't Load Records" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Nepodařilo se načíst záznamy" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Nepodarilo sa načítať záznamy" } }
    } },
    "list.loadError.message" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Something went wrong reaching your data." } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Při načítání dat došlo k chybě." } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Pri načítaní údajov došlo k chybe." } }
    } },
    "list.empty.title" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "No Sport Records" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Žádné sportovní záznamy" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Žiadne športové záznamy" } }
    } },
    "list.empty.message" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Add your first activity to see it here." } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Přidejte svou první aktivitu a zobrazí se zde." } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Pridajte svoju prvú aktivitu a zobrazí sa tu." } }
    } },
    "list.empty.filtered.title" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "No %@ Records" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Žádné %@ záznamy" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Žiadne %@ záznamy" } }
    } },
    "list.empty.filtered.message" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "You have no %@ records yet." } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Zatím nemáte žádné %@ záznamy." } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Zatiaľ nemáte žiadne %@ záznamy." } }
    } },
    "list.banner.offline" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "You're offline — showing local records." } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Jste offline — zobrazují se místní záznamy." } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Ste offline — zobrazujú sa miestne záznamy." } }
    } },
    "list.banner.remoteUnavailable" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Couldn't reach remote — showing local records." } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Vzdálené úložiště není dostupné — zobrazují se místní záznamy." } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Vzdialené úložisko nie je dostupné — zobrazujú sa miestne záznamy." } }
    } },
    "list.add.button" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Add Record" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Přidat záznam" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Pridať záznam" } }
    } },
    "list.deleteSelection.button" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Delete Records (%lld)" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Smazat záznamy (%lld)" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Odstrániť záznamy (%lld)" } }
    } },
    "list.deleteConfirm.title %lld" : { "localizations" : {
      "en" : { "variations" : { "plural" : {
        "one" : { "stringUnit" : { "state" : "translated", "value" : "Delete %lld record?" } },
        "other" : { "stringUnit" : { "state" : "translated", "value" : "Delete %lld records?" } }
      } } },
      "cs" : { "variations" : { "plural" : {
        "one" : { "stringUnit" : { "state" : "translated", "value" : "Smazat %lld záznam?" } },
        "few" : { "stringUnit" : { "state" : "translated", "value" : "Smazat %lld záznamy?" } },
        "other" : { "stringUnit" : { "state" : "translated", "value" : "Smazat %lld záznamů?" } }
      } } },
      "sk" : { "variations" : { "plural" : {
        "one" : { "stringUnit" : { "state" : "translated", "value" : "Odstrániť %lld záznam?" } },
        "few" : { "stringUnit" : { "state" : "translated", "value" : "Odstrániť %lld záznamy?" } },
        "other" : { "stringUnit" : { "state" : "translated", "value" : "Odstrániť %lld záznamov?" } }
      } } }
    } },
    "list.deleteError.both" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Couldn't delete some records. Check your connection and try again." } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Některé záznamy se nepodařilo smazat. Zkontrolujte připojení a zkuste to znovu." } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Niektoré záznamy sa nepodarilo odstrániť. Skontrolujte pripojenie a skúste to znova." } }
    } },
    "list.deleteError.remote" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Couldn't delete remote records. You may be offline." } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Vzdálené záznamy se nepodařilo smazat. Možná jste offline." } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Vzdialené záznamy sa nepodarilo odstrániť. Možno ste offline." } }
    } },
    "list.deleteError.local" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Couldn't delete local records. Please try again." } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Místní záznamy se nepodařilo smazat. Zkuste to prosím znovu." } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Miestne záznamy sa nepodarilo odstrániť. Skúste to prosím znova." } }
    } },
    "list.deleteError.unknown" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Couldn't delete records." } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Záznamy se nepodařilo smazat." } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Záznamy sa nepodarilo odstrániť." } }
    } },
    "filter.all" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "All" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Všechny" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Všetky" } }
    } },
    "filter.local" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Local" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Místní" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Miestne" } }
    } },
    "filter.remote" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Remote" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Vzdálené" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Vzdialené" } }
    } },
    "common.ok" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "OK" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "OK" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "OK" } }
    } },
    "common.cancel" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Cancel" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Zrušit" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Zrušiť" } }
    } },
    "common.delete" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Delete" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Smazat" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Odstrániť" } }
    } },
    "common.done" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Done" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Hotovo" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Hotovo" } }
    } },
    "common.edit" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Edit" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Upravit" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Upraviť" } }
    } },
    "common.tryAgain" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Try Again" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Zkusit znovu" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Skúsiť znova" } }
    } },
```

- [ ] **Step 4: Extend `L10n` with `List`, `Filter`, `Common`**

Replace the body of `L10n.swift` (keep the `str` helper and file header) so it reads:

```swift
enum L10n {
    enum List {
        static var title: String { str("list.title") }
        static var deleteFailedTitle: String { str("list.deleteError.title") }
        static var loadErrorTitle: String { str("list.loadError.title") }
        static var loadErrorMessage: String { str("list.loadError.message") }
        static var emptyTitle: String { str("list.empty.title") }
        static var emptyMessage: String { str("list.empty.message") }
        static var bannerOffline: String { str("list.banner.offline") }
        static var bannerRemoteUnavailable: String { str("list.banner.remoteUnavailable") }
        static var addButton: String { str("list.add.button") }
        static var deleteErrorBoth: String { str("list.deleteError.both") }
        static var deleteErrorRemote: String { str("list.deleteError.remote") }
        static var deleteErrorLocal: String { str("list.deleteError.local") }
        static var deleteErrorUnknown: String { str("list.deleteError.unknown") }

        static func emptyFilteredTitle(_ filter: String) -> String {
            String(format: str("list.empty.filtered.title"), filter)
        }
        static func emptyFilteredMessage(_ filter: String) -> String {
            String(format: str("list.empty.filtered.message"), filter)
        }
        static func deleteSelectionButton(_ count: Int) -> String {
            String(format: str("list.deleteSelection.button"), count)
        }
        static func deleteConfirmTitle(_ count: Int) -> String {
            String(localized: "list.deleteConfirm.title \(count)", bundle: .module)
        }
    }

    enum Filter {
        static var all: String { str("filter.all") }
        static var local: String { str("filter.local") }
        static var remote: String { str("filter.remote") }
    }

    enum Common {
        static var ok: String { str("common.ok") }
        static var cancel: String { str("common.cancel") }
        static var delete: String { str("common.delete") }
        static var done: String { str("common.done") }
        static var edit: String { str("common.edit") }
        static var tryAgain: String { str("common.tryAgain") }
    }
}
```

> Note: `str` uses `String.LocalizationValue`, so `str("list.empty.filtered.title")` returns the format string `"No %@ Records"`, which `String(format:)` then fills. `deleteConfirmTitle` uses interpolation so the plural variation resolves (generated key `list.deleteConfirm.title %lld`).

- [ ] **Step 5: Route `RecordsFilter.title` through `L10n`**

In `RecordsListState.swift`, replace the `title` computed property:

```swift
    public var title: String {
        switch self {
        case .all: L10n.Filter.all
        case .local: L10n.Filter.local
        case .remote: L10n.Filter.remote
        }
    }
```

- [ ] **Step 6: Route delete-error messages through `L10n`**

In `RecordsListViewModel.swift`, replace the `message(for stores:)` body:

```swift
    private func message(for stores: Set<StorageType>) -> String {
        switch (stores.contains(.local), stores.contains(.remote)) {
        case (true, true): L10n.List.deleteErrorBoth
        case (false, true): L10n.List.deleteErrorRemote
        case (true, false): L10n.List.deleteErrorLocal
        case (false, false): L10n.List.deleteErrorUnknown
        }
    }
```

- [ ] **Step 7: Migrate `RecordsListView` call sites**

Apply these exact replacements in `RecordsListView.swift`:

- `.navigationTitle("Sport Records")` → `.navigationTitle(L10n.List.title)`
- `"Delete failed"` (alert title) → `L10n.List.deleteFailedTitle`
- `Button("OK", role: .cancel) {}` → `Button(L10n.Common.ok, role: .cancel) {}`
- `.failed(title: "Couldn't Load Records", message: "Something went wrong reaching your data.")` → `.failed(title: L10n.List.loadErrorTitle, message: L10n.List.loadErrorMessage)`
- `.init(title: "Try Again")` → `.init(title: L10n.Common.tryAgain)`
- `Label("Delete", systemImage: "trash")` → `Label(L10n.Common.delete, systemImage: "trash")`
- empty filtered branch:
  ```swift
  ? .empty(
      title: L10n.List.emptyFilteredTitle(viewModel.filter.title),
      message: L10n.List.emptyFilteredMessage(viewModel.filter.title.lowercased())
  )
  ```
- `.empty(title: "No Sport Records", message: "Add your first activity to see it here.")` → `.empty(title: L10n.List.emptyTitle, message: L10n.List.emptyMessage)`
- `bannerRow("You're offline — showing local records.", style: .warning)` → `bannerRow(L10n.List.bannerOffline, style: .warning)`
- `bannerRow("Couldn't reach remote — showing local records.", style: .info)` → `bannerRow(L10n.List.bannerRemoteUnavailable, style: .info)`
- `Button(viewModel.isEditing ? "Done" : "Edit")` → `Button(viewModel.isEditing ? L10n.Common.done : L10n.Common.edit)`
- `Label("Add Record", systemImage: "plus")` → `Label(L10n.List.addButton, systemImage: "plus")`
- `Text("Delete Records (\(viewModel.selection.count))")` → `Text(L10n.List.deleteSelectionButton(viewModel.selection.count))`
- `"Delete \(viewModel.selection.count) record(s)?"` (confirmationDialog title) → `L10n.List.deleteConfirmTitle(viewModel.selection.count)`
- inside the dialog: `Button("Delete", role: .destructive)` → `Button(L10n.Common.delete, role: .destructive)` and `Button("Cancel", role: .cancel) {}` → `Button(L10n.Common.cancel, role: .cancel) {}`

- [ ] **Step 8: Run tests — expect PASS**

Run: `make test-sportrecord` → Expected: exit code 0 (new List/filter/common tests pass; existing VM tests unaffected).

- [ ] **Step 9: Commit**

```bash
git add Modules/SportRecord/Sources/SportRecord/Resources/Localizable.xcstrings \
        Modules/SportRecord/Sources/SportRecord/Presentation/Localization/L10n.swift \
        Modules/SportRecord/Sources/SportRecord/Presentation/List \
        Modules/SportRecord/Tests/SportRecordTests/Presentation/LocalizationTests.swift
git commit -m "feat(sportrecord): localize the records list screen"
```

---

## Task 3: Add screen strings + shared `StorageType`

Add `addRecord.*` and `storageType.*` entries, then migrate the Add screen, `DurationPicker`, `StorageType.label`, and `AddRecordViewModel` messages.

**Files:**
- Modify: `Modules/SportRecord/Sources/SportRecord/Resources/Localizable.xcstrings`
- Modify: `Modules/SportRecord/Sources/SportRecord/Presentation/Localization/L10n.swift`
- Modify: `Modules/SportRecord/Sources/SportRecord/Presentation/Shared/StorageType+Style.swift`
- Modify: `Modules/SportRecord/Sources/SportRecord/Presentation/AddRecord/ViewModel/AddRecordViewModel.swift`
- Modify: `Modules/SportRecord/Sources/SportRecord/Presentation/AddRecord/View/AddRecordView.swift`
- Modify: `Modules/SportRecord/Sources/SportRecord/Presentation/AddRecord/View/DurationPicker.swift`
- Modify: `Modules/SportRecord/Tests/SportRecordTests/Presentation/LocalizationTests.swift`

- [ ] **Step 1: Write failing tests for storage label + save-error substrings**

Append inside `LocalizationTests`:

```swift
    @Test func storageLabelsResolve() {
        #expect(StorageType.local.label == "Local")
        #expect(StorageType.remote.label == "Remote")
    }

    @Test func saveErrorMessagesKeepAssertedSubstrings() {
        #expect(L10n.AddRecord.saveErrorRemote.contains("backend"))
        #expect(L10n.AddRecord.saveErrorLocal.contains("locally"))
    }
```

- [ ] **Step 2: Run — expect FAIL** (`L10n.AddRecord` undefined → build error).

Run: `make test-sportrecord` → Expected: build failure (unresolved `L10n.AddRecord`).

- [ ] **Step 3: Add Add-screen + storage entries to the catalog**

Add to `Localizable.xcstrings` (inside `"strings"`, valid commas). Every key carries `en` + `cs` + `sk`:

```json
    "addRecord.title" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Add Record" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Přidat záznam" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Pridať záznam" } }
    } },
    "addRecord.section.activity" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Activity" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Aktivita" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Aktivita" } }
    } },
    "addRecord.name.placeholder" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Name" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Název" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Názov" } }
    } },
    "addRecord.location.placeholder" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Location" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Místo" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Miesto" } }
    } },
    "addRecord.section.duration" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Duration" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Doba trvání" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Trvanie" } }
    } },
    "addRecord.section.storage" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Storage" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Úložiště" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Úložisko" } }
    } },
    "addRecord.storage.picker" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Select storage" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Vyberte úložiště" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Vyberte úložisko" } }
    } },
    "addRecord.saveError.title" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Couldn't Save" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Nepodařilo se uložit" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Nepodarilo sa uložiť" } }
    } },
    "addRecord.saveError.remote" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Couldn't save to the backend. You may be offline — check your connection and try again." } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Nepodařilo se uložit na server. Možná jste offline — zkontrolujte připojení a zkuste to znovu." } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Nepodarilo sa uložiť na server. Možno ste offline — skontrolujte pripojenie a skúste to znova." } }
    } },
    "addRecord.saveError.local" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Couldn't save locally. Please try again." } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Nepodařilo se uložit místně. Zkuste to prosím znovu." } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Nepodarilo sa uložiť miestne. Skúste to prosím znova." } }
    } },
    "addRecord.duration.hours" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "h" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "h" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "h" } }
    } },
    "addRecord.duration.minutes" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "m" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "m" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "m" } }
    } },
    "addRecord.duration.seconds" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "s" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "s" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "s" } }
    } },
    "storageType.local" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Local" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Místní" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Miestne" } }
    } },
    "storageType.remote" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Remote" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Vzdálené" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Vzdialené" } }
    } },
```

- [ ] **Step 4: Extend `L10n` with `AddRecord` and `Storage`**

Add these nested enums inside `L10n` (alongside `List`, `Filter`, `Common`):

```swift
    enum AddRecord {
        static var title: String { str("addRecord.title") }
        static var sectionActivity: String { str("addRecord.section.activity") }
        static var namePlaceholder: String { str("addRecord.name.placeholder") }
        static var locationPlaceholder: String { str("addRecord.location.placeholder") }
        static var sectionDuration: String { str("addRecord.section.duration") }
        static var sectionStorage: String { str("addRecord.section.storage") }
        static var storagePicker: String { str("addRecord.storage.picker") }
        static var saveErrorTitle: String { str("addRecord.saveError.title") }
        static var saveErrorRemote: String { str("addRecord.saveError.remote") }
        static var saveErrorLocal: String { str("addRecord.saveError.local") }

        enum Duration {
            static var hours: String { str("addRecord.duration.hours") }
            static var minutes: String { str("addRecord.duration.minutes") }
            static var seconds: String { str("addRecord.duration.seconds") }
        }
    }

    enum Storage {
        static var local: String { str("storageType.local") }
        static var remote: String { str("storageType.remote") }
    }
```

- [ ] **Step 5: Route `StorageType.label` through `L10n`**

In `StorageType+Style.swift`, replace the `label` property:

```swift
    var label: String {
        switch self {
        case .local: L10n.Storage.local
        case .remote: L10n.Storage.remote
        }
    }
```

- [ ] **Step 6: Route save-error messages through `L10n`**

In `AddRecordViewModel.swift`, replace the `message(for:)` body:

```swift
    private func message(for storageType: StorageType) -> String {
        switch storageType {
        case .remote: L10n.AddRecord.saveErrorRemote
        case .local: L10n.AddRecord.saveErrorLocal
        }
    }
```

- [ ] **Step 7: Migrate `AddRecordView` call sites**

Exact replacements in `AddRecordView.swift`:

- `Section("Activity")` → `Section(L10n.AddRecord.sectionActivity)`
- `TextField("Name", text: $viewModel.name)` → `TextField(L10n.AddRecord.namePlaceholder, text: $viewModel.name)`
- `TextField("Location", text: $viewModel.location)` → `TextField(L10n.AddRecord.locationPlaceholder, text: $viewModel.location)`
- `Section("Duration")` → `Section(L10n.AddRecord.sectionDuration)`
- `Section("Storage")` → `Section(L10n.AddRecord.sectionStorage)`
- `Picker("Select storage", selection: $viewModel.storageType)` → `Picker(L10n.AddRecord.storagePicker, selection: $viewModel.storageType)`
- `.navigationTitle("Add Record")` → `.navigationTitle(L10n.AddRecord.title)`
- `Button("Cancel") { onCancel() }` → `Button(L10n.Common.cancel) { onCancel() }`
- `Button("Save") {` → `Button(L10n.Common.save) {`
- `"Couldn't Save"` (alert title) → `L10n.AddRecord.saveErrorTitle`
- `Button("OK", role: .cancel) {}` → `Button(L10n.Common.ok, role: .cancel) {}`

- [ ] **Step 8: Add `common.save` (used first here)**

`Save` isn't referenced in Task 2. Add its catalog entry:

```json
    "common.save" : { "localizations" : {
      "en" : { "stringUnit" : { "state" : "translated", "value" : "Save" } },
      "cs" : { "stringUnit" : { "state" : "translated", "value" : "Uložit" } },
      "sk" : { "stringUnit" : { "state" : "translated", "value" : "Uložiť" } }
    } },
```

…and the accessor inside `L10n.Common`:

```swift
        static var save: String { str("common.save") }
```

- [ ] **Step 9: Migrate `DurationPicker` units**

In `DurationPicker.swift`, replace the three `wheel(...)` unit arguments and make the wheel label verbatim so it isn't treated as a localization key:

```swift
            wheel($hours, range: 0..<24, unit: L10n.AddRecord.Duration.hours)
            wheel($minutes, range: 0..<60, unit: L10n.AddRecord.Duration.minutes)
            wheel($seconds, range: 0..<60, unit: L10n.AddRecord.Duration.seconds)
```

and in the `wheel` builder:

```swift
            ForEach(range, id: \.self) { Text(verbatim: "\($0) \(unit)").tag($0) }
```

- [ ] **Step 10: Run tests — expect PASS**

Run: `make test-sportrecord` → Expected: exit code 0. The existing `AddRecordViewModelTests` substring assertions (`"backend"`, `"locally"`) pass because the English wording is preserved.

- [ ] **Step 11: Commit**

```bash
git add Modules/SportRecord/Sources/SportRecord/Resources/Localizable.xcstrings \
        Modules/SportRecord/Sources/SportRecord/Presentation \
        Modules/SportRecord/Tests/SportRecordTests/Presentation/LocalizationTests.swift
git commit -m "feat(sportrecord): localize the add-record screen and storage labels"
```

---

## Task 4: Full build, leak check, locale verification, and docs

- [ ] **Step 1: Full app build**

Run: `make build` → Expected: `** BUILD SUCCEEDED **` (or exit 0). Confirms the catalog compiles into the package resource bundle (with `en.lproj`/`cs.lproj`/`sk.lproj`) and the App target links it.

- [ ] **Step 2: Grep for any missed literals**

Run:
```bash
grep -rn '"[A-Z][a-z]' Modules/SportRecord/Sources/SportRecord/Presentation --include='*.swift' \
  | grep -v systemImage | grep -v 'L10n' | grep -v verbatim
```
Expected: no user-facing UI literals remain (SF Symbol names and non-UI strings are fine). If any surface, add a key + `en`/`cs`/`sk` values + accessor following the same pattern before continuing.

- [ ] **Step 3: Confirm the catalog produces all three locales**

After `make build`, verify the compiled bundle carries the localizations (path contains the `Debug-iphonesimulator` build products dir):
```bash
find ~/Library/Developer/Xcode/DerivedData -type d -name '*.lproj' -path '*SportRecord*' 2>/dev/null \
  | grep -Eo '(en|cs|sk)\.lproj' | sort -u
```
Expected: `cs.lproj`, `en.lproj`, `sk.lproj`. (If only `en.lproj` appears, the `cs`/`sk` entries didn't parse — recheck the catalog JSON.)

- [ ] **Step 4: Manual locale check (English, then Czech, then Slovak)**

There is **no automated UI test** for rendered locale (no snapshot infra), so verify by eye. In Xcode: **Product ▸ Scheme ▸ Edit Scheme ▸ Run ▸ Options ▸ App Language** — this injects `-AppleLanguages`, which `Bundle.module` honors without any App-target change. Run once per language and confirm on both screens:
- `en`: identical to today (no visible change).
- `cs` / `sk`: nav titles, filter segments (All/Local/Remote), offline & remote banners, load-error and save-error alerts, storage badges, and the **delete-confirm dialog at counts 1, 3, and 5** (proving `one`/`few`/`other` plural forms) all render translated with no English leaking through.

Record the outcome in the commit/PR notes. This step gates completion.

- [ ] **Step 5: Update `docs/ARCHITECTURE.md` folder organization**

In the "Folder organization" section of [docs/ARCHITECTURE.md](../../ARCHITECTURE.md), document the two new locations under `SportRecord`:
- `Sources/SportRecord/Resources/Localizable.xcstrings` — the module's String Catalog; `en` source plus `cs`/`sk` translations.
- `Presentation/Localization/L10n.swift` — typed accessor resolving keys against `Bundle.module`.

Add a one-line rule: *user-facing strings live only in `Presentation/`, are keyed in the catalog, and are read through `L10n`; nothing outside `Presentation/` imports `L10n`.*

- [ ] **Step 6: Update `CLAUDE.md` conventions**

Under "## Conventions" in [CLAUDE.md](../../../CLAUDE.md), add a bullet:
- *Localization: per-module String Catalog at `Sources/<Module>/Resources/Localizable.xcstrings` (`en` source + `cs`/`sk`), resolved via `Bundle.module` behind a typed `L10n` enum in `Presentation/Localization/`. Keys are dotted `lowerCamelCase` with no feature prefix (`list.title`, `storageType.remote`, `common.ok`); common strings stay under `common.*` until a second module needs them. Adding a locale is catalog-only. The App target declares supported languages (`knownRegions` + `InfoPlist.xcstrings` → `CFBundleLocalizations`) so iOS shows the per-app language switcher.*

- [ ] **Step 7: Commit**

```bash
git add docs/ARCHITECTURE.md CLAUDE.md
git commit -m "docs: document SportRecord localization convention (en/cs/sk)"
```

---

## Task 5: Per-app language switcher (App target)

Declare `cs`/`sk` on the **App** bundle so iOS surfaces Settings ▸ Sports Tracker ▸ Language. Nested package bundles don't count toward the app's language list, so this is a genuine App-target change: `knownRegions` + an app-level localized resource that populates `CFBundleLocalizations`.

> **Recommended tool:** do the file registration in **Xcode** (Project ▸ **Info** ▸ **Localizations** ▸ **+** Czech, Slovak), because it edits `project.pbxproj` correctly (variant group, build-file membership, `knownRegions`). Hand-editing `pbxproj` to register a new resource is error-prone. The exact artifacts Xcode should end up producing are given below so the result is verifiable regardless of how it's applied.

**Files:**
- Modify: `SportsTracker/SportsTracker.xcodeproj/project.pbxproj` (add `cs`, `sk` to `knownRegions`; register the new resource in the app target's Resources phase)
- Create: `SportsTracker/SportsTracker/Resources/InfoPlist.xcstrings`

- [ ] **Step 1: Add `cs`/`sk` to `knownRegions`**

In `project.pbxproj`, extend the project's `knownRegions` (currently `en`, `Base`):

```
			knownRegions = (
				en,
				Base,
				cs,
				sk,
			);
```

- [ ] **Step 2: Create the app-level `InfoPlist.xcstrings`**

Create `SportsTracker/SportsTracker/Resources/InfoPlist.xcstrings`. Localizing one Info.plist key across `en`/`cs`/`sk` is enough to make Xcode emit `cs.lproj`/`sk.lproj` into the app bundle and add all three to `CFBundleLocalizations`. Use the display name (kept identical across locales — declaring the languages is the point):

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "CFBundleDisplayName" : {
      "extractionState" : "manual",
      "localizations" : {
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Sports Tracker" } },
        "cs" : { "stringUnit" : { "state" : "translated", "value" : "Sports Tracker" } },
        "sk" : { "stringUnit" : { "state" : "translated", "value" : "Sports Tracker" } }
      }
    }
  },
  "version" : "1.0"
}
```

- [ ] **Step 3: Register the file in the app target**

If you created the file via Xcode's Localizations UI, it is already a member of the **SportsTracker** app target's **Copy Bundle Resources** phase — skip to Step 4. If you created it on disk, add it to that target in Xcode (drag into the project, check the **SportsTracker** target), or add the corresponding `PBXFileReference` + `PBXBuildFile` + Resources-phase entries in `project.pbxproj`. `GENERATE_INFOPLIST_FILE = YES` stays on; the localized `InfoPlist.strings` compiled from the catalog is merged with the generated Info.plist.

- [ ] **Step 4: Build and verify `CFBundleLocalizations`**

Run: `make build` → Expected: exit 0. Then confirm the built app declares the languages:
```bash
APP=$(find ~/Library/Developer/Xcode/DerivedData -type d -name 'SportsTracker.app' -path '*iphonesimulator*' 2>/dev/null | head -1)
/usr/libexec/PlistBuddy -c 'Print :CFBundleLocalizations' "$APP/Info.plist" 2>/dev/null
ls "$APP" | grep -E '(en|cs|sk)\.lproj'
```
Expected: `CFBundleLocalizations` lists `en`, `cs`, `sk`, and `cs.lproj`/`sk.lproj` exist in the app bundle. (If missing, the catalog isn't in the app target's Resources phase — recheck Step 3.)

- [ ] **Step 5: Verify the switcher and the running translations**

Install on the simulator and open **Settings ▸ Sports Tracker ▸ Language** — it lists **Čeština** and **Slovenčina**. Select Czech, relaunch: the app is Czech end to end (nav titles, filter segments, banners, error alerts, storage badges, delete-confirm dialog at counts 1 / 3 / 5). Repeat for Slovak. Confirm English still selectable and unchanged.

- [ ] **Step 6: Commit**

```bash
git add SportsTracker/SportsTracker.xcodeproj/project.pbxproj \
        SportsTracker/SportsTracker/Resources/InfoPlist.xcstrings
git commit -m "feat(app): add per-app Czech/Slovak language switcher"
```

---

## Self-review checklist (done while writing)

- **Spec coverage:** every key in the spec's §3 inventory has an `en`/`cs`/`sk` catalog entry (Tasks 1–3) and an `L10n` accessor; `common.save` added in Task 3 Step 8 where first used. ✅
- **Translations:** cs/sk values match the spec's §3a table; the `list.deleteConfirm.title %lld` plural carries `one`/`few`/`other` for cs and sk (Task 2 Step 3). ✅
- **Substring constraint:** English `addRecord.saveError.remote/.local` wording preserved verbatim (cs/sk free to differ); tests run in `en`, guarded in Task 3 Step 1. ✅
- **Type consistency:** accessor names referenced in call-site steps (`L10n.List.deleteSelectionButton`, `deleteConfirmTitle`, `L10n.Common.save`, `L10n.AddRecord.Duration.hours`, `L10n.Storage.local`) all match their definitions in Steps 4/8. ✅
- **Locale resolution:** `defaultLocalization` stays `en`; cs/sk live only in the feature catalog; `Bundle.module` resolution documented. ✅
- **Per-app switcher (Task 5):** App target gains `cs`/`sk` in `knownRegions` + an `InfoPlist.xcstrings` populating `CFBundleLocalizations`; verified via built-bundle `PlistBuddy` check and Settings ▸ app ▸ Language. ✅
- **Domain purity:** feature edits are in `Presentation/` + `Resources/` + `Package.swift`; no Domain/Data file touched. Task 5 touches only the App project (`pbxproj` + app `InfoPlist.xcstrings`). ✅
- **No placeholders:** every code/JSON step is complete and paste-ready. ✅
