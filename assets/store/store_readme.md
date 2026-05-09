# TradePact — App Icon Spec

## Dimensions
- 512 × 512 px (Play Store)
- 1024 × 1024 px (App Store)

## Design Concept

### Background
- Solid fill: `#0D0D0D` (app background color — no rounded corners at source, the store adds them)

### Primary Element — Candlestick Chart Icon
- Three stylised candlestick bars arranged left-to-right, ascending
- Bar color: `#C9A84C` (gold accent)
- Wicks: thin gold lines extending above/below each bar
- Bars sized roughly 40% of canvas height, centred slightly above centre

### Secondary Element — "T" Lettermark (optional alternate)
- Bold serif or geometric "T" in gold `#C9A84C`
- Centred, occupies ~50% of canvas
- Subtle candlestick motif embedded in the crossbar of the T

### Style
- Flat design, NO gradients
- NO shadows
- Padding: 10% of canvas on all sides (keeping the icon clear of Play Store rounded crop)

## Export Formats Required
| Asset | Size | Format |
|---|---|---|
| Play Store icon | 512 × 512 | PNG (no alpha) |
| App Store icon | 1024 × 1024 | PNG (no alpha) |
| Adaptive icon foreground (Android) | 108 × 108 dp | PNG |
| Notification icon | 24 × 24 dp | White silhouette PNG |

## Files to Place
```
android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png   (192×192)
android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png    (144×144)
android/app/src/main/res/mipmap-xhdpi/ic_launcher.png     (96×96)
android/app/src/main/res/mipmap-hdpi/ic_launcher.png      (72×72)
android/app/src/main/res/mipmap-mdpi/ic_launcher.png      (48×48)
ios/Runner/Assets.xcassets/AppIcon.appiconset/             (all sizes)
```

Recommended tool: `flutter_launcher_icons` package for automated generation.
