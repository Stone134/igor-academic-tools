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

## Panels

| Electrical / OECT | UV-vis |
| --- | --- |
| Import all columns from electrical text files | Import JASCO ASCII or plain two-column spectra |
| Plot Id vs time, Vref vs time, and Id vs Vg | Plot raw or corrected spectra |
| Calculate steady-state Id vs Vg | Correct detector jumps and a reference baseline |
| Add Vg or Vref to an Id/time graph | Retain native data and a shared wavelength grid |
| Omit gate-step artifacts from Id and Ig copies | Keep raw spectra separate from corrected spectra |

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

Mirroring (`mirror=1`) is applied only to edges without a real opposite right/top axis. Applying Thesis2 preserves unrelated existing settings, axis ranges, display multipliers, and trace colors.

### Resize the graph freely

Bring the intended graph to the front, then check **Free graph size (resize window)** under **Graph style and colors**. Drag the graph window's edges or corner to change width and height independently.

- **Checked:** Igor uses automatic plot-area sizing (`width=0,height=0`), so the graph follows the window.
- **Unchecked:** restores the fixed Thesis2 plot area, `width=170.079,height=99.2126` points.
- Changing the checkbox affects the front graph immediately. New toolbox plots and **Apply Thesis2** honor the setting; other open graphs are not changed automatically.
- The Electrical/OECT and UV-vis panels share this setting. It starts unchecked and is retained when you save the experiment.

### Axis units and numbers

Units appear in axis titles, such as **Id (µA)** and **Time (s)**, without extra unit text beside the tick labels. Ordinary measurement ranges use full numbers: for example, **1000** seconds instead of **1 ks**. Extremely small or large values outside the fixed-notation thresholds above may still use exponential notation.

The extra **A** came from the current wave's ampere metadata, even though the plotted current was already multiplied by `1e6` for µA display. **ks** was Igor's automatic engineering prefix for thousands of seconds. This update changes tick formatting while preserving source values, wave units, and display multipliers.

For an existing graph, click **Apply Thesis2** to apply the new tick formatting. If a panel was already open when you replaced the procedure, close and reopen it to show the checkbox.

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

Starting at the first point carrying the new gate voltage, the selected current points are replaced by **NaN in separate corrected copies**. Rows are not deleted: Time and GateV stay aligned, and the raw currents remain unchanged. Overlapping omission intervals are combined; the start of a file is not masked without a recorded gate change.

Correction enables **Use corrected currents when available** and switches graphs directly plotting the selected raw currents to their corrected copies. Uncheck the option and create a new plot to use raw currents again; the checkbox does not revert existing plots. Repeating correction replaces the selected corrected copies from raw data. Derived steady-state curves must be regenerated.

## More information

- [Validation notes](VALIDATION.md): checks actually performed and limitations.

The separate OECT and Time Overlays menu groups, Extra Tools, adjustable Appearance controls, and Make RGB waves feature have been removed. Voltage-overlay buttons remain in Electrical/OECT; the current version supports one Vg and one Vref overlay per graph.
