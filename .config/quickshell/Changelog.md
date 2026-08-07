# Changelog

All notable changes to Event Horizon Dotfiles will be documented in this file.

## [3.2.0] - 2026-04-24

### Bug Fixes

- **Control Center / Widgets**
  - Fixed `CompoundPill.qml` syntax errors caused by duplicated blocks / stray braces.
  - Fixed recursive instantiation in `AudioSliderRow.qml` and `InputAudioSliderRow.qml` across Control Center, Dock, and MiniPanel by qualifying imports to the correct module.
  - Fixed `WidgetGrid` `qmldir` declarations incorrectly marking `WidgetGrid` as `singleton`.
  - Fixed `WidgetGrid` loader property assignment errors by only assigning properties that exist on the loaded item.
  - Increased Control Center popout widths across modules to reduce cramped layouts.
  - Widened TaskBar Control Center popout by 8px for better widget fit.

- **Brightness**
  - Rebuilt brightness UI to avoid widget overflow: compact tile + expanded detail view.
  - Added `BrightnessDetail.qml` and routed `DetailHost.qml` to load it for the `brightnessSlider` expanded section.
  - Fixed per-monitor brightness slider repeater bindings (`modelData.*`) and guarded against `undefined` brightness values.
  - Improved `DisplayService` device filtering (ignore `leds`) and preferred `backlight` devices for defaults.
  - Fixed `BrightnessOSD.qml` scope issues by keeping a root-level reference to the loaded slider and removing duplicate property assignments.

- **App drawer / Popouts**
  - Fixed Dock app drawer local component resolution (`import "." as ...`) and scoping of `isInhibiting`.
  - Fixed TaskBar app drawer module casing/import issues and `qmldir` exports (including back-compat type aliases), plus corrected popup sizing/clamping so it isn’t cut off.
  - Fixed TopBar app drawer namespace/property casing issues and adjusted positioning so it sits flush beneath the TopBar (2px gap).
  - Fixed TopBar calling the correct API (`show()` instead of `open()`).

- **Notifications**
  - Fixed `NotificationService` MPRIS connections by targeting `activePlayer`, using the correct signal, and ignoring unknown signals.
  - Hardened notification wrapper bindings against `null`/`undefined` notification payloads to prevent runtime warnings.
  - Fixed hot-reload type incompatibility by storing notification wrapper lists as untyped `var` arrays instead of `list<NotifWrapper>`.

- **Settings**
  - Fixed `ControlCenterTab.qml` delegate scope warnings by removing invalid cross-scope references (refresh happens via `SettingsData` change signal).
  - Fixed various Settings sliders/text bindings that could assign `undefined` to typed `int`/`double` properties by providing safe defaults.
  - Fixed `NetworkTab.qml` `undefined` → `int` warnings by guarding `font.pixelSize` bindings with numeric fallbacks.
  - Fixed multiple Settings tabs’ `undefined` → typed property warnings with safe fallbacks (Matugen, TaskBar, Dock, MiniPanel, Workspace Overview, System Update, Sound, Network, etc.).
  - Fixed deprecated signal handler parameter injection (`onExited`) by switching to formal-parameter functions.
  - Fixed Hyprland animations tab using unsupported `Quickshell.runSynced` by switching to `Process` + `StdioCollector`.
  - Fixed `SoundTab.qml` runtime warning caused by an out-of-scope `isActive` reference.
  - Fixed `SystemUpdateTab.qml` model safety by guarding optional fields in Flatpak cards.

- **Theme / Rendering**
  - Fixed `QFont::setPixelSize` warnings by clamping font sizes and adding compatibility aliases (`fontSizeXSmall`, `cornerRadiusSmall`) in `Theme.qml`.
  - Reduced excessive SVG `sourceSize` usage across widgets/popouts to prevent `qt.svg.draw` buffer warnings.
  - Fixed `SystemLogo.qml` attempting to set `sourceSize` on `IconImage` (unsupported) and kept sizing only on plain `Image`.

- **System Updates**
  - Fixed `dnf` update checking behavior by correcting exit-code handling, avoiding forced `--refresh` on every run, and adding a watchdog timeout to prevent “endless checking”.

## [3.1.0] - 2026-04-22

### New Features

- **Package Manager**
  - Multi-package removal functionality
    - Select multiple packages at once and remove them in batch
    - Improved selection UI with checkboxes
  - Install/Remove/Update UI for packages
    - New InstallPopupWindow with better UX
    - UI to remove packages directly from installed list
    - UI to install updated packages and their dependencies
    - UI to install apps and dependencies after search
  - Package upgrade window with dependency resolution
    - New PKGUpgradeWindow with enhanced functionality
    - Better dependency handling and resolution
  - Local package installation support
    - PKGLocalInstallTab improvements
    - LocalInstallWindow enhancements
  - Enhanced package card design
    - PKGCard redesign with better display

- **Weather Module**
  - New raining animation shader (ANIM_WP_Raining)
    - New fragment shader for rain effects
    - New vertex shader for animation
    - Compiled shader binaries (.qsb)
  - New blur shader effects
    - blur.frag and blur.vert shaders
    - Applied to weather visuals
  - New glass material shaders (glassMat and glassMatVulkan)
    - Advanced glass rendering for weather backgrounds
    - Vulkan variant for better performance
  - Enhanced weather modal with improved UI
    - Major WeatherModal redesign (234 lines changed)
    - Better visual effects and responsiveness
  - Updated DayRow and HourBox components
    - DayRow improvements (73 lines)
    - HourBox enhancements (29 lines)
  - StatBox improvements
    - Enhanced statistics display

### Improvements

- **Control Center**
  - VolumeMixerDetail redesign (607 lines)
    - Complete overhaul of volume mixing UI
    - Better audio device management
  - AudioInputPill and AudioOutputPill improvements
    - Redesigned audio I/O widgets (69-79 lines each)
  - CompactSlider enhancements
    - Better slider controls (25 lines)
  - MediaPill redesign
    - Media control widget overhaul (103 lines)
  - PerformancePill refactoring
    - Performance widget improvements (161 lines)
  - Widget Grid improvements
    - Grid layout system enhancements

- **Dock Control Center**
  - Complete widget grid redesign (224 lines)
    - Full layout system rewrite
  - VolumeMixerDetail enhancements
    - Same improvements as main Control Center
  - All widget improvements mirroring Control Center
    - AudioPills, CompactSlider, MediaPill, PerformancePill
    - ToggleButton and CompoundPill updates

- **TaskBar Control Center**
  - Widget Grid improvements (129 lines added)
    - Grid system additions
  - Full VolumeMixerDetail redesign
    - Complete 607-line redesign
    - All widgets updated (AudioPills, CompactSlider, MediaPill, PerformancePill, ToggleButton, CompoundPill)

- **Spotlight Search**
  - Download badge fix for search results
    - Fixed weird white download Badge on Spotlight search results

### Bug Fixes

- **Spotlight Search**
  - Fixed weird white download badge on search results
    - Removed white background on download indicators
    - Fixed in SpotlightWindow.qml and DotfilesUpdateService.qml

- Various UI and stability improvements

## [3.0.0-beta.2] - 2026-04-20

### New Features

- **Event Horizon Installer**
  - New EventHorizonInstaller.py for system installation
  - Automated setup and configuration

- **Spotlight Search**
  - New spotlight search functionality
  - Quick access search feature

- **Animation Tab**
  - WIP Animation Tab for wallpaper/animation settings
  - Monitor configuration improvements

- **Network Tab**
  - Complete network tab redesign
  - Enhanced network configuration options

### Improvements

- **Mini Panel**
  - Full functionality for all settings
  - Performance optimizations

- **Taskbar**
  - Restored borders and full functionality
  - Performance and smoothness improvements

- **Dock**
  - All errors fixed and optimized
  - Better performance and smoothness aligned with user refresh rate

- **Appdrawer**
  - Performance optimizations

### Bug Fixes

- **Package Manager**
  - Fixed dnf check for updates

- **Hyprland General**
  - Fixed layout option "Scrolling" to properly use "scrolling" instead of "scroller"
  - Fixed Hyprland border slider to use hyprctl keyword for real-time updates

- Various UI and stability improvements

## [3.0.0-beta.1] - 2026-04-09

### New Features

- **Weather Application**
  - Full weather app with detailed modal interface including hourly and daily forecasts
  - Comprehensive weather components: DayCard, HourCard, StatCard, DetailCard
  - Opens with Win+W keybind
  - Integrated weather service for data fetching

- **Package Manager**
  - Complete package management system with modal interface
  - Search, install, update, and remove packages functionality
  - Installed packages tab with package information
  - Updates tab for managing system updates
  - Package source badges and tabbed interface
  - Settings integration for package manager configuration
  - Support for multiple package sources and operations

- **Workspace Overview**
  - Full workspace overview feature with visual workspace management
  - Workspace view and overview widget components
  - Enhanced workspace navigation and display

- **Weather Widgets**
  - Weather Pill widget in Control Center and Dock Control Center
  - Weather Detail components for expanded weather information
  - Integrated weather data display in control centers

### Improvements

- **Compositor Service**
  - Major refactoring (726 lines changed) for improved performance and stability

- **Control Center**
  - Widget Grid complete rewrite with better layout system
  - Detail Host improvements for component hosting
  - Widget Model enhanced data handling
  - Layout utils improved positioning algorithms
  - Weather Detail and Weather Pill integration

- **Dock Control Center**
  - Mirror of Control Center improvements
  - Weather Detail and Weather Pill integration
  - Widget Grid enhancements

- **Wallpaper Tab**
  - Major enhancements and UI improvements

- **Package Manager Service**
  - Multiple fixes and enhancements for functionality
  - Improved package operation handling

### Bug Fixes

- **CachyOS System Logo**
  - Fixed positioning issues in dock and widgets

- **Settings**
  - Proper closing behavior when modal is dismissed

- Various UI and stability improvements
