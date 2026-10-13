# Validation — 2026-10-13

## Latest update: fixed SI units, filename parsing and voltage overlays

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
