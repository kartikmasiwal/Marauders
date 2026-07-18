# Design Implementation

Marauders follows the supplied Monument Guide specification and HTML references.

- Palette: sandstone `#FEF9EF`, terracotta `#6D2325`, muted gold `#775A19`, and status teal `#004544`.
- Shape: 12-24 point continuous corners, pill statuses, and circular AR controls.
- Depth: tonal surfaces and native thin/ultra-thin materials instead of heavy shadows.
- Navigation: ticket-oriented app tabs and the reference Map, Scan, Info tour bar.
- Maps: the three supplied PNG maps are bundled locally. Hotspots use normalized coordinates so map interactions scale across iPhone sizes.
- Typography: rounded system headings approximate Plus Jakarta Sans without requiring a separately licensed font bundle; body text uses the native system face for Dynamic Type support.

The implementation was derived from the supplied Monument Guide design specification, HTML references, and map images. No remote image URLs or API credentials are used by the app.
