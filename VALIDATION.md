# Validation — 2026-10-13

## Latest update: multiple-sample overlays and standalone Vg/time

Passed source checks:

- Preserved all 77 original functions; the procedure now has 89 unique functions with balanced blocks and the Igor 8 version pragma. The diff passes whitespace checks.
- Vg and Vref overlays use separate short trace names for each sample. Re-adding the same sample/quantity updates only that overlay; other samples remain plotted. Legacy fixed-name overlays are still recognized.
- The interactive selector uses the existing checkbox picker for multiple samples and excludes missing, empty or entirely nonfinite Time/voltage pairs. Each overlay copies its own selected Id trace's displayed time offset/multiplier.
- The voltage legend scans all managed overlays. Right-axis labels reflect Vg, Vref or both. Gradient recoloring preserves all right-axis grey overlays without mistaking ordinary standalone traces for overlays.
- `AT_E_PlotVg()` creates a new voltage-only graph with the existing category/file selection, colors, time-zero shift, optional legend and normal/inverted axis choice. Vg and Vref share the same plotting helper, retaining previous Vref behavior.
- Electrical panel and Macros menu entries were checked against their callbacks. Independent source review found no blocking issue.

Native runtime validation remains pending because Igor was in use for interactive graph editing. `AT_SelfTest()` now includes `AT_TestVoltagePlots()`, a regression check prepared for execution in a fresh experiment. It checks two Vg samples coexisting, re-add without duplication, Vref coexistence, separate sample time origins/multipliers, grey preservation after recoloring, a standalone two-sample Vg graph, axis inversion and unchanged source values. These new checks were not executed during this turn.

To verify interactively, compile the update, reopen the Electrical panel, plot Id/time for at least two samples, and select both under **Add Vg vs time to graph**. Re-add one and confirm the other remains. Then use **Plot Vg vs time (new)** and confirm a new graph contains only the selected GateV traces with Time (s) and Vg (V) labels.

## Previous update: fixed SI units, filename parsing and voltage overlays

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

## Previous Vref/separate-panel revision

The previous revision was loaded and compiled in Igor Pro 8 using hidden procedure loading. These results apply to that revision:

- `AT_SelfTest()` passed: gradients for 1–25 traces, grid validation, descending XY alignment, UV seam correction and baseline anchoring, repeatability, raw preservation, steady-state averaging and demo styling.
- Synthetic files with and without Vref imported successfully.
- The Vref/time graph was visually inspected with academic appearance, correct labels and an inverted Vref axis.
- The separate OECT panel opened with transfer and steady-state controls.

The old hard-coded validation-directory helpers were preserved and updated for fixed SI input semantics; their original fixture-based runs were not repeated in this update.
