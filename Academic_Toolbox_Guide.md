# Academic Toolbox user guide

This guide describes the simplified **2026-10-16** version of [Academic_Toolbox.ipf](Academic_Toolbox.ipf), for Igor Pro 8 or later. See the [README](README.md) for installation and a quick start.

## Open the panels

Use the two entries under **Macros**, or run:

~~~igorpro
AT_ElectricalPanel()
AT_UVPanel()
~~~

`AT_Panel()` opens Electrical/OECT. Each panel has its own saved color choice; both expose the same graph actions. Bring the intended graph to the front before using a graph-action button.

The old separate OECT panel, Time Overlays submenu, Extra Tools, Appearance controls, and Make RGB waves command are no longer present. The standalone `AT_E_PlotVg()` command from an earlier revision is not part of this version.

## Electrical import

Use **Load single file(s)...** for one or more files, or **Load folder...** for files directly inside a selected folder. Folder loading does not recurse into subfolders. The default electrical extension is `.txt`; enter `.txt;.csv` to include both.

Import options are the zero-based column-header line, encoding, and whether to clear previously loaded electrical data. Header line **0** means that the first row contains column names. Encoding choices are Windows-1252, UTF-8, MacRoman, or Igor's automatic choice. Loading is additive by default.

Inputs use **A, V, and s**, with no unit-conversion prompt. Toolbox current graphs display amperes as **µA** using a display multiplier; source values stay in amperes. Legacy input-scale settings do not convert data.

All imported columns, including numeric and text columns, are copied to `Native` and `Data`. Recognized current, voltage, and time aliases also receive canonical names for plotting. A missing DrainI column does not prevent import; each plotting command requires its own relevant columns. The loader does not invent a Time column.

### Wave names and metadata

For `B051 s2 Ph2phos -0.5V 1800s.txt`:

| Item | Result |
| --- | --- |
| Base name | `s2_Ph2phos_-0.5V_1800s` |
| Time wave | `Time_s2_Ph2phos_-0.5V_1800s` |
| Drain-current wave | `DrainI_s2_Ph2phos_-0.5V_1800s` |
| Gate-current wave | `GateI_s2_Ph2phos_-0.5V_1800s` |
| Sample | `s2` |
| Category | `Ph2phos` |

The prefix before the detected sample token is omitted, the final file extension is removed, and every space becomes an underscore. Decimal points in electrical filename sections are preserved where valid in Igor names. Sample numbers can have more than two digits. The first section immediately after `s#` defines the electrical category; later sections remain in the wave name.

Igor cleans invalid names and applies its length limits. Repeated base names receive numeric suffixes. Files without a sample token still load with sample `unknown`; use **List loaded files** to inspect the resulting metadata. Metadata is also recorded in working-wave notes.

Older underscore-delimited filenames and older suffix-style working waves remain readable. On macOS, path handling distinguishes a POSIX path by its leading slash so that literal colon characters in filenames are not mistaken for directory separators.

### Electrical plots

| Button | Data and behavior |
| --- | --- |
| Plot Id vs time | DrainI against Time; optional per-trace time-zero shift; inverted current axis by default |
| Plot Vref vs time | Vref against Time; optional time-zero shift and axis inversion |
| Plot Id vs Vg | Transfer curves; inverted Vg and Id axes |
| Steady-state Id vs Vg | Average the final chosen number of points per file or per Vg plateau; group results by sample and category |
| Add Vg vs time | Add the chosen plotted sample's GateV to the right axis |
| Add Vref vs time | Add the chosen plotted sample's Vref to the right axis |

Plots allow category filtering and file selection. Reversing an axis changes its displayed direction, not the data signs. Time runs left to right. Steady-state plateau detection uses a 0.0001 V tolerance and requires at least three points per plateau; it averages the requested tail region. New result names preserve earlier steady-state curves.

### Voltage overlays

First create an Id/time graph with the toolbox. Click **Add Vg vs time** or **Add Vref vs time**, then choose one Id trace already in that graph.

The voltage uses its corresponding Time wave and copies that current trace's displayed time offset/multiplier. Vg is grey and solid; Vref is grey and dashed. Both use the inverted right-hand voltage axis, with a separate voltage legend.

**This version keeps one Vg overlay and one Vref overlay per graph.** Adding the same quantity for another sample replaces that quantity's previous overlay. Both quantities can coexist. Recoloring leaves these managed overlays unchanged.

The graph must have a suitable toolbox Id/time trace and a compatible voltage column. An unrelated right-axis quantity is rejected. These single-overlay semantics differ from the multiple-sample overlay revision documented in the historical validation notes.

## Gate-step correction for Id and Ig

Click **Correct Id / Ig (gate steps)...**, enter an integer from **1 to 10**, set a nonnegative gate-change tolerance, and select the files.

A change is detected when two consecutive finite GateV values differ by more than the tolerance. The default is **0.0001 V**. Omission starts at the first point carrying the new gate voltage, includes the chosen number of points, and stops at the file boundary. Overlapping masks are combined. No points are omitted at the start of a file unless a recorded change occurs.

The operation creates floating-point copies of DrainI and GateI under `root:AT_Elec:Corr`, with the affected points set to **NaN**. It does not delete rows, interpolate, smooth, or change the raw currents, Time, or GateV. Missing current columns are skipped; each current must have the same length as GateV. Wave notes record the correction settings and source.

After correction:

- **Use corrected currents when available** is enabled for new toolbox current plots and steady-state calculations.
- Existing graph traces directly referencing the selected raw DrainI/GateI waves are switched to corrected copies.
- Repeating correction regenerates those copies from raw data and updates graphs referencing them.
- Unchecking the option affects future plots/calculations only. Replot to return to raw currents.
- Previously generated steady-state waves are not recalculated automatically; regenerate them if needed.

Because every detected voltage change starts an omission interval, a continuously swept or noisy GateV record can lose many plotted points. Choose the tolerance and point count for the measured gate-step sequence.

## Correct and plot UV–vis

1. Choose **UV-vis → Load single file(s)…**.
2. Select **JASCO ASCII** for your exported `.txt` and `.csv` spectra. The loader reads `XYDATA` and `NPOINTS`, ignores the instrument footer, and accepts descending wavelengths. Plain two-column text is a separate format option; specify how many header lines to skip.
3. Click **Correct (jump + reference baseline)** if those corrections are appropriate for the measurement.
4. Click **Plot spectra**, choose raw or corrected data, select files, and choose one of the four color schemes. The usual wavelength range is 400–1600 nm; either limit can be set to 0 for automatic range.

Native `.jws` instrument files are not supported; export them as JASCO ASCII first. The folder loader accepts `.txt;.csv` by default and processes only the selected folder.

**What “correct” means here:** it preserves the methods used by your previous codes, with selectable settings:

- **Detector jump:** by default the visible branch ends at 850 nm and the NIR branch starts at 851 nm. Fit five points on each side, skipping two near the transition; estimate the two fitted values at the seam and shift the NIR branch by their difference. A single-point fallback is used if the fitted shift worsens the immediate discontinuity. Optional blanking marks transition points as NaN.
- **Reference baseline:** choose a reference spectrum, or automatically search all spectra for the lowest absorbance inside the chosen window (default 1200–1300 nm). Its minimum determines one shared anchor wavelength. Subtract each spectrum's own absorbance at that wavelength from that spectrum. Choose 1000–1500 nm to reproduce the wider search window of the older targeted processor.

This is a constant offset plus optional detector-branch offset. It does not perform blank-spectrum subtraction, scattering correction, smoothing, or instrument calibration. A minimum inside an absorption band is not automatically a physically valid zero baseline.

Every correction starts from `Raw`, so repeating it does not accumulate shifts. It rebuilds `Corr` for the loaded UV dataset, including spectra not currently selected for plotting. Graphs referencing these corrected waves will update. Copy corrected waves first if you want to retain a previous correction version. Missing valid reference values are reported and skipped.

UV import retains its own filename options: separator (automatic, spaces, or underscores), number of category tokens (default three), and base-name mode. The fixed one-section electrical category convention does not replace these UV options.

## Graph appearance

New toolbox plots use **Thesis2**. **Apply Thesis2** applies only:

~~~igorpro
ModifyGraph axThick=0.75,btLen=3,fSize=9,lsize=0.75,expand=2,font="Arial",tick=2,mirror=1,standoff=0,width=170.079,height=99.2126
~~~

The width and height are Igor's plot-area dimensions in points. The function does not change unrelated margins, marker settings, axis ranges, or trace colors. Mirroring is applied only where a real right/top axis does not already occupy the opposite edge.

**Restore to default** reconstructs a standalone curve graph with Igor's factory appearance, preserving the wave references, trace/axis assignments, error bars, label text, and display offsets/multipliers. It retains the original graph name after successful reconstruction. User appearance preferences are temporarily disabled for reconstruction and then restored.

Custom ranges and formatting, legends, drawing objects, and other annotations are not copied. Use **Add legend** to create a legend afterward. Graphs with images, contours, or subwindows are left unchanged. If reconstruction fails, the original graph is retained.

**Add legend** adds or refreshes the toolbox legend using Igor's default legend formatting. It does not force a font, size, frame, or position.

## Colors and exact palettes

The panels remember their schemes independently. Plot dialogs inherit the relevant panel's choice and permit a per-plot override. **Recolor** applies the selected panel scheme to the front graph.

| Scheme | Assignment |
| --- | --- |
| Red (dark to light) | Interpolate the red anchors across all data traces in trace order |
| Blue (dark to light) | Interpolate the blue anchors across all data traces in trace order |
| Categories blue & red | First category blue, second red; alternate for further categories; dark-to-light shades within each |
| Distinct category colors | One categorical color for each category |

A single trace uses the darkest gradient color. Trace order, not voltage or date, determines gradient position. More than two categories reuse the blue/red families; use distinct category colors when those families are insufficient. The categorical palette has eight base colors and uses lightened cycles for additional categories, so it is not an unlimited set of distinct hues.

### Gradient anchors

These are 8-bit RGB values in dark-to-light order. The exact interpolated values used by Igor are calculated in the 0–65535 range and rounded to integers.

| Anchor | Red RGB | Blue RGB |
| --- | --- | --- |
| 1 | 103, 0, 13 | 8, 48, 107 |
| 2 | 165, 15, 21 | 8, 81, 156 |
| 3 | 203, 24, 29 | 33, 113, 181 |
| 4 | 239, 59, 44 | 66, 146, 198 |
| 5 | 251, 106, 74 | 107, 174, 214 |
| 6 | 252, 146, 114 | 158, 202, 225 |
| 7 | 252, 187, 161 | 198, 219, 239 |

Categorical base colors, in order: `(0,114,178)`, `(213,94,0)`, `(0,158,115)`, `(204,121,167)`, `(230,159,0)`, `(86,180,233)`, `(140,86,75)`, and `(90,90,90)`.

### Choose a color for one curve

1. Bring the graph to the front.
2. Choose a scheme, then open **Curve color → Exact palette and curve colors...**.
3. Select the target curve from the **Curve** menu.
4. Select a swatch row and click **Apply selected color to curve**.

The picker contains the selected scheme's planned color for each data trace, all seven red and seven blue anchors, and the eight categorical base colors. Its swatches and RGB columns use the same exact 16-bit values as recoloring. The graph rows preview the selected scheme; they do not read back arbitrary colors manually assigned earlier. Selecting a scheme alone does not recolor an existing graph—use **Recolor**.

There is no Make RGB waves button or exported color-table feature. Internal picker waves only support the swatch interface.

## Data folders

| Location | Contents |
| --- | --- |
| `root:AT_Elec:Native:<base>` | All imported source columns, including text |
| `root:AT_Elec:Data` | All column-first working waves and canonical aliases |
| `root:AT_Elec:Corr` | Gate-step-corrected DrainI/GateI copies |
| `root:AT_Elec:SS` | Generated steady-state curves |
| `root:AT_UV:Native` | Native wavelength/absorbance pairs, ordered ascending |
| `root:AT_UV:Wavelength` | Shared wavelength grid from the first imported spectrum |
| `root:AT_UV:Raw` | Uncorrected spectra on the shared grid |
| `root:AT_UV:Corr` | Most recently corrected spectra |
| `root:Packages:AcademicToolbox` | Panel color choices, corrected-current preference, and picker state |

Each data root also holds filename, base-name, category, and sample metadata. Save the Igor experiment to retain loaded data and preferences.

## Scripting

| Function | Purpose |
| --- | --- |
| `AT_Panel()` / `AT_ElectricalPanel()` | Open Electrical/OECT |
| `AT_UVPanel()` | Open UV-vis |
| `AT_E_PlotTransient()` | Interactive Id/time plot |
| `AT_E_PlotVref()` | Interactive Vref/time plot |
| `AT_E_PlotTransfer()` | Interactive Id/Vg plot |
| `AT_E_PlotSteadyState()` | Interactive steady-state calculation/plot |
| `AT_E_AddVg()` / `AT_E_AddVref()` | Add a selected sample's voltage overlay |
| `AT_E_CorrectCurrents()` | Interactive gate-step correction |
| `AT_E_CorrectOne(base,omit,tol)` | Create corrected copies for one base name |
| `AT_E_ApplyLook(graphName,1)` | Apply Thesis2 |
| `AT_RestoreDefault(graphName)` | Restore factory graph appearance |
| `AT_AddLegend(graphName)` | Add a default-format legend |
| `AT_RecolorGraph(graphName,mode)` | Recolor; modes 1–4 follow the table above |
| `AT_ColorPicker(graphName,mode)` | Open exact-color selection |
| `AT_U_Correct()` / `AT_U_PlotSpectra()` | Interactive UV correction/plotting |

An empty graph name selects the front graph for the style, reset, legend, and recoloring functions. Pass an existing graph name to `AT_ColorPicker`.

`AT_LoadPath(fullPath,kind,[fmt,skipLines,encoding])` imports one file without the file picker. Use `kind=1` for electrical or `kind=2` for UV. For UV, `fmt=1` means JASCO (default), and `fmt=2` means plain text. `skipLines` is the zero-based header line for electrical data and the number of skipped lines for plain UV. It returns 0 for not loaded, 1 for loaded, or 2 for loaded without a recognized sample token.

`AT_E_AddVoltage(kind,gName="graphName",currentTrace="traceName")` adds an overlay without its interactive selector: kind 1 is Vg; kind 2 is Vref. The trace must already be an Id/time trace in that graph. A later call for the same quantity replaces its prior overlay.

## Validation

See [VALIDATION.md](VALIDATION.md) for the native Igor checks performed on this revision. The development-only validation module is not bundled in the simplified procedure; the old `AT_SelfTest()` entry point is no longer present.
