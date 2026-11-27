# Apple HIG, Educational UX & Swift 6 UI Checklist

Use this reference alongside `ios-swiftui-mvvm` (and the **Mobbin** plugin skills `search` / `redesign-screen` when benchmarking real shipped language-app patterns) when designing or reviewing any view in `iosApp/Sources/Presentation/`.

Cross-reference specs:
- [05-ui-flows.md](../../../../specs/05-ui-flows.md) — Exact navigation flows, view contracts, and EN/ES separation.
- [01-cambridge-phases.md](../../../../specs/01-cambridge-phases.md) — 4 skill/phase states and assessment constants.
- [AGENTS.md](../../../../AGENTS.md) — `@Observable`, subview limit (~50 lines), and iOS 17+ baseline.

---

## 1. Apple Human Interface Guidelines (iOS 17+)

- **Minimum Touch Targets (`44 × 44 pt`):** Ensure every button, multiple-choice row, word-reorder chip, and skill cell meets `44 × 44 pt` minimum hit area (apply `.contentShape(Rectangle())` on custom card tap targets).
- **4pt / 8pt Spacing Grid:** Use consistent padding and spacing steps (`4`, `8`, `12`, `16`, `20`, `24`, `32`) — avoid arbitrary constants (`13`, `17`, `23`).
- **Native iOS Navigation & Controls:**
  - Use `NavigationStack`, `.sheet`, `.navigationDestination`, `ProgressView`, and `ContentUnavailableView` (iOS 17+) rather than custom web-style drawers or Android-style floating menus.
  - Keep primary CTA buttons anchored consistently near the bottom thumb zone (`"Start Test"`, `"Continue"`, `"Practice Missed Questions"`).
- **Dynamic Type & Text Wrapping:**
  - Prefer SwiftUI semantic text styles (`.largeTitle`, `.title2`, `.headline`, `.body`, `.callout`, `.caption`) and `@ScaledMetric` for custom icon/spacing ratios.
  - Never fix heights on text containers holding English prompts or Spanish RAG explanations (`fixedSize(horizontal: false, vertical: true)` inside scrollable containers if needed).

---

## 2. Educational UX Patterns (Duolingo-Inspired, Spec-Aligned)

- **Single-Task Focus in `TestView` & `PlacementTestView`:**
  - Hide dashboard clutter during active questions; show only the top `Question X of 15` (or `18`) progress bar, the prompt card, the answer input area, and the primary submit button.
- **Tri-Tier Visual & Haptic Feedback:**
  - Use native iOS 17+ `.sensoryFeedback(...)` modifiers bound to answer submission triggers:
    - `+1.0` correct → crisp green confirmation + `.sensoryFeedback(.success, trigger:)`
    - `0.0` error (in `TestView`, never `PlacementTestView`) → `.sensoryFeedback(.error, trigger:)` + immediate Spanish explanation `.sheet` with `interactiveDismissDisabled(true)` until `"Continue"` is tapped
- **Colorblind-Safe 4-State Differentiation (`HomeView`):**
  - Never rely solely on color to distinguish `✅ passed`, `⏭️ skippedPassed`, `🔵 available`, and `🔒 locked`. Combine SF Symbols/badges, distinct contrast/opacity, and explicit English status labels or accessibility descriptions.
- **Anti-Cheating Input Hygiene:**
  - On `fillBlank` and `translation` text fields, apply `.autocorrectionDisabled(true)` and `.textInputAutocapitalization(.never)` where appropriate so iOS predictive autocorrect does not mask grammar/spelling errors being tested.
- **Benchmarking with Mobbin (Optional):**
  - Before finalizing layout hierarchy for `OnboardingView`, `HomeView`, `TestView`, or `FeedbackView`, use the installed **Mobbin** plugin (`search` / `redesign-screen`) to study real shipped iOS language-learning layouts while keeping 100% of our app copy in English and error feedback in Spanish.

---

## 3. Accessibility & Dark Mode Verification

- **Semantic Colors Only:** Use system dynamic colors (`Color(.systemBackground)`, `Color(.secondarySystemBackground)`, `.primary`, `.secondary`) and asset-catalog adaptive colors verified in both Light and Dark Mode.
- **VoiceOver Support:**
  - Group composite skill/attempt cards (`accessibilityElement(children: .combine)`) with clear English `accessibilityLabel` and `accessibilityValue` (e.g., `"Skill A1-01 Personal pronouns, Passed, Best score 93 percent"`).
  - Mark decorative animations (like confetti on `FeedbackView` `>= 0.80`) with `.accessibilityHidden(true)`.
  - Ensure `reorder` word chips announce whether a token is selected in the sentence tray or available in the word bank.

---

## 4. Swift 6 Strict Concurrency UI Guardrails

- **Observable ViewModels (`@Observable @MainActor`):**
  - Always pass `@Observable` models with `@Bindable` inside child views that require two-way bindings (`$viewModel.userInput`), instead of legacy `@ObservedObject` / `@StateObject`.
- **Lifecycle-Bound Async Work (`.task(id:)`):**
  - Trigger asynchronous RAG explanation generation or model loading using `.task` / `.task(id:)` (which cancels automatically when the view dismisses) rather than uncancelled detached `Task {}` calls in `onAppear`.
- **Zero Heavy Work in `View.body`:**
  - Never sort/shuffle `distractors`, decode Markdown, run cosine search, or query SwiftData filters inside `body`. Compute shuffled question state once inside the `@MainActor` ViewModel when presenting the question.
- **Strict Language Lock Audit:**
  - Verify zero Spanish strings appear in SwiftUI `Button`, `Text` headers, `navigationTitle`, alerts, or `accessibilityLabel`s, and zero English prose replaces the 3 Spanish Markdown sections inside the error explanation sheet.
