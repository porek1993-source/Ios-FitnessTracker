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
---

## Session 5: Opravy bugů a vylepšení (v2.2)

### Opravené bugy:

#### 1. `Services/AI/GeminiAPIClient.swift` — Kritická aktualizace API modelu
**Problém:** Model `gemini-2.5-flash-preview-05-20` byl preview verze, která může být kdykoliv stažena. Navíc chyběla detekce SAFETY/RECITATION blokování.

**Opravy:**
- ✅ Model aktualizován na `gemini-2.0-flash` (stabilní GA verze, nižší latence)
- ✅ `finishReason` check — detekce SAFETY/RECITATION/OTHER blokování před parsováním
- ✅ `GeminiError.contentBlocked(reason:)` nový error case pro blokovaný obsah
- ✅ Retry logika rozšířena o HTTP 503 (přetížené API) — exponential backoff
- ✅ `GeminiResponse.Candidate` nyní dekóduje `finishReason: String?`

#### 2. `Services/AI/AITrainerService.swift` — Opravy `shouldUseGemini`
**Problém 1:** Odsazení `Calendar.mondayStart.isDate(...)` bylo špatné — volání bylo mimo podmínku, čímž se vždy zařazovalo do vnějšího `filter` closure, ale logika nedávala smysl pro compiler.

**Problém 2:** `daysRemainingInWeek = 7 - adjustedWeekday` mohlo být záporné (v neděli = 0, pak -1 pro výpočty).

**Problém 3:** Chyběla kontrola nízké HRV — API se nevolalo ani při kriticky nízkém HRV, takže trénink nebyl adaptován.

**Opravy:**
- ✅ Opraveno odsazení `Calendar.mondayStart.isDate(...)` — nyní správně uvnitř filter closure
- ✅ `daysRemainingInWeek = max(0, 7 - adjustedWeekday)` — nemůže být záporné
- ✅ Přidána HRV kontrola: pokud HRV < 50 % baseline, AI se zavolá pro adaptaci intenzity

#### 3. `Services/Sync/OfflineSyncManager.swift` — Odstranění duplicitní instance
**Problém:** `OfflineSyncManager` vytvářel vlastní instanci `SupabaseExerciseRepository` v `private init()`, zatímco `AppEnvironment` měl sdílenou instanci. = 2 zbytečné Supabase klienty.

**Opravy:**
- ✅ `configure(repository:)` metoda pro injektování sdílené instance z `AppEnvironment`
- ✅ `AppEnvironment.performStartup` nyní volá `OfflineSyncManager.shared.configure(repository: exerciseRepository)`
- ✅ Retry logika pro přechodné síťové chyby (max 2 pokusy s exponential backoff)

#### 4. `App/AppEnvironment.swift` — OfflineSyncManager konfigurace
**Oprava:**
- ✅ `performStartup` volá `OfflineSyncManager.shared.configure(repository: exerciseRepository)` po startu
