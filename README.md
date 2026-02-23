# Agilní Fitness Trenér — Xcode Setup

## Požadavky
- Xcode 16+
- iOS 17.0+ deployment target
- watchOS 10+ (pro Watch target)
- Swift 5.9+

---

## Struktura targetů v Xcode

Projekt potřebuje **3 targety**:

| Target | Typ | Soubory |
|--------|-----|---------|
| `AgileFitnessTrainer` | iOS App | Vše v `App/`, `Core/`, `Data/`, `Domain/`, `Services/`, `Features/`, `Watch/` (jen iOS soubory) |
| `AgileFitnessTrainerWidgetExtension` | Widget Extension | `LiveActivity/RestTimerLiveActivity.swift`, `LiveActivity/RestTimerAttributes.swift` |
| `AgileFitnessTrainerWatch` | watchOS App | `Watch/WatchWorkoutView.swift`, `Watch/WatchConnectivityManager.swift` |

### Sdílené soubory (přidat do více targetů):
- `LiveActivity/RestTimerAttributes.swift` → iOS App + Widget Extension
- `Watch/WatchConnectivityManager.swift` → iOS App + watchOS App

---

## Nastavení projektu

### 1. Capabilities (iOS target)
V Xcode → Target → Signing & Capabilities přidej:
- ✅ HealthKit
- ✅ Push Notifications  
- ✅ Background Modes → `Background fetch`, `Remote notifications`
- ✅ Live Activities (automaticky s Push Notifications)

### 2. Info.plist — přidej klíče
```xml
<key>NSHealthShareUsageDescription</key>
<string>Aplikace čte data pro optimalizaci tréninku (HRV, spánek, aktivity).</string>

<key>NSHealthUpdateUsageDescription</key>
<string>Aplikace ukládá tréninkové záznamy do Apple Health.</string>

<key>GEMINI_API_KEY</key>
<string>$(GEMINI_API_KEY)</string>
```

### 3. API klíč
V Xcode → Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables:
```
GEMINI_API_KEY = tvůj_klíč_zde
```
Nebo nastav v `xcconfig` souboru pro produkci.

### 4. Widget Extension — Info.plist
Přidej do Widget Extension targetu:
```xml
<key>NSSupportsLiveActivities</key>
<true/>
```

### 5. App Group (pro sdílení dat mezi app a widget)
- Přidej capability `App Groups` do obou targetů
- Group ID: `group.com.yourcompany.agilefit`
- Uprav `ModelConfiguration` pro sdílený container (volitelné)

---

## Pořadí buildování

1. Nejdříve zbuilduj **Widget Extension** target
2. Pak hlavní **iOS App** target  
3. Watch target je nezávislý

---

## Soubory ke stažení / CDN

### Exercise animations
`ExerciseAnimationView` aktuálně zobrazuje SF Symbol placeholder.
Pro produkci nahraď za:
```swift
// Option A: AsyncImage z CDN
AsyncImage(url: URL(string: "https://cdn.agilefit.app/exercises/\(slug).gif"))

// Option B: Lottie (přidej balíček)
LottieView(name: slug)
```

### ExerciseDatabase.json
Přidej do `Resources/` seed data ve formátu:
```json
[
  {
    "slug": "barbell-bench-press",
    "name": "Bench Press (činka)",
    "nameEN": "Barbell Bench Press",
    "category": "chest",
    "movementPattern": "push",
    "equipment": ["barbell"],
    "musclesTarget": ["pecs"],
    "musclesSecondary": ["triceps", "delts"]
  }
]
```

---

## Závislosti (Swift Package Manager)
Projekt nemá externí závislosti — vše je nativní SwiftUI / SwiftData / HealthKit / ActivityKit.

Volitelně:
- `lottie-ios` pro animace cviků
- `Kingfisher` pro cachování GIF animací z CDN
