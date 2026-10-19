# Validation

## Graph sizing and numeric ticks — 2026-10-19

The updated procedure was loaded and compiled in the user's already-open Igor Pro 8 session. A development helper exercised the public style and checkbox functions using 11 synthetic points spanning 0–10000 seconds and 0 to −10 µA, with source current values stored in amperes.

### Executed checks

- Unchecked sizing applied the Thesis2 plot-area dimensions: 170.079 × 99.2126 points.
- Checking the option removed the fixed width and height; resizing the graph window changed both plot-area dimensions.
- Reapplying Thesis2 while free sizing was enabled kept the dimensions unlocked.
- Unchecking restored the fixed Thesis2 dimensions.
- Graph recreation text contained `tickUnit=1` and the fixed-notation thresholds.
- All source current/time values and their A/s wave-unit metadata remained unchanged.
- The actual Electrical/OECT checkbox was clicked, and the stored preference changed to 1.
- Both panels were visually inspected; the new checkbox, color controls, and palette preview fit without overlap. The UV-vis panel reflected the shared checked state.
- The graph was visually inspected before and after resizing: the left title read **Id (µA)**, the bottom title read **Time (s)**, and ticks showed **0, 2000, …, 10000**, without extra A or ks labels.

Igor printed: `PASS: fixed/free sizing, checkbox callback, Thesis2 while free, plain ticks, raw values and units preserved.`

These checks used synthetic data and focused on the requested sizing and tick-formatting changes. The user's experimental dataset and the full import/correction workflows were not rerun. The development helper is not bundled with the production procedure.

## Simplified toolbox — 2026-10-16

Procedure: [Academic_Toolbox.ipf at de8705a](https://github.com/Stone134/igor-academic-tools/blob/de8705a90e4dce3252b0e7e9d58f8cc7491b985a/Academic_Toolbox.ipf).

The revised procedure was loaded and compiled in the installed Igor Pro 8 application. Electrical/OECT and UV-vis panels were opened and inspected, and the exact-color picker was visually inspected.

An isolated development module used a synthetic tab-separated file named `B999 s123 Ph2phos -0.5V test.txt`, with 20 rows and eight columns: Time, GateI, GateV, DrainI, DrainV, Vref, Temperature, and a text Status column.

### Executed checks

- All eight columns were imported, including the text values.
- Sample `s123`, category `Ph2phos`, column-first names, and the decimal voltage section were preserved; repeat import produced a unique base name.
- Numeric current and time values matched the fixture.
- Gate-step masks handled one-point omission, ten-point overlapping intervals, end clipping, and no automatic omission at the file start.
- Invalid omission counts (0, 11, and a noninteger) were rejected.
- Two-point correction produced NaNs in both Id and Ig copies, preserved all unmasked values, and left raw current values unchanged.
- Repeating correction rebuilt copies from raw data.
- Thesis2 preserved an existing custom margin, minor-tick setting, and trace line style while applying the requested properties.
- A dual-axis style error was found and fixed: mirrored edges are now applied only where a real opposite axis is absent. The corrected native run completed without that error.
- The darkest red palette value was verified as Igor RGB `(26471,0,3341)`; the managed voltage overlay was excluded from recoloring.
- Default reset removed custom appearance while retaining two traces, their axis assignments, label text, and the current/time display transformations. The transformation was confirmed in the generated graph recreation text.
- The picker displayed the planned graph palette, red/blue anchor swatches, categorical swatches, and exact 16-bit RGB values.

### Scope and limitations

The current checks used synthetic data; the user's experimental dataset was not re-imported in this validation run. This was not a comprehensive runtime regression of every UV correction, file format, dialog, or color/category combination. Existing UV processing was retained, and its earlier results are historical evidence rather than a fresh run.

The validation helper and fixture were development files and are not included in this repository. There is no `AT_SelfTest()` command in the current simplified procedure.

The current version has one Vg and one Vref overlay per graph. Multiple-sample overlays and standalone `AT_E_PlotVg()` described below belong to an earlier revision and are not current features.

## Historical notes — 2026-10-13 and earlier

The following records are retained for provenance. References to old controls, helper functions, and pending tests apply to their respective revisions, not to the current README.

### Latest update: multiple-sample overlays and standalone Vg/time

Passed source checks:

- Preserved all 77 original functions; the procedure now has 89 unique functions with balanced blocks and the Igor 8 version pragma. The diff passes whitespace checks.
- Vg and Vref overlays use separate short trace names for each sample. Re-adding the same sample/quantity updates only that overlay; other samples remain plotted. Legacy fixed-name overlays are still recognized.
- The interactive selector uses the existing checkbox picker for multiple samples and excludes missing, empty or entirely nonfinite Time/voltage pairs. Each overlay copies its own selected Id trace's displayed time offset/multiplier.
- The voltage legend scans all managed overlays. Right-axis labels reflect Vg, Vref or both. Gradient recoloring preserves all right-axis grey overlays without mistaking ordinary standalone traces for overlays.
- `AT_E_PlotVg()` creates a new voltage-only graph with the existing category/file selection, colors, time-zero shift, optional legend and normal/inverted axis choice. Vg and Vref share the same plotting helper, retaining previous Vref behavior.
- Electrical panel and Macros menu entries were checked against their callbacks. Independent source review found no blocking issue.

Native runtime validation remains pending because Igor was in use for interactive graph editing. `AT_SelfTest()` now includes `AT_TestVoltagePlots()`, a regression check prepared for execution in a fresh experiment. It checks two Vg samples coexisting, re-add without duplication, Vref coexistence, separate sample time origins/multipliers, grey preservation after recoloring, a standalone two-sample Vg graph, axis inversion and unchanged source values. These new checks were not executed during this turn.

To verify interactively, compile the update, reopen the Electrical panel, plot Id/time for at least two samples, and select both under **Add Vg vs time to graph**. Re-add one and confirm the other remains. Then use **Plot Vg vs time (new)** and confirm a new graph contains only the selected GateV traces with Time (s) and Vg (V) labels.

### Previous update: fixed SI units, filename parsing and voltage overlays

Passed checks:

- The supplied real measurement file is valid ASCII tab-separated text. Header line 0 contains Time, GateI, GateV, DrainI, DrainV and Vref. All 14,401 data rows contain six finite numbers; time increases monotonically.
- Native Igor history confirms the previous importer attempted to load only ` quasi.txt` and reported macOS error -43 (file/folder not found), then incorrectly described the failure as a missing DrainI column.
- macOS path conversion confirms a POSIX colon in the filename appears as a literal slash in the HFS basename. The revised path helper identifies POSIX paths by a leading slash and otherwise uses HFS separators on Mac, preserving that filename.
- Electrical input uses source values directly in A, V and s, including when an older experiment retains non-SI scale preferences. GateV and Vref working-wave units are V; Time is s and DrainI is A. The input-unit function has no prompt.
- Static checks retain all 77 original functions, with 84 unique function names, balanced procedure/control blocks, Igor 8 version pragma and no diff whitespace errors.
- Independent code review checked Igor 8 syntax and bundled examples for AppendToGraph trace naming, wave-reference rebinding, AxisList, Legend string expressions and TraceInfo offset/multiplier parsing.
- Overlay wiring was reviewed for current-sample selection, grey right-axis traces, copied displayed time alignment, same-kind replacement, combined Vg/Vref labels, source-wave preservation and grey preservation during recoloring. Existing toolbox GateV/Vref traces on the right axis are supported; unrelated right-axis data are rejected.

Native compilation and runtime testing of this latest update remain pending. Igor was being used for interactive graph editing during this turn; attempts to start isolated validation could not reach a separate test instance. No new native compile or runtime result is claimed for the latest code.

Suggested native checks: compile the updated procedure; import the supplied file with header line 0 and verify 14,401 points and first values Time=0.28749896 s, DrainI=-3.86e-9 A, GateV=0 V, Vref=-0.02902479 V. Plot Id/time, add each overlay for that sample, verify copied time-zero alignment and appropriate right-axis titles. Add both overlays, repeat one to confirm replacement, and recolor to confirm both remain grey. Close/reopen the Electrical panel to reveal its new buttons.

### Previous Vref/separate-panel revision

The previous revision was loaded and compiled in Igor Pro 8 using hidden procedure loading. These results apply to that revision:

- `AT_SelfTest()` passed: gradients for 1–25 traces, grid validation, descending XY alignment, UV seam correction and baseline anchoring, repeatability, raw preservation, steady-state averaging and demo styling.
- Synthetic files with and without Vref imported successfully.
- The Vref/time graph was visually inspected with academic appearance, correct labels and an inverted Vref axis.
- The separate OECT panel opened with transfer and steady-state controls.

The old hard-coded validation-directory helpers were preserved and updated for fixed SI input semantics; their original fixture-based runs were not repeated in this update.
