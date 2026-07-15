# SportRecord Localization — Design

**Date:** 2026-07-15
**Scope:** Introduce localization to the **`SportRecord`** feature package. Extract every user-facing string currently hardcoded in the package's Presentation layer into a String Catalog resolved against the package's own bundle, behind a typed accessor, and ship three locales: **English (`en`, source), Czech (`cs`), Slovak (`sk`)**.

In scope on the App target: declaring `cs`/`sk` as supported app localizations so iOS surfaces a **per-app language switcher** (Settings ▸ Sports Tracker ▸ Language) and the app can run in Czech/Slovak independent of the device language. Out of scope: the `Core` package.

---

## 1. Decisions (settled)

| Question | Decision | Why |
|---|---|---|
| Format | **String Catalog** (`.xcstrings`) | Xcode 15+/iOS 18 native; plural/device variants; one file per module. |
| Ownership | **Per-module**, resolved against **`Bundle.module`** | Keeps `App → SportRecord → Core` intact; module builds/previews/tests in isolation. |
| Catalog location | `Sources/SportRecord/Resources/Localizable.xcstrings` (target root) | Standard SPM location; `Bundle.module` is target-wide so location is lookup-independent. |
| Accessor location | `Sources/SportRecord/Presentation/Localization/L10n.swift` | Localization is a **Presentation** concern (Domain stays UI-free). |
| Key namespace | Dotted `lowerCamelCase`, **no `feature.` prefix** | The bundle already namespaces; drops redundancy, survives module renames. |
| Access | Hand-written typed `L10n` enum returning **`String`** | One place owns each key + `bundle: .module`; works in every SwiftUI + `String` context. SwiftGen generation is the documented next step, not this iteration. |
| Common strings (`OK`, `Cancel`, …) | Stay in **SportRecord** under `common.*` for now | YAGNI: only one feature module exists. `common.*` namespace makes the future lift to a `Core` catalog a mechanical grep-and-move. |
| Locales | `en` (source) + `cs` + `sk`, all in the one catalog | `defaultLocalization` stays `en`; `cs`/`sk` are added as `localizations` per key. Adding a locale later is catalog-only, no code change. |

### Deviation note

An earlier scaling discussion recommended a shared `Core` catalog for common strings "now." That advice targets a *many-module* future. With exactly one feature module today, a `Core` catalog referenced by a single consumer is premature indirection. We keep common strings in `SportRecord` under an explicit `common.*` namespace so the extraction is trivial when module #2 lands. This is the only departure from the prior discussion and is deliberate.

## 2. Key naming convention

```
<screen>.<element>[.<variant>][.<role>]      feature UI, screen-scoped
<enumName>.<case>                            reused enum labels (filter, storageType)
common.<name>                                cross-screen primitives
```

`lowerCamelCase` segments, dot-separated. `role` suffixes: `.title`, `.placeholder`, `.button`, `.message`, `.picker`, `.section`.

## 3. Full string inventory & key map

Screens: **List** (`RecordsListView`, `RecordsListState`, `RecordsListViewModel`) and **Add** (`AddRecordView`, `AddRecordViewModel`, `DurationPicker`), plus shared enums (`StorageType`, `RecordsFilter`).

### List
| Source | English | Key |
|---|---|---|
| `RecordsListView` navTitle | `Sport Records` | `list.title` |
| alert title | `Delete failed` | `list.deleteError.title` |
| failed state title | `Couldn't Load Records` | `list.loadError.title` |
| failed state message | `Something went wrong reaching your data.` | `list.loadError.message` |
| empty title (nothing anywhere) | `No Sport Records` | `list.empty.title` |
| empty message | `Add your first activity to see it here.` | `list.empty.message` |
| empty title (filtered) | `No %@ Records` | `list.empty.filtered.title` |
| empty message (filtered) | `You have no %@ records yet.` | `list.empty.filtered.message` |
| banner offline | `You're offline — showing local records.` | `list.banner.offline` |
| banner remote down | `Couldn't reach remote — showing local records.` | `list.banner.remoteUnavailable` |
| toolbar add label | `Add Record` | `list.add.button` |
| filter picker (a11y label) | `Filter` | `list.filter.picker` |
| bottom-bar delete | `Delete Records (%lld)` | `list.deleteSelection.button` |
| confirm dialog title | `Delete %lld record(s)?` → **plural** | `list.deleteConfirm.title %lld` |
| delete err both | `Couldn't delete some records. Check your connection and try again.` | `list.deleteError.both` |
| delete err remote | `Couldn't delete remote records. You may be offline.` | `list.deleteError.remote` |
| delete err local | `Couldn't delete local records. Please try again.` | `list.deleteError.local` |
| delete err unknown | `Couldn't delete records.` | `list.deleteError.unknown` |

### Add
| Source | English | Key |
|---|---|---|
| `AddRecordView` navTitle | `Add Record` | `addRecord.title` |
| section | `Activity` | `addRecord.section.activity` |
| name field | `Name` | `addRecord.name.placeholder` |
| location field | `Location` | `addRecord.location.placeholder` |
| section | `Duration` | `addRecord.section.duration` |
| section | `Storage` | `addRecord.section.storage` |
| picker label | `Select storage` | `addRecord.storage.picker` |
| alert title | `Couldn't Save` | `addRecord.saveError.title` |
| save err remote | `Couldn't save to the backend. You may be offline — check your connection and try again.` | `addRecord.saveError.remote` |
| save err local | `Couldn't save locally. Please try again.` | `addRecord.saveError.local` |
| duration unit | `h` | `addRecord.duration.hours` |
| duration unit | `m` | `addRecord.duration.minutes` |
| duration unit | `s` | `addRecord.duration.seconds` |

### Shared enums
| Source | English | Key |
|---|---|---|
| `RecordsFilter.all` | `All` | `filter.all` |
| `RecordsFilter.local` | `Local` | `filter.local` |
| `RecordsFilter.remote` | `Remote` | `filter.remote` |
| `StorageType.local` label | `Local` | `storageType.local` |
| `StorageType.remote` label | `Remote` | `storageType.remote` |

`filter.local`/`storageType.local` are **separate keys despite identical English** — different UI contexts that may diverge per locale.

### Common
| English | Key |
|---|---|
| `OK` | `common.ok` |
| `Cancel` | `common.cancel` |
| `Save` | `common.save` |
| `Delete` | `common.delete` |
| `Done` | `common.done` |
| `Edit` | `common.edit` |
| `Try Again` | `common.tryAgain` |

## 3a. Translations (cs / sk)

`%@` = interpolated filter name; `%lld` = count. Filter/storage words are localized, so interpolations read naturally in each language.

| Key | English | Czech (`cs`) | Slovak (`sk`) |
|---|---|---|---|
| `list.title` | Sport Records | Sportovní záznamy | Športové záznamy |
| `list.deleteError.title` | Delete failed | Smazání se nezdařilo | Odstránenie zlyhalo |
| `list.loadError.title` | Couldn't Load Records | Nepodařilo se načíst záznamy | Nepodarilo sa načítať záznamy |
| `list.loadError.message` | Something went wrong reaching your data. | Při načítání dat došlo k chybě. | Pri načítaní údajov došlo k chybe. |
| `list.empty.title` | No Sport Records | Žádné sportovní záznamy | Žiadne športové záznamy |
| `list.empty.message` | Add your first activity to see it here. | Přidejte svou první aktivitu a zobrazí se zde. | Pridajte svoju prvú aktivitu a zobrazí sa tu. |
| `list.empty.filtered.title` | No %@ Records | Žádné %@ záznamy | Žiadne %@ záznamy |
| `list.empty.filtered.message` | You have no %@ records yet. | Zatím nemáte žádné %@ záznamy. | Zatiaľ nemáte žiadne %@ záznamy. |
| `list.banner.offline` | You're offline — showing local records. | Jste offline — zobrazují se lokální záznamy. | Ste offline — zobrazujú sa lokálne záznamy. |
| `list.banner.remoteUnavailable` | Couldn't reach remote — showing local records. | Vzdálené úložiště není dostupné — zobrazují se lokální záznamy. | Vzdialené úložisko nie je dostupné — zobrazujú sa lokálne záznamy. |
| `list.add.button` | Add Record | Přidat záznam | Pridať záznam |
| `list.deleteSelection.button` | Delete Records (%lld) | Smazat záznamy (%lld) | Odstrániť záznamy (%lld) |
| `list.deleteError.both` | Couldn't delete some records. Check your connection and try again. | Některé záznamy se nepodařilo smazat. Zkontrolujte připojení a zkuste to znovu. | Niektoré záznamy sa nepodarilo odstrániť. Skontrolujte pripojenie a skúste to znova. |
| `list.deleteError.remote` | Couldn't delete remote records. You may be offline. | Vzdálené záznamy se nepodařilo smazat. Možná jste offline. | Vzdialené záznamy sa nepodarilo odstrániť. Možno ste offline. |
| `list.deleteError.local` | Couldn't delete local records. Please try again. | Lokální záznamy se nepodařilo smazat. Zkuste to prosím znovu. | Lokálne záznamy sa nepodarilo odstrániť. Skúste to prosím znova. |
| `list.deleteError.unknown` | Couldn't delete records. | Záznamy se nepodařilo smazat. | Záznamy sa nepodarilo odstrániť. |
| `filter.all` | All | Všechny | Všetky |
| `filter.local` | Local | Lokální | Lokálne |
| `list.filter.picker` | Filter *(a11y label)* | Filtr | Filter |
| `filter.remote` | Remote | Vzdálené | Vzdialené |
| `common.ok` | OK | OK | OK |
| `common.cancel` | Cancel | Zrušit | Zrušiť |
| `common.save` | Save | Uložit | Uložiť |
| `common.delete` | Delete | Smazat | Odstrániť |
| `common.done` | Done | Hotovo | Hotovo |
| `common.edit` | Edit | Upravit | Upraviť |
| `common.tryAgain` | Try Again | Zkusit znovu | Skúsiť znova |
| `addRecord.title` | Add Record | Přidat záznam | Pridať záznam |
| `addRecord.section.activity` | Activity | Aktivita | Aktivita |
| `addRecord.name.placeholder` | Name | Název | Názov |
| `addRecord.location.placeholder` | Location | Místo | Miesto |
| `addRecord.section.duration` | Duration | Doba trvání | Trvanie |
| `addRecord.section.storage` | Storage | Úložiště | Úložisko |
| `addRecord.storage.picker` | Select storage | Vyberte úložiště | Vyberte úložisko |
| `addRecord.saveError.title` | Couldn't Save | Nepodařilo se uložit | Nepodarilo sa uložiť |
| `addRecord.saveError.remote` | Couldn't save to the backend. You may be offline — check your connection and try again. | Nepodařilo se uložit na server. Možná jste offline — zkontrolujte připojení a zkuste to znovu. | Nepodarilo sa uložiť na server. Možno ste offline — skontrolujte pripojenie a skúste to znova. |
| `addRecord.saveError.local` | Couldn't save locally. Please try again. | Nepodařilo se uložit lokálně. Zkuste to prosím znovu. | Nepodarilo sa uložiť lokálne. Skúste to prosím znova. |
| `addRecord.duration.hours` | h | h | h |
| `addRecord.duration.minutes` | m | m | m |
| `addRecord.duration.seconds` | s | s | s |
| `storageType.local` | Local | Lokální | Lokálne |
| `storageType.remote` | Remote | Vzdálené | Vzdialené |

### Plural: `list.deleteConfirm.title %lld`

Czech and Slovak both distinguish **one / few (2–4) / other (0, 5+)** for integer counts (the CLDR `many` category is decimal-only, so it's not needed here).

| Category | English | Czech | Slovak |
|---|---|---|---|
| one | Delete %lld record? | Smazat %lld záznam? | Odstrániť %lld záznam? |
| few | — (uses *other*) | Smazat %lld záznamy? | Odstrániť %lld záznamy? |
| other | Delete %lld records? | Smazat %lld záznamů? | Odstrániť %lld záznamov? |

## 4. Accessor mechanism

`L10n` is a caseless enum with nested namespaces returning `String`, resolved via a private helper against `Bundle.module`:

- **Plain:** `String(localized: "key", bundle: .module)`.
- **`%@` interpolation** (filter name): explicit clean key + `String(format:)` — keeps keys placeholder-free.
- **Plural** (`%lld` with grammatical agreement): `String(localized: "key \(count)", bundle: .module)`; the generated key carries ` %lld` and the catalog entry uses plural variations.

Returning `String` (not `LocalizedStringKey`/`LocalizedStringResource`) works uniformly across every SwiftUI control (all have `StringProtocol` verbatim overloads) and the `String`-typed ViewModel error properties. Tradeoff: Xcode's static extraction and stale-key detection don't follow the `L10n` helper, so the catalog is authored/maintained explicitly. SwiftGen (generating `L10n` from the catalog) is the documented upgrade once the module count grows — it restores catalog-as-source-of-truth.

## 5. Constraints / gotchas

- **`AddRecordViewModelTests` asserts** `saveError` contains `"backend"` (remote) and `"locally"` (local). Those assertions resolve against the **test process locale, which is `en`**, so the *English* wording for `addRecord.saveError.remote` / `.local` must keep those substrings (the `cs`/`sk` translations can use "server"/"lokálně" freely). Preserve the English verbatim.
- `Package.swift` needs `defaultLocalization: "en"` (required for any localized resource) and an explicit `resources: [.process("Resources")]` on the target. `cs`/`sk` are *not* named here — they live only as `localizations` inside the catalog.
- **Locale resolution is per-bundle.** `Bundle.module` computes its own `preferredLocalizations` from the catalog's available languages ∩ the user's `AppleLanguages`. So the package's `cs`/`sk` strings load whenever the device language (or an Xcode scheme "App Language" override, which injects `-AppleLanguages`) is Czech/Slovak — **independent of the App target**. No app-target change is required for the strings to appear.
- **Per-app language switcher (in scope).** iOS only shows the per-app "Preferred Language" control, and only reports `Locale.current` as `cs`/`sk` to the App bundle, if the *app bundle* itself declares those localizations — nested package/framework bundles (like `SportRecord`'s) don't count toward the app's language list. So the App target must gain `cs`/`sk` in the project's `knownRegions` **and** an app-level localized resource (an `InfoPlist.xcstrings`) so `CFBundleLocalizations` lists `en`/`cs`/`sk`. This is what makes the switcher appear; the feature strings still come from `Bundle.module`.
- Plural categories for `cs`/`sk` are **one / few / other** (integer counts); do not omit `few`, or 2–4 fall back to `other` and read wrong ("Smazat 3 záznamů?" instead of "…záznamy?").
- Domain layer stays UI-free — no `L10n` import in `Domain/`. All migrated strings live in `Presentation/`. The `.storageType` stamping rule is unaffected.

## 6. Verification

- `make test-sportrecord` green (new accessor/label tests + preserved English substring assertions; tests run in `en`).
- `make build` succeeds (catalog compiles into `SportRecord_SportRecord.bundle` with `en.lproj`/`cs.lproj`/`sk.lproj`; `Bundle.module` resolves at runtime).
- **Manual `en`:** List and Add render identical English to today — no visible change, confirming keys resolve and no raw key leaks.
- **Manual `cs` / `sk`:** two ways, both must pass. (a) Quick loop — run the scheme with the Run action's **App Language** set to Czech, then Slovak (Xcode ▸ Scheme ▸ Run ▸ Options ▸ App Language). (b) Shipping path — with the app installed, **Settings ▸ Sports Tracker ▸ Language** lists Čeština and Slovenčina; picking one relaunches the app localized. In both, every screen — nav titles, filter segments, banners, error alerts, storage badges, and the delete-confirm dialog at counts 1 / 3 / 5 (verifying plural forms) — shows translated text with no English leaking through.
