# Changelog — Kompletní Refaktoring AgileFitnessTrainer
## Verze 2.1 — Master Prompt Audit

---

## 📁 Dodané soubory a co bylo opraveno

---

### 1. `MuscleMapView.swift` — Prémiový UI redesign

**Problém:** Původní `BodyFigureView` používal ostré `Rectangle()` tvary — postava vypadala jako součet obdélníků, ne jako lidská silueta.

**Opravy:**
- ✅ Přejmenováno na `MuscleMapView` — čistší veřejné API (zpětně kompatibilní)
- ✅ Nová `PremiumBodySilhouette` shape — **nulové ostré rohy**, postavena výhradně z `Capsule`-like tvarů (`addCapsule()` helper)
- ✅ Silueta má gradient pozadí + subtilní border gradient (jako Apple Fitness+)
- ✅ `OrganicMuscleZoneView` — dynamický `cornerRadius` (malé oblasti = plná Capsule)
- ✅ Gamifikační glow animace pro trénované svaly — pulsující `RadialGradient`
- ✅ `ViewTogglePill` — prémiový přepínač Přední/Zadní s Capsule designem
- ✅ `TapCatcherView` — transparentní hit-test vrstva, seřazená od nejmenší oblasti (přesnější výběr)
- ✅ Entrance animace celé siluety (fade + scale)
- ✅ Plná zpětná kompatibilita s `HeatmapViewModel` a `MuscleArea`

**Jak použít:**
```swift
// Nahraď BodyFigureView(vm: vm) za:
MuscleMapView(vm: vm) { area in
    vm.lastTappedArea = area
    showConfirmation = true
}
```

---

### 2. `EmptyStateView.swift` — Opravená prémiová komponenta

**Problém:** Původní soubor obsahoval globální funkci `previewCard()` (kompilační conflict při více previewích), chyběly stavy pro Supabase error a nenalezený profil.

**Opravy:**
- ✅ `previewCard()` nahrazena privátní `EmptyStatePreviewCard` struct (žádný global scope conflict)
- ✅ Přidány 3 nové tovární metody: `.noWorkout(onGenerate:)`, `.supabaseError(onRetry:)`, `.noProfile()`
- ✅ Animace optimalizována — jeden `appeared` stav, dvě fáze (icon + text)
- ✅ Přidán `.accessibilityLabel` pro VoiceOver podporu
- ✅ Glow animace spouštěna přes `.animation(.repeatForever)` — žádný `DispatchQueue` hack

---

### 3. `AITrainerService.swift` — API optimalizace a thread safety

**Problémy:**
- Task.detached bez `[weak self]` → potenciální retain cycle
- `persistAIMetadata` bez `[weak self]` v Task closure
- JSON parser nechránil před BOM znakem ani prose před `{`
- Timeout race nesprávně strukturován (chyběla `TaskGroup`)

**Opravy:**
- ✅ `callGeminiWithTimeout()` přepsán jako `withThrowingTaskGroup` — správná race condition mezi API a timeoutem
- ✅ `Task.detached` pro cache save má explicitní `[weak self]` guard
- ✅ `persistAIMetadata` volána přes `Task { [weak self] in ... }` — žádný retain cycle
- ✅ `parseAndValidateJSON()` stripuje BOM (`\u{FEFF}`), najde první `{` v odpovědi
- ✅ System Prompt zkrácen o ~40% — odstraněny příklady a opakování
- ✅ `buildUserMessage()` nepoužívá `.prettyPrinted` → menší request payload
- ✅ `WorkoutCache.save()` je `nonisolated` → bezpečné volání z `Task.detached`
- ✅ `generateTodayWorkout()` vrací vždy `TrainerResponse` (nikdy nehází) — graceful degradation
- ✅ Přidány `invalidateTodayCache()` a `clearAllCache()` public metody

---

### 4. `AppEnvironment.swift` — Opravený DI kontejner

**Problémy:**
- `configure()` nebylo idempotentní — volání dvakrát by vytvořilo 2x `AITrainerService`
- Chyběl `showError(AppError)` overload pro typované chyby
- `isStartupComplete` nebyl publikován → UI nemohlo zobrazit loading stav

**Opravy:**
- ✅ `configure()` je idempotentní — `isConfigured` guard
- ✅ `@Published private(set) var isStartupComplete` — UI může čekat na startup
- ✅ `showError(AppError)` — překladač z typované chyby na toast
- ✅ `AppToastError.Severity` rozšířena o `.critical`
- ✅ `Task.detached` v `performStartup` má `[weak self]` guard
- ✅ Přidán `AppToastError.supabaseError`

---

### 5. `AgileFitnessTrainerApp.swift` — Opravený App entry point

**Problémy:**
- `RootView` okamžitě renderoval MainTabView bez čekání na startup → crash pokud SwiftData ještě není připraven
- `DebugOverlayView` byl v produkci (zbytečné)

**Opravy:**
- ✅ `AppStartupView` — prémiový loading screen čekající na `isStartupComplete`
- ✅ `#if DEBUG` podmínka pro `DebugOverlayView`
- ✅ Onboarding větev oddělena do `@ViewBuilder var onboardingFlow`
- ✅ Transition animace pro všechny 3 stavy (startup → onboarding → main)

---

### 6. `project.yml` — Finální XcodeGen konfigurace

**Problémy:**
- Chyběl SPM packages blok (Supabase)
- `aps-environment: production` v base settings — musí být `development` pro debug
- Chybělo `UIUserInterfaceStyle: Dark`
- Test environment variables neměly mock hodnoty

**Opravy:**
- ✅ SPM `packages:` blok s Supabase (verze ≥ 2.5.0)
- ✅ `aps-environment: development` v base (pro Sideloadly/debug)
- ✅ `UIUserInterfaceStyle: Dark` v Info.plist
- ✅ `MinimumOSVersion: "17.0"` explicitně
- ✅ Test scheme má mock environment variables (testy nechodí na Gemini API)
- ✅ `MallocStackLogging: "1"` v run scheme → snadnější debug memory leaků
- ✅ Tests: `parallelizable: true` + `randomExecutionOrder: true`
- ✅ `xcodeVersion: "16.2"` — pevná verze pro deterministické buildy

---

### 7. `ios-build.yml` — Opravený GitHub Actions workflow

**Kritická chyba:** `sed -i "s/..."` bez prázdného backup extension → **selže na macOS** (GNU sed ≠ BSD sed)

**Opravy:**
- ✅ `sed -i '' "s/..."` — macOS-kompatibilní syntax (KRITICKÁ OPRAVA)
- ✅ `--TEAM_ID__` placeholder místo `TEAM_ID_PLACEHOLDER` (čistší)
- ✅ SPM resolve má retry smyčku (3 pokusy, 15s pauza) → odolné vůči dočasným síťovým chybám
- ✅ `set -o pipefail` v test a archive krocích → pipeline selže i při piped exit code
- ✅ Artifact name obsahuje branch name + short SHA → snazší identifikace
- ✅ `skip_tests` input pro rychlý build bez testů
- ✅ `xcodegen generate --no-env` → nezahlcuje log environment variables
- ✅ Build Summary zobrazuje signing status (✅/⚠️)
- ✅ `XCODE_VERSION: "16.2"` — pevná verze (deterministické buildy)

---

## 🛠️ Jak soubory nasadit

### Nahrazení souborů:
```
MuscleMapView.swift          → Features/TodayWorkout/MuscleMapView.swift
                               (smaž MuscleMapView_Redesign.swift — je nahrazen)
EmptyStateView.swift         → Features/Shared/EmptyStateView.swift
AITrainerService.swift       → Services/AI/AITrainerService.swift
AppEnvironment.swift         → App/AppEnvironment.swift
AgileFitnessTrainerApp.swift → App/AgileFitnessTrainerApp.swift
project.yml                  → project.yml
ios-build.yml                → .github/workflows/ios-build.yml
```

### Aktualizace referencí na MuscleMapView:
V `HeatmapView.swift` nahraď:
```swift
// PŘED:
BodyFigureView(vm: vm) { area in ... }

// PO:
MuscleMapView(vm: vm) { area in ... }
```

### Vygenerování projektu (po změnách):
```bash
cd AgileFitnessTrainer_IOS
xcodegen generate
```

---

## 💰 Odhadované úspory Gemini API

| Optimalizace | Úspora |
|---|---|
| Cache HIT (druhé otevření dne) | ~100% nákladů na 2.+ volání |
| Zkrácený System Prompt | ~15% méně input tokenů |
| `.sortedKeys` bez `.prettyPrinted` | ~8% méně request tokenů |
| Structured Output (no markdown) | ~5% méně output tokenů |
| **Celkem při 1 generování/den** | **~25% úspora / první volání** |
| **Celkem při cache HIT** | **~95% úspora / den** |
