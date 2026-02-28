# Changelog — AI Opravy (3 sessions)

## Session 1: UI/UX Premium Polish

### Nové soubory:
- `Features/TodayWorkout/MuscleMapView_Redesign.swift`
  → OrganicBodyFigureView (drop-in za BodyFigureView) s organickými Capsule tvary
- `Features/Shared/EmptyStateView.swift`
  → Univerzální prázdné stavy (spánek, HRV, grafy, historie)
- `Features/Settings/HealthKitErrorHandling.swift`
  → AppleHealthSection + HealthKitErrorMapper (skrývá surové systémové chyby)
- `Features/ActiveWorkout/ActiveSessionContrast_and_PlanFallback.swift`
  → enhancedRowBackground pro ActiveSetRow + PlanFallbackCard pro RollingWeekView

### Jak integrovat:
1. V `HeatmapView.swift` nahraď `BodyFigureView(...)` za `OrganicBodyFigureView(...)`
2. V `SettingsView.swift` nahraď sekci Apple Health za `AppleHealthSection(healthKitService:)`
3. V `ActiveSessionView.swift` nahraď `.background(rowBG)` za `.background(enhancedRowBackground)`
4. V `RollingWeekView.swift` přidej `PlanFallbackCard(...)` pokud `selectedWorkoutDay == nil`

---

## Session 2: GIF Přehrávač + AI Objem

### Nové soubory:
- `Features/Shared/ExerciseMediaView.swift`
  → GIF přehrávač přes WKWebView + YouTube fallback karta
- `Services/AI/AITrainerService_UpdatedPrompt.swift`
  → SystemPromptContent.updated s pravidlem 6-8 cviků + ExerciseCountValidator

### Přepsané soubory:
- `Features/ExerciseDetail/ExerciseDetailView.swift`
  → ExerciseMediaView integrována jako první sekce + GIFLibrary

---

## Session 3: Architektura + DevOps

### Nové soubory:
- `App/AppEnvironment.swift`
  → Centrální DI kontejner (AppEnvironment + AppToastError)
- `Features/ActiveWorkout/ActiveSessionViewModel.swift`
  → Bezpečný concurrency vzor ([weak self], Task cancellation, Timer invalidation)
- `Features/Shared/GlobalErrorModifier.swift`
  → Globální Toast notifikace + NetworkMonitor (NWPathMonitor)

### Přepsané soubory:
- `App/AgileFitnessTrainerApp.swift`
  → AppEnvironment jako @StateObject, startup orchestrace
- `Services/AI/AITrainerService.swift`
  → WorkoutCache vrstva (UserDefaults, TTL 24h) + optimalizovaný system prompt
- `project.yml`
  → Finální XcodeGen konfigurace s HealthKit entitlements a privacy strings
- `.github/workflows/ios-build.yml`
  → Pipeline s cache (SPM + Homebrew), build numbering, TestResults upload
---

## Session 4: Video Sync & SVG Anatomy

### Nové soubory:
- `Features/Shared/AnatomySVGPath.swift`
  → Centrální mapa SVG cest a offsetů z human-anatomy-main (přední část těla)

### Přepsané soubory:
- `App/AppEnvironment.swift`
  → Vylepšený `syncExerciseVideos` s fuzzy matchingem (fix "ukázka chybí")
- `Features/Shared/DetailedBodyFigureView.swift`
  → Implementace dynamického skládání SVG dílků s přesným zarovnáním
- `Features/Shared/ExerciseMediaView.swift`
  → Úplné odstranění YouTube fallbacku, pročištění komentářů

### Smazané soubory:
- `Core/Utilities/YouTubeLinkGenerator.swift`
  → Již nepotřebné, veškerá media jsou lokální/Supabase
