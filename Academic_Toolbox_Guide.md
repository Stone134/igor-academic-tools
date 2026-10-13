# Academic Toolbox for Igor Pro 8

One standalone procedure combines the useful features of all six original files. This revision adds Vref plotting and separate Electrical and OECT panel selections; existing UV–vis, styling and extra tools remain available.

## Start here

1. In Igor, open `Academic_Toolbox.ipf` as a procedure and compile it. Save it in your User Procedures folder first.
2. Choose **Macros → Academic Toolbox - Electrical** or **Macros → Academic Toolbox - OECT**. Electrical provides Id/time and Vref/time plots; OECT provides transfer and steady-state plots. Both panels share the loaded electrical dataset and preferences, and retain UV–vis and appearance controls. You can also run `AT_ElectricalPanel()`, `AT_OECTPanel()`, or the backward-compatible `AT_Panel()` from the command line (Command–J).
3. Choose **Red (dark to light)** or **Blue (dark to light)** in the panel. This becomes the default for new toolbox plots.
4. Use **Load single file(s)…**, followed by **Plot Id vs time** or **Plot spectra**.

To include the toolbox in another experiment, add `#include "Academic_Toolbox"` to that experiment's main procedure and compile. You do not need to include any of the six older files.

If opening the procedure editor causes a crash in this installed Igor 8.04, the following commands load it without displaying that editor. Execute each line separately:

```igorpro
OpenProc/V=0 "Macintosh HD:Applications:Igor Pro 8 Folder:User Procedures:Academic_Toolbox.ipf"
Execute/P "COMPILEPROCEDURES "
AT_Panel()
```

An accessibility-related crash was encountered while inspecting Igor's visible procedure editor during development; hidden loading and compilation worked.

## Your usual workflows

### Load electrical data and plot Id versus time

Click **Electrical → Load single file(s)…**. The ADCMT test file has its column names on line **0**: `Time`, `GateI`, `GateV`, `DrainI`, `DrainV`. Choose the actual units in the source file; the normal ADCMT settings are **A** and **s**. Units are explicit choices, not inferred from the column name.

The loader retains every numeric source column in `root:AT_Elec:Native`. It also creates working DrainI in amperes, Time in seconds, GateV in volts and optional Vref in volts under `root:AT_Elec:Data`. The plot converts amperes to **µA** for display. Missing time is reported and skipped instead of inventing seconds from point indices.

Click **Plot Id vs time**. Select the desired files from the list, choose a gradient, and keep the default **Reverse current axis? → Yes** for your preferred inverted Id axis (choose No for the conventional direction). You can shift each trace's starting time to zero. Time still increases from left to right. Negative current remains negative; axis inversion does not change the data signs. Transfer and steady-state plots default to inverted Vg and Id axes.

**Load folder…** imports matching files directly inside the folder you select. It does not search subfolders. For your ADCMT directory, select a measurement/date subfolder when you want a batch. All files in a batch must use the selected units. Loading is additive by default; **Clear data already loaded? → Yes** removes the corresponding toolbox dataset from the experiment.

### Plot reference-electrode voltage versus time

Load files through either panel using the same electrical loader. The optional `Vref` column (also recognized as `ReferenceVoltage` or `ReferenceElectrodeVoltage`, case-insensitively) is copied to `<base>_Vref` in `root:AT_Elec:Data`. Supply voltage values in **V**; no automatic mV conversion is performed. Native columns remain unchanged. Files without Vref still load normally when they contain the required DrainI column. Reload previously imported files to create the new working Vref waves.

In **Electrical**, click **Plot Vref vs time**, or run `AT_E_PlotVref()`. Choose files, category filtering, colors, line width, legend and optional time-zero shift just as for Id/time. The plot uses the shared academic appearance, **Time (s)** and **Vref (V)** labels, and an inverted Vref axis by default. Smaller voltages appear higher; data signs are unchanged. Choose **Reverse Vref axis? → No** for a conventional axis. Time increases left to right. Missing, empty, unequal-length or entirely nonfinite Time/Vref pairs are skipped; no time wave is fabricated. Time-zero shifting also requires a finite first time value. No valid selection produces an alert and removes the empty graph.

Use **OECT** for **Plot Id vs Vg (transfer)** and **Plot steady-state Id vs Vg**. Loading or clearing data in either panel affects the same dataset. Closing one panel leaves the other open.

### Correct and plot UV–vis

1. Choose **UV-vis → Load single file(s)…**.
2. Select **JASCO ASCII** for your exported `.txt` and `.csv` spectra. The loader reads `XYDATA` and `NPOINTS`, ignores the instrument footer, and accepts descending wavelengths. Plain two-column text is a separate format option; specify how many header lines to skip.
3. Click **Correct (jump + reference baseline)** if those corrections are appropriate for the measurement.
4. Click **Plot spectra**, choose raw or corrected data, select files, and choose red or blue. The usual wavelength range is 400–1600 nm; either limit can be set to 0 for automatic range.

Native `.jws` instrument files are not supported; export them as JASCO ASCII first. The folder loader accepts `.txt;.csv` by default and processes only the selected folder.

**What “correct” means here:** it preserves the methods used by your previous codes, with selectable settings:

- **Detector jump:** by default the visible branch ends at 850 nm and the NIR branch starts at 851 nm. Fit five points on each side, skipping two near the transition; estimate the two fitted values at the seam and shift the NIR branch by their difference. A single-point fallback is used if the fitted shift worsens the immediate discontinuity. Optional blanking marks transition points as NaN.
- **Reference baseline:** choose a reference spectrum, or automatically search all spectra for the lowest absorbance inside the chosen window (default 1200–1300 nm). Its minimum determines one shared anchor wavelength. Subtract each spectrum's own absorbance at that wavelength from that spectrum. Choose 1000–1500 nm to reproduce the wider search window of the older targeted processor.

This is a constant offset plus optional detector-branch offset. It does not perform blank-spectrum subtraction, scattering correction, smoothing, or instrument calibration. A minimum inside an absorption band is not automatically a physically valid zero baseline.

Every correction starts from `Raw`, so repeating it does not accumulate shifts. It rebuilds `Corr` for the loaded UV dataset, including spectra not currently selected for plotting. Graphs referencing these corrected waves will update. Copy corrected waves first if you want to retain a previous correction version. Missing valid reference values are reported and skipped.

### Red and blue gradients

The panel offers exactly the two requested sequential choices. **Recolour top graph** applies the selected gradient to an existing graph. New plot dialogs inherit the choice but allow an override.

Colors progress from dark to light in **trace order**, with one continuous gradient across the whole graph. Folder imports are sorted by filename; plot grouping/selection can affect trace order. Color does not automatically encode voltage, elapsed time, or measurement date. A one-trace graph uses the darkest color. The light end remains colored rather than fading completely to white.

The plot dialogs also retain the older category, within-category, and distinct-color options. **Make RGB waves** exposes the red/blue tables under `root:Packages:ColorTables:AcademicToolbox`.

### Academic appearance

Defaults are Arial 16 pt, 2.5 pt curves, 2 pt axes, inward ticks, a mirrored frame and uncluttered backgrounds. Axis labels explicitly show the quantities and units. The code suppresses unit suffixes on ticks in toolbox-generated plots to avoid displaying amperes alongside a µA axis label.

Adjust font size, line/axis thickness, marker size and dimensions in the panel. **Apply to top graph** updates the current graph; **Apply to ALL graphs** affects every graph in the experiment. Appearance changes preserve labels and trace colors. Use **Recolour top graph** separately to change colors.

The default graph resizes with its window. For a fixed plot rectangle, enable **Fixed plot size** and set width/height in cm (defaults 7 × 5 cm). These dimensions describe the plot rectangle, excluding labels and margins. Long filenames can make legends crowded; hide the legend or edit it to short sample labels before publication. Export through Igor's Save Graphics dialog.

## Other retained tools

| Tool | Purpose |
|---|---|
| Plot Id vs Vg | Transfer curves, with current displayed in µA; retains the older convention of reversed voltage/current axes. |
| Plot steady-state Id vs Vg | Average the final chosen number of points per file or per constant-Vg plateau. Plateau detection uses 1e-4 V tolerance and at least three points. New result names preserve earlier steady-state curves. |
| Extra tools → Plot existing waves | Supply full X/Y wave paths; create a graph or append a trace. Electrical source units are explicit and display conversion leaves source waves unchanged. |
| Extra tools → Correct spectra from top graph | Copy graph source XY data into the toolbox, then open the UV correction dialog. Supports explicit X waves or waveform X scaling. Display offsets/multipliers are not included. Replot corrected spectra afterward. |
| Extra tools → Label top graph | Labels for electrical, UV–vis, XRD, conductivity or relative conductivity. Labels alone do not convert data units. |
| Extra tools → Convert XRD 2-theta to q | Creates a new q wave using q = 4π sin(2θ × π/360)/λ, default λ = 1.5418 Å. |
| Extra tools → Stack XRD traces | Uses a logarithmic intensity axis and multiplicative display spacing, leaving source waves unchanged. |

The legacy conductivity tools only format plots; neither the old files nor this toolbox calculates conductivity from resistance or device dimensions.

## Summary of all six original files

| Original file | Functions and behavior | Consolidation |
|---|---|---|
| `OECT_Electrical.ipf` | ADCMT folder and multiple-file import; filename/sample/category parsing; dataset listing/deletion; transient, transfer and steady-state plots; curve selection; gradients; axes, legends and appearance preferences. | Retained as `AT_E_*`; explicit input units, original-column retention, inverted Id by default with an optional conventional direction, and no fabricated time. |
| `UVvis_Spectra.ipf` | JASCO/plain-text import; ascending wavelength conversion; common-grid interpolation; detector-jump and common-anchor baseline correction; raw/corrected plotting; duplicated selection, color and style helpers. | Retained as `AT_U_*`; shared helpers consolidated, native XY preserved, every grid point checked, out-of-range interpolation becomes NaN. |
| `OECT_Panel.ipf` | Includes the two large files and provides the electrical/UV/color/appearance control panel. | Replaced by `AT_Panel` and `AT_Button` inside the single file. Gradient choice now persists for new plots. |
| `Style Panel.ipf` | `OpenStylePanel` creates a formatting panel; `ApplyAcademicStyle` sets Arial, boxed axes, lines, colors and legend; `LabelAxes`/`LabelAxes2` label electrical and UV axes. | One shared adjustable style and label dialog. The old general style could erase the Y label and overwrite colors; appearance and color controls are now separate. |
| `UV-Vis Spectra Processor.ipf` | `ProcessSpectra_Targeted` edits graph waves directly, aligns 850/851 nm, finds the named reference minimum at 1000–1500 nm, then zeroes all curves at that wavelength. `ApplyAcademicStyle_UV` styles the graph; `UVVisProcessorPanel` and its two callbacks expose processing and labels. | Selectable reference added to the main correction dialog; graph-based correction works on copies. No dependence on a specially named “red” wave. |
| `Modify UV XRD Cond.ipf` | `ModifyUV` and `ModifyXRD` format axes; `ConvertToqz` performs Cu Kα conversion; `SplitXRDTrace` spaces curves; `ModifyCond`/`ModifyRelCond` format conductivity/time graphs. | Label, q-conversion and XRD display-stack tools retained. The old stacker dereferenced optional waves even when absent; the replacement works from actual graph traces. |

### Important fixes compared with the originals

- Fixed the encoding selector: the old mapping treated 255 as UTF-8, but it means binary. Encoding names now resolve through Igor's encoding lookup.
- Added support for the comma-separated `NPOINTS` header found in your JASCO CSV sample.
- Filename parsing defaults to `auto`, accommodating spaces and underscores. A detected `s1`–`s99` token sets sample identity; absent tokens produce `unknown` without rejecting the file. The following three tokens define category by default. Adjust that count for shorter names.
- Unique names protect repeat imports and steady-state results from overwriting earlier waves.
- Original UV grids remain available; working spectra share the first loaded file's wavelength grid. Later data outside that grid are retained in Native but are not included in common-grid plots.
- Correction is repeatable and checks finite data, monotonic wavelength axes, overlap and reference availability.
- Toolkit names and data folders use `AT_` to coexist with your older procedures.

## Data organization and scripting

| Location | Contents |
|---|---|
| `root:AT_Elec:Native:<base>` | All numeric electrical columns in original source units. |
| `root:AT_Elec:Data` | Working DrainI (A), Time (s), GateV (V), optional Vref (V). |
| `root:AT_Elec:SS` | Generated steady-state curves. |
| `root:AT_UV:Native` | Per-file native wavelength/absorbance pairs, ordered ascending. |
| `root:AT_UV:Wavelength` | First imported spectrum's grid, used by Raw and Corr. |
| `root:AT_UV:Raw` | Uncorrected spectra on the shared grid. |
| `root:AT_UV:Corr` | Most recently corrected spectra; notes record settings. |
| `root:Packages:AcademicToolbox` | Appearance, gradient and electrical input-unit preferences for the experiment. |

Both data roots also hold filename, base-name, category and sample metadata. Preferences persist within an experiment and are saved with it, rather than being global application settings.

`AT_LoadPath(fullPath,kind,[fmt,skipLines,encoding])` is an optional scriptable single-file entry point. `kind=1` loads electrical data; `kind=2` loads UV. For UV, `fmt=1` means JASCO and `fmt=2` means plain text. `skipLines` is the zero-based header line for electrical data and the number of skipped lines for plain UV. Electrical scaling uses the current unit preferences, default A/s. Return values are 0 (not loaded), 1 (loaded), or 2 (loaded but no recognized sample token). On this Mac/Igor 8 it accepts an existing POSIX path or an Igor colon-separated path.

## Validation

For this revision, source checks confirm retained original functions, unique function names, balanced procedure blocks, Vref loader/plot/button wiring and separate panel routes. The new code uses the existing Igor 8 plotting/style helpers and no newer-version API. Axis inversion uses reversed numeric limits, as documented by [WaveMetrics SetAxis](https://docs.wavemetrics.com/igorpro/commands/setaxis).

This revision compiled and ran in the installed Igor Pro 8 application. The existing `AT_SelfTest()` passed. Synthetic electrical files with and without Vref loaded successfully, the inverted Vref plot was visually inspected, and the separate OECT panel opened with its expected controls. No new real measurement files were supplied. See `VALIDATION.md` for exact scope and remaining checks.
