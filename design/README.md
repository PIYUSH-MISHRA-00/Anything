# Design

This directory holds visual design references for the Anything platform.

## Structure

```
design/
  README.md                              # This file
  stitch/
    product_foundation/                   # Stitch export pairs + design docs
      <feature_name>/
        code.html                         # Reference HTML prototype
        screen.png                        # Visual validation screenshot
      anything_canonical_software_design_specification_sds.md
```

## Stitch Design Materials

**Stitch is the visual reference, not the implementation.** These materials define _what_ the UI should look like, not _how_ it is built.

- **`code.html` files** are reference HTML prototypes exported from Stitch. They are static mockups for visual inspection only. **They are NOT production Flutter code.** Do not copy-paste from them into the Flutter codebase.

- **`screen.png` files** are visual validation references. Use them to confirm that the native Flutter implementation matches the intended design.

## Runtime Assets

Runtime assets (fonts, icons, images used by the app) belong in `assets/`, not in design directories. Design directories contain reference material only.

## Flutter Implementation

Flutter components must recreate the design natively using Dart/Flutter widgets. Use the Stitch HTML prototypes and screenshots as the source of truth for layout, spacing, color, and typography, then translate them into Flutter equivalents.
