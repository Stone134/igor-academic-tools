# Igor Academic Tools

A single procedure file for electrical/OECT measurements and UV–vis spectra in **Igor Pro 8 or later**.

The current version provides two independent panels: **Electrical / OECT** and **UV-vis**, each with graph-style controls, four color schemes, and an exact-color picker.

## Quick start

1. Download [Academic_Toolbox.ipf](Academic_Toolbox.ipf).
2. Open it as a procedure file in Igor and compile. Replace any older loaded copy rather than loading both versions.
3. Open either panel from **Macros → Academic Toolbox - Electrical / OECT** or **Macros → Academic Toolbox - UV-vis**.
4. Use **Load single file(s)...** or **Load folder...**, then choose a plot.

The panels can also be opened from Igor's command line:

~~~igorpro
AT_ElectricalPanel()
AT_UVPanel()
~~~

`AT_Panel()` remains an alias for the Electrical/OECT panel. For reuse across experiments, place the file in Igor's User Procedures folder and add `#include "Academic_Toolbox"` to the experiment's main procedure.

For automatic loading, keep the full `Academic_Toolbox.ipf` in **User Procedures** and place [Academic_Toolbox_Loader.ipf](installation/Academic_Toolbox_Loader.ipf) in **Igor Procedures**. The loader includes the maintained User Procedures file. Back up and remove any older full toolbox copy from **Igor Procedures**; loading both full copies can cause duplicate-constant/function errors or leave an older correction active. Restart Igor or unload the older procedure before compiling the loader.

## Panels

| Electrical / OECT | UV-vis |
| --- | --- |
| Import all columns from electrical text files | Import JASCO ASCII or plain two-column spectra |
| Plot Id vs time, Vref vs time, and Id vs Vg | Plot raw or corrected spectra |
| Calculate steady-state Id vs Vg | Correct detector jumps and a reference baseline |
| Add Vg or Vref to an Id/time graph | Retain native data and a shared wavelength grid |
| Remove gate-step artifacts and close gaps in Id and Ig copies | Keep raw spectra separate from corrected spectra |

Both panels include **Apply Thesis2**, **Restore to default**, **Add legend**, **Recolor**, **Curve color**, and a **Free graph size (resize window)** checkbox.

## Electrical file naming

Supply electrical data in **A, V, and s**. Set the header line to **0** when column names occupy the first row. All columns, including text columns, are retained.

For a filename such as:

~~~text
B051 s2 Ph2phos -0.5V 1800s.txt
~~~

working wave names include:

~~~text
Time_s2_Ph2phos_-0.5V_1800s
DrainI_s2_Ph2phos_-0.5V_1800s
GateI_s2_Ph2phos_-0.5V_1800s
GateV_s2_Ph2phos_-0.5V_1800s
~~~

The experiment prefix before `s2` is omitted; spaces become underscores. Sample metadata is `s2`, and category metadata is `Ph2phos`, the first section after the sample. Extra columns use their imported column headers as prefixes. Repeated imports receive unique suffixes.

## Graph style and colors

**Apply Thesis2** applies the following baseline appearance. New toolbox plots use the same style:

~~~igorpro
ModifyGraph axThick=0.75,btLen=3,fSize=9,lsize=0.75,expand=2,font="Arial",tick=2,standoff=0
ModifyGraph tickUnit=1,lowTrip=1e-15,highTrip=1e15
~~~

Mirroring (`mirror=1`) is applied only to edges without a real opposite right/top axis. Applying Thesis2 preserves unrelated existing settings, range bounds, trace display multipliers, and trace colors. It also applies the electrical axis directions, tick formatting, and borderless legends described below.

### Resize the graph freely

Bring the intended graph to the front, then check **Free graph size (resize window)** under **Graph style and colors**. Drag the graph window's edges or corner to change width and height independently.

- **Checked:** Igor uses automatic plot-area sizing (`width=0,height=0`), so the graph follows the window.
- **Unchecked:** restores the fixed Thesis2 plot area, `width=170.079,height=99.2126` points.
- Changing the checkbox affects the front graph immediately. New toolbox plots and **Apply Thesis2** honor the setting; other open graphs are not changed automatically.
- The Electrical/OECT and UV-vis panels share this setting. It starts unchecked and is retained when you save the experiment.

### Axis direction, units and numbers

**Id, Vg, and Vref axes are reversed by default.** Reversed fixed ranges also set Igor's **Reverse axis** checkbox, so switching to autoscale retains that direction. Time remains left to right. Plot dialogs that offer a reverse-axis choice still allow **No**; clicking **Apply Thesis2** later restores the reversed direction on recognized electrical axes. Existing autoscale mode, zero handling, and range algorithm are retained.

Units appear in axis titles, such as **Id (µA)** and **Time (s)**, without extra unit text beside the tick labels. Ordinary measurement ranges use full numbers: for example, **1000** seconds instead of **1 ks**. Extremely small or large values outside the fixed-notation thresholds above may still use exponential notation.

Linear **Id** ticks use **one decimal place**, such as `−2.0, −1.5, −1.0, −0.5`, with zero shown as **`0`**. The toolbox chooses a major-tick interval for the current range. After changing the range substantially, click **Apply Thesis2** again to recalculate that interval. Voltage and UV-vis axes retain their own tick precision; logarithmic current axes retain logarithmic tick formatting.

For an Id range entirely below 0.1 µA in magnitude, ticks use one decimal plus an explicit power-of-ten scale. For example, a `0.005 µA` tick is displayed as `0.5` with **×10⁻²** shown on the axis. This avoids rounding every tick to `0.0`. Applying the style clears any separate axis prescale exponent so it cannot silently rescale the µA numbers a second time; source data and the trace's A-to-µA multiplier are unchanged.

The extra **A** came from the current wave's ampere metadata, even though the plotted current was already multiplied by `1e6` for µA display. **ks** was Igor's automatic engineering prefix for thousands of seconds. This update changes tick formatting while preserving source values, wave units, and display multipliers.

For an existing graph, click **Apply Thesis2** to apply the reversed electrical axes, tick formatting, and legend-frame removal. If a panel was already open when you replaced the procedure, close and reopen it to show the checkbox.

### Legend borders

New plot legends and **Add legend** use **no black rectangular frame**. **Apply Thesis2** also removes frames from existing legends while retaining their text, symbols, and positions. Other annotation types are unchanged.

**Restore to default** rebuilds a standalone curve graph using Igor's factory appearance. It retains the data, axis assignments, label text, error bars, and display offsets/multipliers. Custom axis ranges, formatting, legends, and other annotations are not retained; use **Add legend** afterward. Image, contour, and subwindow graphs are not supported by this reset. Factory reset can restore automatic SI tick formatting; click **Apply Thesis2** afterward to restore the toolbox tick style and sizing preference.

| Color option | Behavior |
| --- | --- |
| Red (dark to light) | One continuous red gradient across data traces |
| Blue (dark to light) | One continuous blue gradient across data traces |
| Categories blue & red | Alternate blue/red by category, with shades within each category |
| Distinct category colors | One categorical color per category |

The Electrical and UV-vis panels remember their color choices separately. **Recolor** applies the selected scheme to the front graph, preserving managed voltage overlays. **Curve color → Exact palette and curve colors...** shows swatches and exact Igor RGB values (0–65535), and lets you apply a selected color to one curve.

## Correct Id / Ig after gate changes

1. Click **Correct Id / Ig (gate steps)...**.
2. Choose **1–10 points** and a gate-change tolerance (default **0.0001 V**).
3. Select the files to correct.

Starting at the first point carrying each new gate voltage, correction removes the selected rows from **separate corrected copies** and shifts all retained points into consecutive earlier time slots. The shift accumulates at every transition: removing two points moves the second Vg segment left by two sample positions, the third by four, and so on. Overlapping removal intervals are combined and counted once; the start of a file is preserved without a recorded gate change. Raw data remain unchanged.

Corrected Id, Ig, GateV and Vref retain the same rows in `root:AT_Elec:Corr`. Corrected Time uses the first retained-count slots of the raw Time wave, shortening the displayed time axis and closing the deleted intervals without inserting NaNs. `SourceTime` and `SourceIndex` preserve each retained point's acquisition timestamp and zero-based raw row.

Correction enables **Use corrected currents when available** and switches existing toolbox current graphs to paired corrected X/Y waves. Managed Vg/Vref overlays follow the corrected time axis. Traces using custom X waves are reported for manual replotting. New time, transfer and steady-state plots select aligned companion waves. Uncheck the option and create a new plot to use raw currents again; the checkbox does not revert existing plots. Repeating correction rebuilds the selected copies from raw data, so shifts do not accumulate between runs. Derived steady-state curves must be regenerated.

After upgrading from the NaN-based version, run **Correct Id / Ig** again to regenerate previously corrected data. The compressed Time wave represents display sample positions; use `SourceTime` when the original acquisition timestamps are needed.

The native regression procedure [AT_GateCompaction_Test.ipf](validation/AT_GateCompaction_Test.ipf) can be opened and compiled alongside the toolbox. Run `AT_TestGateCompaction()`; zero means all checks passed. It uses uniquely named synthetic fixtures and removes its own graph and waves afterward.

## More information

- [Validation notes](VALIDATION.md): checks actually performed and limitations.

The separate OECT and Time Overlays menu groups, Extra Tools, adjustable Appearance controls, and Make RGB waves feature have been removed. Voltage-overlay buttons remain in Electrical/OECT; the current version supports one Vg and one Vref overlay per graph.
