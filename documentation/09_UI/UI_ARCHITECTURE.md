# UI Architecture

## App Navigation

MetalCraft uses a TabView with 4 tabs:

```
TabView
├── Editor Tab (AppTab.editor)
│   └── EditorView
│       ├── ImageCanvasView / VideoCanvasView (media preview)
│       ├── Tool tabs (Adjustments, Effects, Stack, Pipeline, Presets)
│       ├── ComparisonView / SplitComparisonView
│       └── Three-dot menu (close media, export, etc.)
│
├── AI Create Tab (AppTab.aiCreate)
│   └── AICreateView (PLACEHOLDER → to be replaced)
│
├── Analytics Tab (AppTab.analytics)
│   └── AnalyticsView
│       ├── GPUDashboardView
│       ├── BenchmarkControlView / BenchmarkResultsView
│       ├── HistogramView / RGBHistogramView
│       ├── ImageInfoView
│       └── PerformanceView
│
└── Projects Tab (AppTab.projects)
    └── ProjectsView
        ├── NewProjectSheet
        ├── ProjectDetailsView
        ├── ImagePreviewSheet / VideoPreviewSheet
        └── ProjectPickerSheet
```

## Design System

**File**: `MetalCraft/Views/Shared/Theme.swift`

MetalCraft follows Apple's iOS design language with:
- System colors and dynamic type
- SF Symbols for iconography
- Native navigation patterns (NavigationStack, .sheet, .toolbar)
- Supports both portrait and landscape orientations
- Dark mode support via system appearance

## Key UI Patterns

1. **State-driven**: All UI reads from `AppState` (single source of truth)
2. **Sheets**: Modal workflows use `.sheet()` presentation
3. **Tool tabs**: Editor uses segmented-style tool selection
4. **Comparison**: Interactive split divider for before/after comparison
5. **Empty states**: Professional empty states with action prompts

## AI Create UI (PHASE 5)

The AICreateView will be replaced with:
- Prompt input field with send button
- Agent state indicator (analyzing → planning → executing → complete)
- Conversation-style message bubbles showing agent reasoning
- EditPlan preview card showing operations and adjustments
- Approve / Revise / Cancel actions
- Research context display (from Parallel)
