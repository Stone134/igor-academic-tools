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

Both panels include **Apply Thesis2**, **Restore to default**, **Add legend**, **Recolor**, and **Curve color**.

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

**Apply Thesis2** sets only these appearance properties:

~~~igorpro
ModifyGraph axThick=0.75,btLen=3,fSize=9,lsize=0.75,expand=2,font="Arial",tick=2,mirror=1,standoff=0,width=170.079,height=99.2126
~~~

New toolbox plots use this style. When a real right or top axis is present, mirroring is applied only to available edges. Applying Thesis2 preserves unrelated existing settings and trace colors.

**Restore to default** rebuilds a standalone curve graph using Igor's factory appearance. It retains the data, axis assignments, label text, error bars, and display offsets/multipliers. Custom axis ranges, formatting, legends, and other annotations are not retained; use **Add legend** afterward. Image, contour, and subwindow graphs are not supported by this reset.

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

- [Detailed user guide](Academic_Toolbox_Guide.md): import options, UV–vis correction, palette values, data folders, and scripting.
- [Validation notes](VALIDATION.md): checks actually performed and limitations.

The separate OECT and Time Overlays menu groups, Extra Tools, adjustable Appearance controls, and Make RGB waves feature have been removed. Voltage-overlay buttons remain in Electrical/OECT; the current version supports one Vg and one Vref overlay per graph.
