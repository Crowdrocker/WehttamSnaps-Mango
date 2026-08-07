# WidgetGrid.qml Splitting Plan

## Overview
`WidgetGrid.qml` is 1282 lines containing 12 different widget components. This document details the planned split into separate files to improve maintainability and reduce risk of breaking the entire dock when modifying widgets.

---

## Current Widget Components in WidgetGrid.qml

### 1. CompoundPill (lines 166-709)
**Widget IDs:** wifi, bluetooth, audioOutput, audioInput, volumeMixer, hdrToggle
- Network connectivity (wifi/ethernet/BT) pills
- Audio output/input with volume sliders
- Volume mixer with app stream cards
- HDR toggle
- **Estimated Lines:** ~544

### 2. MediaPill (lines 714-720)
**Widget IDs:** media
- Uses existing `MediaPill` component (external)
- **Estimated Lines:** ~7

### 3. AudioSliderRow (lines 725-754)
**Widget IDs:** volumeSlider
- Uses `AudioSliderRow` component (external)
- **Estimated Lines:** ~30

### 4. BrightnessSliderRow (lines 756-781)
**Widget IDs:** brightnessSlider
- Uses `BrightnessSliderRow` component (external)
- **Estimated Lines:** ~26

### 5. InputAudioSliderRow (lines 783-812)
**Widget IDs:** inputVolumeSlider
- Uses `InputAudioSliderRow` component (external)
- **Estimated Lines:** ~30

### 6. BatteryPill (lines 817-881)
**Widget IDs:** battery (large)
- Full-size battery indicator with icon + percentage
- **Estimated Lines:** ~65

### 7. SmallBattery (lines 883-944)
**Widget IDs:** battery (small, ≤25 width)
- Compact battery indicator (icon-only centered)
- **Estimated Lines:** ~62

### 8. PerformancePill (lines 949-1010)
**Widget IDs:** performance
- Performance mode indicator (power-saver/balanced/performance)
- Cycle mode on click
- **Estimated Lines:** ~62

### 9. WeatherPill (lines 1015-1118)
**Widget IDs:** weather
- Weather display with icon tile, temperature, location
- Uses `WeatherService` refs
- **Estimated Lines:** ~104

### 10. ToggleButton (lines 1123-1211)
**Widget IDs:** nightMode, darkMode, doNotDisturb, idleInhibitor (full size)
- Toggle buttons with label + icon
- **Estimated Lines:** ~89

### 11. SmallToggle (lines 1216-1281)
**Widget IDs:** nightMode, darkMode, doNotDisturb, idleInhibitor (compact)
- Icon-only compact toggle variant
- **Estimated Lines:** ~66

---

## Proposed File Structure

```
Components/
├── WidgetGrid.qml           # Stub with layout logic only (reduced from 1282 to ~180 lines)
├── CompoundPill.qml       # wifi, BT, audio, volumeMixer, hdrToggle (~544 lines)
├── MediaPill.qml           # Re-exports MediaPill (~10 lines)
├── AudioSliderRow.qml       # Re-exports AudioSliderRow (~10 lines)
├── BrightnessSliderRow.qml  # Re-exports BrightnessSliderRow (~10 lines)
├── InputAudioSliderRow.qml # Re-exports InputAudioSliderRow (~10 lines)
├── BatteryPill.qml         # Full battery pill (~65 lines)
├── SmallBattery.qml       # Compact battery (~62 lines)
├── PerformancePill.qml     # Performance mode pill (~62 lines)
├── WeatherPill.qml         # Weather widget (~104 lines)
├── ToggleButton.qml        # Full-size toggle buttons (~89 lines)
└── SmallToggle.qml        # Compact toggle buttons (~66 lines)
```

---

## Splitting Priority Order

### Phase 1: Independent External Components
These use existing external components and wrap them only:
1. MediaPill.qml - Simple re-export (~10 lines)
2. AudioSliderRow.qml - Simple re-export (~10 lines)
3. BrightnessSliderRow.qml - Simple re-export (~10 lines)
4. InputAudioSliderRow.qml - Simple re-export (~10 lines)

### Phase 2: Small Standalone Widgets
These have minimal external dependencies:
5. BatteryPill.qml - Battery service only (~65 lines)
6. SmallBattery.qml - Battery service only (~62 lines)
7. PerformancePill.qml - Performance service only (~62 lines)

### Phase 3: Medium Complexity Widgets
8. WeatherPill.qml - Weather service, ref counting (~104 lines)
9. ToggleButton.qml - Multiple services (~89 lines)
10. SmallToggle.qml - Multiple services (~66 lines)

### Phase 4: Complex Compound Widget
11. CompoundPill.qml - Network, BT, Audio services, complex state (~544 lines)

### Phase 5: Main Grid Stub
12. WidgetGrid.qml - Layout logic only (~180 lines)

---

## Shared Dependencies to Pass Via Context

All extracted components will receive these via context properties (Loader parent):
- `widgetData: var` - Widget configuration
- `widgetIndex: int` - Global widget index
- `globalWidgetIndex: int` - Same as widgetIndex
- `widgetWidth: int` - Widget width category
- `root.editMode: bool` - Edit mode state
- `root.expandClicked(...)` signal - Expand handler
- `root.removeWidget(...)` signal - Remove handler
- `root.moveWidget(...)` signal - Move handler
- `root.toggleWidgetSize(...)` signal - Size toggle handler
- Design constants: `_cardRadius`, `_cardBorderAlpha`, `_cardBgAlpha`
- Helper functions: `_cardBg()`, `_cardBorder()`

---

## Breaking Criteria

### If Split Correctly, Single Widget Break = Single File Break Only

| If This Breaks | Only These Files Affected |
|--------------|----------------------|
| wifi/bluetooth widget | CompoundPill.qml only |
| audio output widget | CompoundPill.qml only |
| volume mixer widget | CompoundPill.qml only |
| media widget | MediaPill.qml only |
| volume slider | AudioSliderRow.qml only |
| brightness slider | BrightnessSliderRow.qml only |
| input volume slider | InputAudioSliderRow.qml only |
| battery widget | BatteryPill.qml or SmallBattery.qml |
| performance widget | PerformancePill.qml only |
| weather widget | WeatherPill.qml only |
| toggle/dark/dnd/idle widgets | ToggleButton.qml or SmallToggle.qml |
| grid layout | WidgetGrid.qml only |

---

## Migration Steps (For Each Component)

### Step 1: Create New File
```qml
import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
// Add needed imports

Component {
    id: widgetComponentName
    // ... extracted component code ...
}
```

### Step 2: Update WidgetGrid.qml
```qml
// Replace Component { id: widgetComponentName ... } with:
Component {
    id: widgetComponentName
    import "WidgetName.qml" as WidgetName
    WidgetName.WidgetComponent { }
}
```

Or use Loader with dynamic source:
```qml
Loader {
    source: "WidgetName.qml"
}
```

### Step 3: Test
- Ensure all widget types render correctly
- Test expand/collapse
- Test edit mode
- Test interactions

---

## Testing Checklist

After each widget type migration, verify:
- [ ] Widget renders at correct size in grid
- [ ] Card styling (radius, border, background) matches
- [ ] Click expands to detail view
- [ ] Edit mode overlay works
- [ ] Remove/toggle size/move works
- [ ] Service bindings update correctly (network, audio, BT, etc.)

---

## Rollback Plan

If critical break:
1. Revert WidgetGrid.qml to pre-split backup
2. Comment out new imports, restore inline Component definitions
3. File can be restored from git

---

## Files To Create

| File | Source Lines | Priority |
|------|-------------|----------|
| Components/CompoundPill.qml | 166-709 | P4 |
| Components/WifiPill.qml | (portion of CompoundPill) | P4 |
| Components/BluetoothPill.qml | (portion of CompoundPill) | P4 |
| Components/AudioOutputPill.qml | (portion of CompoundPill) | P4 |
| Components/AudioInputPill.qml | (portion of CompoundPill) | P4 |
| Components/VolumeMixerPill.qml | (portion of CompoundPill) | P4 |
| Components/HdrTogglePill.qml | (portion of CompoundPill) | P4 |
| Components/MediaPill.qml | 714-720 | P1 |
| Components/AudioSliderRow.qml | 725-754 | P1 |
| Components/BrightnessSliderRow.qml | 756-781 | P1 |
| Components/InputAudioSliderRow.qml | 783-812 | P1 |
| Components/BatteryPill.qml | 817-881 | P2 |
| Components/SmallBattery.qml | 883-944 | P2 |
| Components/PerformancePill.qml | 949-1010 | P2 |
| Components/WeatherPill.qml | 1015-1118 | P3 |
| Components/ToggleButton.qml | 1123-1211 | P3 |
| Components/SmallToggle.qml | 1216-1281 | P3 |

---

## Notes

- Consider further splitting CompoundPill into 6 separate components if complexity warrants
- Each extracted component should have clear import requirements documented
- Design constants should live in a shared file or be passed via context
- Test thoroughly after each phase before proceeding
- Keep WidgetGrid.qml as the coordination point initially, refactor later