# Validation — 2026-10-13

This revision was loaded and compiled in the installed Igor Pro 8 application, using hidden procedure loading to avoid the previously reported procedure-editor accessibility crash.

## Passed

- Native procedure compilation and execution.
- Existing `AT_SelfTest()`: gradients for 1–25 traces, grid validation, descending XY alignment, UV seam correction and baseline anchoring, repeatability, raw preservation, steady-state averaging and demo styling.
- Synthetic tab-separated electrical import with Time, GateV, DrainI and Vref. Working Vref retained 0.1 and 0.3 V endpoints exactly.
- Synthetic electrical file without Vref imported successfully (return value 1).
- Vref plot with both files selected: missing-Vref file skipped; valid curve plotted with Time (s) and Vref (V), academic style, and smaller voltages at the top. Visually inspected: time 0–2 s, voltage 0.1–0.3 V, inverted bounds 0.35 at bottom / 0.05 at top.
- OECT panel opened separately with transfer and steady-state buttons; Electrical panel uses Id/time and Vref/time buttons. Shared UV, color and appearance controls retained.
- Static checks: every original function retained, no duplicate function names, balanced procedure/control blocks, Igor 8 version pragma retained.

## Limits and suggested follow-up

No new real measurement files were supplied. The malformed-pair guards were reviewed in source; each error branch and every dialog option was not exercised interactively. Existing hard-coded validation-directory helpers were preserved and not rerun because their old fixtures were not provided. For your measurements, load a file containing Vref in volts, verify its time units, and compare the plotted endpoints with the source. Check both red and blue gradients, time-zero shifting, and conventional-axis selection as needed.
