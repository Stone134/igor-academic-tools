#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma IgorVersion=8.00

// Academic Toolbox: self-contained consolidation, 2026-09-10.
// Open this file and run AT_Panel(). See Academic_Toolbox_Guide.md.
// Original six procedures are preserved. AT_ names and data folders are isolated.
Constant kAT_E_NPAL=8
StrConstant ksAT_E_PAL="0,114,178;213,94,0;0,158,115;204,121,167;230,159,0;86,180,233;140,86,75;90,90,90"

Function AT_E_LoadFolder()

	String ext = ".txt"
	Variable headerLine = 0
	Variable encSel = 1
	String sep = "auto"
	Variable nCat = 3
	Variable nameMode = 1
	Variable clearFirst = 2

	Prompt ext,        "Extensions (.txt;.csv; ???? = all)"
	Prompt headerLine, "0-based line holding the column names"
	Prompt encSel,     "Text encoding of the files", popup, "Windows-1252 (Latin 1);UTF-8;MacRoman;let Igor decide"
	Prompt sep,        "Filename separator (auto, space, or _)"
	Prompt nCat,       "Tokens AFTER the sample used as CATEGORY"
	Prompt nameMode,   "Wave names", popup, "Start at the sample token (s6_...);Full file name"
	Prompt clearFirst, "Clear data already loaded?", popup, "Yes;No"
	DoPrompt "Load electrical raw data", ext, headerLine, encSel, sep, nCat, nameMode, clearFirst
	if (V_flag)
		return -1
	endif

	if (AT_InputUnits() != 0)
		return -1
	endif
	NewPath/O/Q/M="Select the folder holding the electrical raw data" AT_Epath
	if (V_flag)
		return -1
	endif

	if (clearFirst == 1)
		KillDataFolder/Z root:AT_Elec
	endif
	NewDataFolder/O root:AT_Elec
	NewDataFolder/O root:AT_Elec:Data

	WAVE/Z/T chk = root:AT_Elec:FileName
	if (!WaveExists(chk))
		Make/O/T/N=0 root:AT_Elec:FileName, root:AT_Elec:BaseName, root:AT_Elec:Category, root:AT_Elec:Sample
	endif
	WAVE/T fnw = root:AT_Elec:FileName
	WAVE/T bnw = root:AT_Elec:BaseName
	WAVE/T ctw = root:AT_Elec:Category
	WAVE/T spw = root:AT_Elec:Sample

	Variable i = 0, nOK = 0, nBad = 0, nNoSample = 0, rc
	String fn
	String fileList=AT_FileList("AT_Epath",ext)

	do
		fn = StringFromList(i,fileList)
		if (strlen(fn) == 0)
			break
		endif
		i += 1

		rc = AT_E_Ingest(fn, sep, nCat, nameMode, headerLine, AT_E_EncCode(encSel))
		if (rc == 0)
			nBad += 1
		else
			nOK += 1
			if (rc == 2)
				nNoSample += 1
			endif
		endif
	while (1)

	Printf "AT_E_LoadFolder: %d file(s) loaded, %d skipped. Total in memory: %d\r", nOK, nBad, numpnts(fnw)
	if (nNoSample > 0)
		Printf "  ! %d file(s) had no s1...s99 token; sample set to \"unknown\".\r", nNoSample
	endif
	if (nOK == 0)
		if(ItemsInList(fileList)==0)
			DoAlert 0, "No matching files in the selected folder. Choose the folder directly containing the data files (subfolders are not searched), and check the extension such as .txt. No header lines were read."
		else
			DoAlert 0, "Files were found but could not be imported. See Command-J history for details; check file access and the 0-based column-header line."
		endif
	endif
	return nOK
End

//  Resolve encoding names through Igor; 255 is binary, NOT UTF-8.
//  UTF-8=1, MacRoman=2, Windows-1252=3, 0=let Igor decide.  JASCO and most instrument
//  exports on Windows are Windows-1252.
Static Function AT_E_EncCode(sel)
	Variable sel
	switch (sel)
		case 1:
			return TextEncodingCode("Windows-1252")
		case 2:
			return TextEncodingCode("UTF-8")
		case 3:
			return TextEncodingCode("MacRoman")
	endswitch
	return 0
End

//  Parse the name, load the columns, append the metadata row.
//  Returns 0 = skipped, 1 = loaded, 2 = loaded but no sample token.
Static Function AT_E_Ingest(fn, sep, nCat, nameMode, headerLine, enc)
	String fn, sep
	Variable nCat, nameMode, headerLine, enc

	WAVE/T fnw = root:AT_Elec:FileName
	WAVE/T bnw = root:AT_Elec:BaseName
	WAVE/T ctw = root:AT_Elec:Category
	WAVE/T spw = root:AT_Elec:Sample

	String stem = AT_E_StripExt(fn), samp = "", rest, base, cat
	Variable pos = AT_E_FindSample(stem, samp)
	rest = stem
	if (pos >= 0)
		rest = stem[pos, strlen(stem) - 1]
	else
		samp = "unknown"
	endif
	if(cmpstr(sep,"auto")==0)
		rest=ReplaceString("_",rest," ")
		sep=" "
	elseif(cmpstr(sep,"space")==0)
		sep=" "
	endif
	cat  = AT_E_CatFrom(rest, sep, nCat, pos >= 0)
	base = AT_E_UniqueBase(AT_E_MakeBase(stem, rest, nameMode))

	if (AT_E_LoadOne(fn, base, headerLine, enc) != 0)
		Print "  ! skipped (no DrainI column found): " + fn
		return 0
	endif

	Variable n = numpnts(fnw)
	Redimension/N=(n + 1) fnw, bnw, ctw, spw
	fnw[n] = fn
	bnw[n] = base
	ctw[n] = cat
	spw[n] = samp
	return (pos >= 0) ? 1 : 2
End

//  Native path separator of a full path string
Static Function/S AT_E_PathSep(fullPath)
	String fullPath
	if (strsearch(fullPath, "\\", 0) >= 0)
		return "\\"
	endif
	if (strsearch(fullPath, "/", 0) >= 0)
		return "/"
	endif
	return ":"
End

//  Load one or several individually chosen files instead of a folder
Function AT_E_LoadFiles()

	Variable headerLine = 0
	Variable encSel = 1
	String sep = "auto"
	Variable nCat = 3
	Variable nameMode = 1
	Variable clearFirst = 2

	Prompt headerLine, "0-based line holding the column names"
	Prompt encSel,     "Text encoding of the files", popup, "Windows-1252 (Latin 1);UTF-8;MacRoman;let Igor decide"
	Prompt sep,        "Filename separator (auto, space, or _)"
	Prompt nCat,       "Tokens AFTER the sample used as CATEGORY"
	Prompt nameMode,   "Wave names", popup, "Start at the sample token (s6_...);Full file name"
	Prompt clearFirst, "Clear data already loaded?", popup, "Yes;No"
	DoPrompt "Load individual electrical files", headerLine, encSel, sep, nCat, nameMode, clearFirst
	if (V_flag)
		return -1
	endif

	if (AT_InputUnits() != 0)
		return -1
	endif
	Variable refNum
	Open/D/R/MULT=1/M="Select one or more electrical data files" refNum
	String list = S_fileName
	if (strlen(list) == 0)
		return -1
	endif

	if (clearFirst == 1)
		KillDataFolder/Z root:AT_Elec
	endif
	NewDataFolder/O root:AT_Elec
	NewDataFolder/O root:AT_Elec:Data
	WAVE/Z/T chk = root:AT_Elec:FileName
	if (!WaveExists(chk))
		Make/O/T/N=0 root:AT_Elec:FileName, root:AT_Elec:BaseName, root:AT_Elec:Category, root:AT_Elec:Sample
	endif

	Variable i, rc, nOK = 0, nBad = 0, nNoSample = 0
	Variable nf = ItemsInList(list, "\r")
	String full, dir, fn, psep
	for (i = 0; i < nf; i += 1)
		full = StringFromList(i, list, "\r")
		if (strlen(full) == 0)
			continue
		endif
		psep = AT_E_PathSep(full)
		dir  = ParseFilePath(1, full, psep, 1, 0)
		fn   = ParseFilePath(0, full, psep, 1, 0)
		NewPath/O/Q AT_Epath dir
		rc = AT_E_Ingest(fn, sep, nCat, nameMode, headerLine, AT_E_EncCode(encSel))
		if (rc == 0)
			nBad += 1
		else
			nOK += 1
			if (rc == 2)
				nNoSample += 1
			endif
		endif
	endfor

	WAVE/T fnw = root:AT_Elec:FileName
	Printf "AT_E_LoadFiles: %d file(s) loaded, %d skipped. Total in memory: %d\r", nOK, nBad, numpnts(fnw)
	if (nNoSample > 0)
		Printf "  ! %d file(s) had no s1...s99 token; sample set to \"unknown\".\r", nNoSample
	endif
	return nOK
End

Static Function AT_E_LoadOne(fn, base, headerLine, enc)
	String fn, base
	Variable headerLine, enc

	String saveDF = GetDataFolder(1)
	KillDataFolder/Z root:AT_Elec:tmp
	NewDataFolder/O/S root:AT_Elec:tmp

	if (enc > 0)
		LoadWave/J/D/W/A/K=0/O/Q/ENCG=(enc)/L={headerLine, headerLine + 1, 0, 0, 0}/P=AT_Epath fn
	else
		LoadWave/J/D/W/A/K=0/O/Q/L={headerLine, headerLine + 1, 0, 0, 0}/P=AT_Epath fn
	endif
	if (V_flag <= 0)
		SetDataFolder saveDF
		KillDataFolder/Z root:AT_Elec:tmp
		return -1
	endif

	String names = S_waveNames
	String nI = AT_U_FindCol(names, "draini;draincurrent;id")
	String nG = AT_U_FindCol(names, "gatev;gatevoltage;vg")
	String nT = AT_E_FindCol(names, "time")
	String nR = AT_U_FindCol(names, "vref;referencevoltage;referenceelectrodevoltage")

	if (strlen(nI) == 0)
		SetDataFolder saveDF
		KillDataFolder/Z root:AT_Elec:tmp
		return -1
	endif

	NewDataFolder/O root:AT_Elec:Native
	NewDataFolder/O root:AT_Elec:Native:$base
	Variable colIndex
	for(colIndex=0;colIndex<ItemsInList(names);colIndex+=1)
		String colName=StringFromList(colIndex,names)
		WAVE/Z column=$colName
		if(WaveExists(column))
			Duplicate/O column,$("root:AT_Elec:Native:"+base+":"+colName)
		endif
	endfor
	WAVE wI = $nI
	Duplicate/O wI, root:AT_Elec:Data:$(base + "_DrainI")
	AT_E_InitPrefs()
	NVAR currentScale=root:Packages:AcademicToolbox:currentScale
	NVAR timeScale=root:Packages:AcademicToolbox:timeScale
	WAVE storedI=root:AT_Elec:Data:$(base + "_DrainI")
	storedI *= currentScale
	SetScale d,0,0,"A",storedI


	if (strlen(nG) > 0)
		WAVE wG = $nG
		Duplicate/O wG, root:AT_Elec:Data:$(base + "_GateV")
	endif

	if (strlen(nR) > 0)
		WAVE wR = $nR
		Duplicate/O wR, root:AT_Elec:Data:$(base + "_Vref")
		WAVE storedR = root:AT_Elec:Data:$(base + "_Vref")
		SetScale d,0,0,"V",storedR
	endif

	if (strlen(nT) > 0)
		WAVE wT = $nT
		Duplicate/O wT, root:AT_Elec:Data:$(base + "_Time")
		WAVE storedT=root:AT_Elec:Data:$(base + "_Time")
		storedT *= timeScale
		SetScale d,0,0,"s",storedT

	endif

	SetDataFolder saveDF
	KillDataFolder/Z root:AT_Elec:tmp
	return 0
End

Function AT_E_ListFiles()
	WAVE/Z/T chk = root:AT_Elec:BaseName
	if (!WaveExists(chk))
		Print "Nothing loaded."
		return -1
	endif
	WAVE/T bnw = root:AT_Elec:BaseName
	WAVE/T ctw = root:AT_Elec:Category
	WAVE/T spw = root:AT_Elec:Sample
	Variable i
	Printf "%-8s %-24s %s\r", "sample", "category", "wave base name"
	for (i = 0; i < numpnts(bnw); i += 1)
		Printf "%-8s %-24s %s\r", spw[i], ctw[i], bnw[i]
	endfor
End

Function AT_E_KillAll()
	DoAlert 1, "Delete root:AT_Elec completely?"
	if (V_flag == 1)
		KillDataFolder/Z root:AT_Elec
	endif
End

// =====================================================================
//  2.  DRAIN CURRENT vs TIME
// =====================================================================

Function AT_E_PlotTransient()

	WAVE/Z/T chk = root:AT_Elec:BaseName
	if (!WaveExists(chk))
		DoAlert 0, "No data. Run \"Load electrical folder\" first."
		return -1
	endif

	AT_E_InitPrefs()
	NVAR gLW = root:Packages:AcademicToolbox:lineWidth
	NVAR gMK = root:Packages:AcademicToolbox:markerSize
	NVAR gWW = root:Packages:AcademicToolbox:winW
	NVAR gWH = root:Packages:AcademicToolbox:winH

	String catFilter = "*"
	Variable pickMode = 2
	NVAR savedGradient=root:Packages:AcademicToolbox:gradient
	Variable colorMode = savedGradient+3
	Variable lw = gLW
	Variable zeroT = 1
	Variable showLeg = 1
	Variable revY=1

	Prompt catFilter,  "Category filter ( * = all )"
	Prompt pickMode,   "Data selection", popup, "Everything matching the filter;Choose from a list..."
	Prompt colorMode,  "Colouring", popup, "One colour per category;Shades within each category;Every curve distinct;Red gradient (dark to light);Blue gradient (dark to light)"
	Prompt lw,         "Line thickness (pt)"
	Prompt zeroT,      "Shift every trace so t starts at 0?", popup, "Yes;No"
	Prompt showLeg,    "Legend", popup, "Show;Hide"
	Prompt revY,"Reverse current axis?",popup,"Yes;No"
	DoPrompt "Drain current vs time", catFilter, pickMode, colorMode, lw, zeroT, showLeg, revY
	if (V_flag)
		return -1
	endif

	WAVE/T bnw = root:AT_Elec:BaseName
	WAVE/T ctw = root:AT_Elec:Category
	WAVE/T spw = root:AT_Elec:Sample

	Make/FREE/N=0 idx
	if (AT_E_Select(ctw, catFilter, idx) == 0)
		DoAlert 0, "No file matches that category filter."
		return -1
	endif
	Variable m = numpnts(idx)

	if (pickMode == 2)
		m = AT_E_PickFrom(idx, bnw, ctw, spw)
		if (m <= 0)
			return -1
		endif
	endif

	Make/FREE/N=(m) ciW, siW, nsW
	String catList = AT_E_GroupIdx(ctw, idx, ciW, siW, nsW)

	String gName = UniqueName("gIt", 6, 0)
	Display/N=$gName/W=(40, 40, 40 + gWW, 40 + gWH) as "Drain current vs time"

	Variable nPlot=0
	Variable i, ymin = inf, ymax = -inf, xmin = inf, xmax = -inf, t0
	String tn, leg = "", lastCat = ""

	for (i = 0; i < m; i += 1)
		WAVE/Z wy = root:AT_Elec:Data:$(bnw[idx[i]] + "_DrainI")
		WAVE/Z wx = root:AT_Elec:Data:$(bnw[idx[i]] + "_Time")
		if (!WaveExists(wx) || !WaveExists(wy))
			Print "Skipped missing Time/DrainI: "+bnw[idx[i]]
			continue
		endif
		if (numpnts(wx)==0 || numpnts(wx)!=numpnts(wy))
			continue
		endif
		nPlot+=1
		AppendToGraph/W=$gName wy vs wx
		tn = NameOfWave(wy)

		t0 = 0
		if (zeroT == 1)
			t0 = wx[0]
		endif
		ModifyGraph/W=$gName offset($tn) = {-t0, 0}, muloffset($tn) = {0, 1e6}
		ModifyGraph/W=$gName lsize($tn) = lw

		Variable r, g, b
		AT_E_TraceColor(colorMode, ciW[i], siW[i], nsW[i], i, r, g, b)
		ModifyGraph/W=$gName rgb($tn) = (r, g, b)

		WaveStats/Q/M=1 wy
		ymin = min(ymin, V_min * 1e6)
		ymax = max(ymax, V_max * 1e6)
		WaveStats/Q/M=1 wx
		xmin = min(xmin, V_min - t0)
		xmax = max(xmax, V_max - t0)

		if (showLeg == 1)
			if (colorMode == 1)
				if (cmpstr(ctw[idx[i]], lastCat) != 0 && siW[i] == 0)
					leg += "\\s(" + tn + ") " + ctw[idx[i]] + "\r"
					lastCat = ctw[idx[i]]
				endif
			else
				leg += "\\s(" + tn + ") " + bnw[idx[i]] + "\r"
			endif
		endif
	endfor

	if(nPlot==0)
		KillWindow $gName
		DoAlert 0,"No valid time/current pairs. A real Time column is required."
		return -1
	endif
	AT_E_SetNiceAxis(gName, "left",   ymin, ymax, revY==1, 0)		// reversed
	AT_E_SetNiceAxis(gName, "bottom", xmin, xmax, 0, 1)		// time: 0 -> rounded up
	AT_E_Style(gName, "Time (s)", "\\f02I\\BD\\M\\f00 (µA)")
	if(colorMode==4 || colorMode==5)
		AT_E_RecolorGradient(gName,colorMode-3)
	endif
	AT_E_PutLegend(gName, leg)

	return 0
End

// Reference-electrode voltage: source and working voltage units are volts.
Function AT_E_PlotVref()

	WAVE/Z/T chk = root:AT_Elec:BaseName
	if (!WaveExists(chk))
		DoAlert 0, "No data. Run \"Load electrical folder\" first."
		return -1
	endif

	AT_E_InitPrefs()
	NVAR gLW = root:Packages:AcademicToolbox:lineWidth
	NVAR gMK = root:Packages:AcademicToolbox:markerSize
	NVAR gWW = root:Packages:AcademicToolbox:winW
	NVAR gWH = root:Packages:AcademicToolbox:winH

	String catFilter = "*"
	Variable pickMode = 2
	NVAR savedGradient=root:Packages:AcademicToolbox:gradient
	Variable colorMode = savedGradient+3
	Variable lw = gLW
	Variable zeroT = 1
	Variable showLeg = 1
	Variable revY=1

	Prompt catFilter,  "Category filter ( * = all )"
	Prompt pickMode,   "Data selection", popup, "Everything matching the filter;Choose from a list..."
	Prompt colorMode,  "Colouring", popup, "One colour per category;Shades within each category;Every curve distinct;Red gradient (dark to light);Blue gradient (dark to light)"
	Prompt lw,         "Line thickness (pt)"
	Prompt zeroT,      "Shift every trace so t starts at 0?", popup, "Yes;No"
	Prompt showLeg,    "Legend", popup, "Show;Hide"
	Prompt revY,"Reverse Vref axis?",popup,"Yes;No"
	DoPrompt "Reference-electrode voltage vs time", catFilter, pickMode, colorMode, lw, zeroT, showLeg, revY
	if (V_flag)
		return -1
	endif

	WAVE/T bnw = root:AT_Elec:BaseName
	WAVE/T ctw = root:AT_Elec:Category
	WAVE/T spw = root:AT_Elec:Sample

	Make/FREE/N=0 idx
	if (AT_E_Select(ctw, catFilter, idx) == 0)
		DoAlert 0, "No file matches that category filter."
		return -1
	endif
	Variable m = numpnts(idx)

	if (pickMode == 2)
		m = AT_E_PickFrom(idx, bnw, ctw, spw)
		if (m <= 0)
			return -1
		endif
	endif

	Make/FREE/N=(m) ciW, siW, nsW
	String catList = AT_E_GroupIdx(ctw, idx, ciW, siW, nsW)

	String gName = UniqueName("gVref", 6, 0)
	Display/N=$gName/W=(40, 40, 40 + gWW, 40 + gWH) as "Reference-electrode voltage vs time"

	Variable nPlot=0
	Variable i, ymin = inf, ymax = -inf, xmin = inf, xmax = -inf, t0
	String tn, leg = "", lastCat = ""

	for (i = 0; i < m; i += 1)
		WAVE/Z wy = root:AT_Elec:Data:$(bnw[idx[i]] + "_Vref")
		WAVE/Z wx = root:AT_Elec:Data:$(bnw[idx[i]] + "_Time")
		if (!WaveExists(wx) || !WaveExists(wy))
			Print "Skipped missing Time/Vref: "+bnw[idx[i]]
			continue
		endif
		if (numpnts(wx)==0 || numpnts(wx)!=numpnts(wy))
			continue
		endif
		WaveStats/Q/M=1 wy
		if (numtype(V_min)!=0 || numtype(V_max)!=0)
			continue
		endif
		WaveStats/Q/M=1 wx
		if (numtype(V_min)!=0 || numtype(V_max)!=0 || (zeroT==1 && numtype(wx[0])!=0))
			continue
		endif
		nPlot+=1
		AppendToGraph/W=$gName wy vs wx
		tn = NameOfWave(wy)

		t0 = 0
		if (zeroT == 1)
			t0 = wx[0]
		endif
		ModifyGraph/W=$gName offset($tn) = {-t0, 0}, muloffset($tn) = {0, 1}
		ModifyGraph/W=$gName lsize($tn) = lw

		Variable r, g, b
		AT_E_TraceColor(colorMode, ciW[i], siW[i], nsW[i], i, r, g, b)
		ModifyGraph/W=$gName rgb($tn) = (r, g, b)

		WaveStats/Q/M=1 wy
		ymin = min(ymin, V_min)
		ymax = max(ymax, V_max)
		WaveStats/Q/M=1 wx
		xmin = min(xmin, V_min - t0)
		xmax = max(xmax, V_max - t0)

		if (showLeg == 1)
			if (colorMode == 1)
				if (cmpstr(ctw[idx[i]], lastCat) != 0 && siW[i] == 0)
					leg += "\\s(" + tn + ") " + ctw[idx[i]] + "\r"
					lastCat = ctw[idx[i]]
				endif
			else
				leg += "\\s(" + tn + ") " + bnw[idx[i]] + "\r"
			endif
		endif
	endfor

	if(nPlot==0)
		KillWindow $gName
		DoAlert 0,"No valid Time/Vref pairs. A real Time column is required."
		return -1
	endif
	AT_E_SetNiceAxis(gName, "left",   ymin, ymax, revY==1, 0)		// reversed
	AT_E_SetNiceAxis(gName, "bottom", xmin, xmax, 0, 1)		// time: 0 -> rounded up
	AT_E_Style(gName, "Time (s)", "\\f02V\\Bref\\M\\f00 (V)")
	if(colorMode==4 || colorMode==5)
		AT_E_RecolorGradient(gName,colorMode-3)
	endif
	AT_E_PutLegend(gName, leg)

	return 0
End

// =====================================================================
//  3.  TRANSFER  --  DrainI vs GateV, both axes reversed
// =====================================================================

Function AT_E_PlotTransfer()

	WAVE/Z/T chk = root:AT_Elec:BaseName
	if (!WaveExists(chk))
		DoAlert 0, "No data. Run \"Load electrical folder\" first."
		return -1
	endif

	AT_E_InitPrefs()
	NVAR gLW = root:Packages:AcademicToolbox:lineWidth
	NVAR gMK = root:Packages:AcademicToolbox:markerSize
	NVAR gWW = root:Packages:AcademicToolbox:winW
	NVAR gWH = root:Packages:AcademicToolbox:winH

	String catFilter = "*"
	Variable pickMode = 2
	NVAR savedGradient=root:Packages:AcademicToolbox:gradient
	Variable colorMode = savedGradient+3
	Variable lw = gLW
	Variable showLeg = 1

	Prompt catFilter, "Category filter ( * = all )"
	Prompt pickMode,   "Data selection", popup, "Everything matching the filter;Choose from a list..."
	Prompt colorMode, "Colouring", popup, "One colour per category;Shades within each category;Every curve distinct;Red gradient (dark to light);Blue gradient (dark to light)"
	Prompt lw,        "Line thickness (pt)"
	Prompt showLeg,   "Legend", popup, "Show;Hide"
	DoPrompt "Drain current vs gate voltage", catFilter, pickMode, colorMode, lw, showLeg
	if (V_flag)
		return -1
	endif

	WAVE/T bnw = root:AT_Elec:BaseName
	WAVE/T ctw = root:AT_Elec:Category
	WAVE/T spw = root:AT_Elec:Sample

	Make/FREE/N=0 idx
	if (AT_E_Select(ctw, catFilter, idx) == 0)
		DoAlert 0, "No file matches that category filter."
		return -1
	endif
	Variable m = numpnts(idx)

	if (pickMode == 2)
		m = AT_E_PickFrom(idx, bnw, ctw, spw)
		if (m <= 0)
			return -1
		endif
	endif

	Make/FREE/N=(m) ciW, siW, nsW
	String catList = AT_E_GroupIdx(ctw, idx, ciW, siW, nsW)

	String gName = UniqueName("gIV", 6, 0)
	Display/N=$gName/W=(60, 60, 60 + gWW, 60 + gWH) as "Transfer curves"

	Variable i, nPlot = 0, ymin = inf, ymax = -inf, xmin = inf, xmax = -inf
	String tn, leg = "", lastCat = ""

	for (i = 0; i < m; i += 1)
		WAVE/Z wy = root:AT_Elec:Data:$(bnw[idx[i]] + "_DrainI")
		WAVE/Z wx = root:AT_Elec:Data:$(bnw[idx[i]] + "_GateV")
		if (!WaveExists(wx) || !WaveExists(wy))
			continue									// no gate column in this file
		endif
		AppendToGraph/W=$gName wy vs wx
		tn = NameOfWave(wy)
		nPlot += 1

		ModifyGraph/W=$gName muloffset($tn) = {0, 1e6}, lsize($tn) = lw

		Variable r, g, b
		AT_E_TraceColor(colorMode, ciW[i], siW[i], nsW[i], i, r, g, b)
		ModifyGraph/W=$gName rgb($tn) = (r, g, b)

		WaveStats/Q/M=1 wy
		ymin = min(ymin, V_min * 1e6)
		ymax = max(ymax, V_max * 1e6)
		WaveStats/Q/M=1 wx
		xmin = min(xmin, V_min)
		xmax = max(xmax, V_max)

		if (showLeg == 1)
			if (colorMode == 1)
				if (cmpstr(ctw[idx[i]], lastCat) != 0 && siW[i] == 0)
					leg += "\\s(" + tn + ") " + ctw[idx[i]] + "\r"
					lastCat = ctw[idx[i]]
				endif
			else
				leg += "\\s(" + tn + ") " + bnw[idx[i]] + "\r"
			endif
		endif
	endfor

	if (nPlot == 0)
		KillWindow $gName
		DoAlert 0, "None of the selected files contains a GateV column."
		return -1
	endif

	AT_E_SetNiceAxis(gName, "left",   ymin, ymax, 1, 0)		// reversed
	AT_E_SetNiceAxis(gName, "bottom", xmin, xmax, 1, 0)		// reversed
	AT_E_Style(gName, "\\f02V\\BG\\M\\f00 (V)", "\\f02I\\BD\\M\\f00 (µA)")
	if(colorMode==4 || colorMode==5)
		AT_E_RecolorGradient(gName,colorMode-3)
	endif
	AT_E_PutLegend(gName, leg)

	return 0
End

// =====================================================================
//  4.  STEADY STATE
//      mode 1: one point per file  (the very end of the file)
//      mode 2: one point per gate-voltage plateau inside every file
// =====================================================================

Function AT_E_PlotSteadyState()

	WAVE/Z/T chk = root:AT_Elec:BaseName
	if (!WaveExists(chk))
		DoAlert 0, "No data. Run \"Load electrical folder\" first."
		return -1
	endif

	AT_E_InitPrefs()
	NVAR gLW = root:Packages:AcademicToolbox:lineWidth
	NVAR gMK = root:Packages:AcademicToolbox:markerSize
	NVAR gWW = root:Packages:AcademicToolbox:winW
	NVAR gWH = root:Packages:AcademicToolbox:winH

	String catFilter = "*"
	Variable pickMode = 2
	Variable ssMode = 1
	Variable avgPts = 10
	NVAR savedGradient=root:Packages:AcademicToolbox:gradient
	Variable colorMode = savedGradient+3
	Variable revX = 1
	Variable revY = 1
	Variable lw = gLW

	Prompt catFilter, "Category filter ( * = all )"
	Prompt pickMode,   "Data selection", popup, "Everything matching the filter;Choose from a list..."
	Prompt ssMode,    "Steady-state point taken", popup, "at the end of each file;at the end of every Vg plateau"
	Prompt avgPts,    "Average the last n points of each hold"
	Prompt colorMode, "Colouring", popup, "One colour per category;Shades within each category;Every curve distinct;Red gradient (dark to light);Blue gradient (dark to light)"
	Prompt revX,      "Reverse the Vg axis?", popup, "Yes;No"
	Prompt revY,      "Reverse the Id axis?", popup, "Yes;No"
	Prompt lw,        "Line thickness (pt)"
	DoPrompt "Steady-state current vs gate voltage", catFilter, pickMode, ssMode, avgPts, colorMode, revX, revY, lw
	if (V_flag)
		return -1
	endif

	if(numtype(avgPts)!=0 || avgPts<1)
		DoAlert 0,"Average count must be a positive number."
		return -1
	endif
	avgPts=round(avgPts)
	WAVE/T bnw = root:AT_Elec:BaseName
	WAVE/T ctw = root:AT_Elec:Category
	WAVE/T spw = root:AT_Elec:Sample
	Variable nAll = numpnts(bnw)

	NewDataFolder/O root:AT_Elec:SS

	// ---- unique category|sample keys -------------------------------
	String keyList = "", key, cat, samp, nm
	Variable i, j
	for (i = 0; i < nAll; i += 1)
		if (!stringmatch(ctw[i], catFilter))
			continue
		endif
		key = ctw[i] + "|" + spw[i]
		if (WhichListItem(key, keyList) < 0)
			keyList = AddListItem(key, keyList, ";", inf)
		endif
	endfor
	Variable nk = ItemsInList(keyList)
	if (nk == 0)
		DoAlert 0, "No file matches that category filter."
		return -1
	endif

	if (pickMode == 2)								// choose which samples to plot
		Make/FREE/T/N=(nk) klabs
		Make/FREE/N=(nk) kpick = 1
		for (j = 0; j < nk; j += 1)
			klabs[j] = ReplaceString("|", StringFromList(j, keyList), "        [ ") + " ]"
		endfor
		if (AT_E_PickList("Choose the samples to plot", klabs, kpick) != 0)
			return -1
		endif
		String newList = ""
		for (j = 0; j < nk; j += 1)
			if (kpick[j] != 0)
				newList = AddListItem(StringFromList(j, keyList), newList, ";", inf)
			endif
		endfor
		keyList = newList
		nk = ItemsInList(keyList)
		if (nk == 0)
			DoAlert 0, "Nothing was selected."
			return -1
		endif
	endif

	// ---- one Vg / Id curve per sample ------------------------------
	Make/FREE/T/N=(nk) catW, sampW, nameW
	for (j = 0; j < nk; j += 1)
		key  = StringFromList(j, keyList)
		cat  = StringFromList(0, key, "|")
		samp = StringFromList(1, key, "|")
		nm   = AT_SSName(CleanupName("SS_" + cat + "_" + samp, 0))
		catW[j] = cat ; sampW[j] = samp ; nameW[j] = nm

		Make/O/D/N=0 root:AT_Elec:SS:$(nm + "_Vg"), root:AT_Elec:SS:$(nm + "_Id")
		WAVE vg = root:AT_Elec:SS:$(nm + "_Vg")
		WAVE id = root:AT_Elec:SS:$(nm + "_Id")

		for (i = 0; i < nAll; i += 1)
			if (cmpstr(ctw[i] + "|" + spw[i], key) != 0)
				continue
			endif
			WAVE/Z wI = root:AT_Elec:Data:$(bnw[i] + "_DrainI")
			WAVE/Z wG = root:AT_Elec:Data:$(bnw[i] + "_GateV")
			if (!WaveExists(wI) || !WaveExists(wG))
				continue
			endif
			AT_E_HarvestPoints(wI, wG, avgPts, ssMode, vg, id)
		endfor
		Sort vg, vg, id
	endfor

	// ---- colours ---------------------------------------------------
	Make/FREE/N=(nk) ciW, siW, nsW
	String catList = ""
	Variable ci
	for (j = 0; j < nk; j += 1)
		ci = WhichListItem(catW[j], catList)
		if (ci < 0)
			catList = AddListItem(catW[j], catList, ";", inf)
			ci = ItemsInList(catList) - 1
		endif
		ciW[j] = ci
	endfor
	Variable nc = ItemsInList(catList)
	Make/FREE/N=(nc) perCat = 0
	for (j = 0; j < nk; j += 1)
		siW[j] = perCat[ciW[j]]
		perCat[ciW[j]] += 1
	endfor
	for (j = 0; j < nk; j += 1)
		nsW[j] = perCat[ciW[j]]
	endfor

	// ---- plot ------------------------------------------------------
	String gName = UniqueName("gSS", 6, 0)
	Display/N=$gName/W=(80, 80, 80 + gWW, 80 + gWH) as "Steady-state current vs gate voltage"

	Variable ymin = inf, ymax = -inf, xmin = inf, xmax = -inf, nPlot = 0
	String tn, leg = "", lastCat = ""

	for (j = 0; j < nk; j += 1)
		WAVE vg = root:AT_Elec:SS:$(nameW[j] + "_Vg")
		WAVE id = root:AT_Elec:SS:$(nameW[j] + "_Id")
		if (numpnts(vg) == 0)
			KillWaves/Z vg, id
			continue
		endif
		AppendToGraph/W=$gName id vs vg
		tn = NameOfWave(id)
		nPlot += 1

		ModifyGraph/W=$gName muloffset($tn) = {0, 1e6}, lsize($tn) = lw
		ModifyGraph/W=$gName mode($tn) = 4, marker($tn) = 19, msize($tn) = gMK, mrkThick($tn) = 1

		Variable r, g, b
		AT_E_TraceColor(colorMode, ciW[j], siW[j], nsW[j], j, r, g, b)
		ModifyGraph/W=$gName rgb($tn) = (r, g, b)

		WaveStats/Q/M=1 id
		ymin = min(ymin, V_min * 1e6)
		ymax = max(ymax, V_max * 1e6)
		WaveStats/Q/M=1 vg
		xmin = min(xmin, V_min)
		xmax = max(xmax, V_max)

		if (colorMode == 1)
			if (cmpstr(catW[j], lastCat) != 0)
				leg += "\\s(" + tn + ") " + catW[j] + "\r"
				lastCat = catW[j]
			endif
		else
			leg += "\\s(" + tn + ") " + sampW[j] + "\r"
		endif
	endfor

	if (nPlot == 0)
		KillWindow $gName
		DoAlert 0, "No usable points were found (GateV column missing?)."
		return -1
	endif

	AT_E_SetNiceAxis(gName, "left",   ymin, ymax, revY == 1, 0)
	AT_E_SetNiceAxis(gName, "bottom", xmin, xmax, revX == 1, 0)
	AT_E_Style(gName, "\\f02V\\BG\\M\\f00 (V)", "Steady-state \\f02I\\BD\\M\\f00 (µA)")
	if(colorMode==4 || colorMode==5)
		AT_E_RecolorGradient(gName,colorMode-3)
	endif
	AT_E_PutLegend(gName, leg)

	Printf "AT_E_PlotSteadyState: %d curve(s) built in root:AT_Elec:SS\r", nPlot
	return 0
End

//  append the steady-state point(s) of one file to vg / id
Static Function AT_E_HarvestPoints(wI, wG, avgPts, ssMode, vg, id)
	WAVE wI, wG, vg, id
	Variable avgPts, ssMode

	Variable np = min(numpnts(wI), numpnts(wG))
	if (np < 1)
		return 0
	endif

	if (ssMode == 1)								// end of the whole file
		AT_E_AppendAvg(wI, wG, max(0, np - max(1, avgPts)), np - 1, vg, id)
		return 1
	endif

	// end of every gate-voltage plateau
	Variable i, s = 0, added = 0
	Variable tol = 1e-4								// V
	for (i = 1; i < np; i += 1)
		if (abs(wG[i] - wG[i - 1]) > tol)
			if (i - s >= 3)
				AT_E_AppendAvg(wI, wG, max(s, i - max(1, avgPts)), i - 1, vg, id)
				added += 1
			endif
			s = i
		endif
	endfor
	if (np - s >= 3)
		AT_E_AppendAvg(wI, wG, max(s, np - max(1, avgPts)), np - 1, vg, id)
		added += 1
	endif
	return added
End

Static Function AT_E_AppendAvg(wI, wG, pA, pB, vg, id)
	WAVE wI, wG, vg, id
	Variable pA, pB
	if (pB < pA)
		return 0
	endif
	WaveStats/Q/M=1/R=[pA, pB] wI
	Variable iEnd = V_avg
	WaveStats/Q/M=1/R=[pA, pB] wG
	Variable vEnd = V_avg
	Variable n = numpnts(vg)
	Redimension/N=(n + 1) vg, id
	vg[n] = vEnd
	id[n] = iEnd
	return 1
End

// =====================================================================
//  NAME PARSING
// =====================================================================

//  file name without extension, NOT yet cleaned up
Static Function/S AT_E_StripExt(fn)
	String fn
	Variable p = strsearch(fn, ".", inf, 1)
	String s = fn
	if (p > 0)
		s = fn[0, p - 1]
	endif
	return ReplaceString(".", s, "")		// 0.1V -> 01V: the dot is not a separator
End

//  Find "s" followed by 1 or 2 digits ANYWHERE in the file name --
//  not preceded by a letter or digit, not followed by one.  This copes
//  with s6 as its own token, with B043s6, with dashes instead of
//  underscores, and with upper case S.  Returns the character position
//  of the "s" (or -1) and puts e.g. "s6" into sampOut.
Static Function AT_E_FindSample(stem, sampOut)
	String stem
	String &sampOut
	sampOut = ""
	Variable i, d, nd, c, n = strlen(stem)
	for (i = 0; i < n; i += 1)
		if (cmpstr(stem[i], "s") != 0)					// cmpstr: case insensitive
			continue
		endif
		if (i > 0)
			if (AT_E_IsAlnum(char2num(stem[i - 1])))		// B043s6 is fine, phos is not
				if (!AT_E_IsDigit(char2num(stem[i - 1])))
					continue
				endif
			endif
		endif
		nd = 0
		for (d = i + 1; d < n && nd < 2; d += 1)
			if (!AT_E_IsDigit(char2num(stem[d])))
				break
			endif
			nd += 1
		endfor
		if (nd == 0)
			continue									// no digits after the s
		endif
		if (i + 1 + nd < n)
			c = char2num(stem[i + 1 + nd])
			if (AT_E_IsAlnum(c))
				continue								// s123... or s6x: not a sample
			endif
		endif
		sampOut = "s" + stem[i + 1, i + nd]
		return i
	endfor
	return -1
End

Static Function AT_E_IsDigit(c)
	Variable c
	return (c >= 48 && c <= 57)
End

Static Function AT_E_IsAlnum(c)
	Variable c
	if (c >= 48 && c <= 57)
		return 1
	endif
	if (c >= 65 && c <= 90)
		return 1
	endif
	if (c >= 97 && c <= 122)
		return 1
	endif
	return 0
End

//  nCat tokens of "rest" after the sample token
Static Function/S AT_E_CatFrom(rest, sep, nCat, haveSample)
	String rest, sep
	Variable nCat, haveSample
	Variable start = (haveSample != 0) ? 1 : 0
	Variable n = ItemsInList(rest, sep)
	Variable i, k = max(1, nCat)
	String out = "", t
	for (i = start; i < min(n, start + k); i += 1)
		t = StringFromList(i, rest, sep)
		if (strlen(t) == 0)
			continue
		endif
		if (strlen(out) > 0)
			out += sep
		endif
		out += t
	endfor
	if (strlen(out) == 0)
		out = "All"
	endif
	return CleanupName(out, 0)
End

//  nameMode 1 = start at the sample, 2 = whole file name
Static Function/S AT_E_MakeBase(stem, rest, nameMode)
	String stem, rest
	Variable nameMode
	if (nameMode == 1)
		return CleanupName(rest, 0)
	endif
	return CleanupName(stem, 0)
End

Static Function/S AT_E_UniqueBase(base)
	String base
	base=base[0,220]
	String b = base
	Variable k = 1
	do
		if (!exists("root:AT_Elec:Data:" + b + "_DrainI"))
			return b
		endif
		b = base + "_" + num2istr(k)
		k += 1
	while (1)
End

Static Function/S AT_E_FindCol(names, key)
	String names, key
	Variable i
	String s
	for (i = 0; i < ItemsInList(names); i += 1)
		s = StringFromList(i, names)
		if (stringmatch(LowerStr(s), "*" + key + "*"))
			return s
		endif
	endfor
	return ""
End

// =====================================================================
//  GROUPING, COLOURS, AXES, STYLE
// =====================================================================

// =====================================================================
//  DATA PICKER  --  modal checkbox list of the loaded wave names
// =====================================================================

//  labels[] are shown, pick[] goes in as the default state and comes
//  back as the user's choice.  Returns 0 on Plot, -1 on Cancel.
Static Function AT_E_PickList(titleStr, labels, pick)
	String titleStr
	WAVE/T labels
	WAVE pick
	Variable n = numpnts(labels)
	if (n == 0)
		return -1
	endif

	NewDataFolder/O root:Packages
	NewDataFolder/O root:Packages:AcademicToolbox
	Make/O/T/N=(n) root:Packages:AcademicToolbox:pickList
	Make/O/B/U/N=(n) root:Packages:AcademicToolbox:pickSel
	WAVE/T lw = root:Packages:AcademicToolbox:pickList
	WAVE   sw = root:Packages:AcademicToolbox:pickSel
	lw = labels[p]
	sw = 0x20 + ((pick[p] != 0) ? 0x10 : 0)		// 0x20 draws a checkbox, 0x10 = ticked
	Variable/G root:Packages:AcademicToolbox:pickResult = 0

	KillWindow/Z AT_pick
	NewPanel/K=1/N=AT_pick/W=(220, 130, 780, 590) as titleStr
	ListBox lbPick, win=AT_pick, pos={10, 10}, size={538, 388}, listWave=lw, selWave=sw, mode=1
	Button bAll,  win=AT_pick, pos={10, 408}, size={80, 26}, proc=AT_E_PickButton, title="All"
	Button bNone, win=AT_pick, pos={96, 408}, size={80, 26}, proc=AT_E_PickButton, title="None"
	Button bPCan, win=AT_pick, pos={368, 408}, size={86, 26}, proc=AT_E_PickButton, title="Cancel"
	Button bPOK,  win=AT_pick, pos={462, 408}, size={86, 26}, proc=AT_E_PickButton, title="Plot"
	PauseForUser AT_pick

	NVAR res = root:Packages:AcademicToolbox:pickResult
	if (res != 1)
		return -1
	endif
	pick = ((sw[p] & 0x10) != 0)
	return 0
End

Function AT_E_PickButton(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	if (ba.eventCode != 2)
		return 0
	endif
	WAVE/Z sw  = root:Packages:AcademicToolbox:pickSel
	NVAR/Z res = root:Packages:AcademicToolbox:pickResult
	strswitch (ba.ctrlName)
		case "bAll":
			sw = sw[p] | 0x10
			break
		case "bNone":
			sw = sw[p] - (sw[p] & 0x10)
			break
		case "bPOK":
			res = 1
			KillWindow/Z AT_pick
			break
		case "bPCan":
			res = 0
			KillWindow/Z AT_pick
			break
	endswitch
	return 0
End

//  Narrows idx[] to the rows the user ticked.  Returns the new count,
//  or -1 if cancelled / nothing chosen.
Static Function AT_E_PickFrom(idx, bnw, ctw, spw)
	WAVE idx
	WAVE/T bnw, ctw, spw
	Variable i, m = numpnts(idx), mm = 0
	Make/FREE/T/N=(m) labs
	Make/FREE/N=(m) pick = 1
	for (i = 0; i < m; i += 1)
		labs[i] = bnw[idx[i]] + "        [ " + ctw[idx[i]] + " ]"
	endfor
	if (AT_E_PickList("Choose the data to plot", labs, pick) != 0)
		return -1
	endif
	for (i = 0; i < m; i += 1)
		if (pick[i] != 0)
			idx[mm] = idx[i]
			mm += 1
		endif
	endfor
	if (mm == 0)
		DoAlert 0, "Nothing was selected."
		return -1
	endif
	Redimension/N=(mm) idx
	return mm
End

Static Function AT_E_Select(ctw, filt, idx)
	WAVE/T ctw
	String filt
	WAVE idx
	Variable i, m = 0, n = numpnts(ctw)
	Redimension/N=(n) idx
	for (i = 0; i < n; i += 1)
		if (stringmatch(ctw[i], filt))
			idx[m] = i
			m += 1
		endif
	endfor
	Redimension/N=(m) idx
	return m
End

Static Function/S AT_E_GroupIdx(ctw, idx, ciW, siW, nsW)
	WAVE/T ctw
	WAVE idx, ciW, siW, nsW
	Variable i, ci, m = numpnts(idx)
	String catList = ""
	for (i = 0; i < m; i += 1)
		ci = WhichListItem(ctw[idx[i]], catList)
		if (ci < 0)
			catList = AddListItem(ctw[idx[i]], catList, ";", inf)
			ci = ItemsInList(catList) - 1
		endif
		ciW[i] = ci
	endfor
	Variable nc = ItemsInList(catList)
	Make/FREE/N=(nc) perCat = 0
	for (i = 0; i < m; i += 1)
		siW[i] = perCat[ciW[i]]
		perCat[ciW[i]] += 1
	endfor
	for (i = 0; i < m; i += 1)
		nsW[i] = perCat[ciW[i]]
	endfor
	return catList
End

//  Red and blue gradients, dark -> light, 7 steps each.
StrConstant ksAT_E_RED  = "103,0,13;165,15,21;203,24,29;239,59,44;251,106,74;252,146,114;252,187,161"
StrConstant ksAT_E_BLUE = "8,48,107;8,81,156;33,113,181;66,146,198;107,174,214;158,202,225;198,219,239"

//  Creates RGB waves in the experiment; graph coloring uses direct RGB.
Function AT_E_MakeColorTables()
	NewDataFolder/O root:Packages
	NewDataFolder/O root:Packages:ColorTables
	NewDataFolder/O root:Packages:ColorTables:AcademicToolbox
	AT_E_MkCT("RedDarkToLight",  ksAT_E_RED,  0)
	AT_E_MkCT("RedLightToDark",  ksAT_E_RED,  1)
	AT_E_MkCT("BlueDarkToLight", ksAT_E_BLUE, 0)
	AT_E_MkCT("BlueLightToDark", ksAT_E_BLUE, 1)
	return 0
End

Static Function AT_E_MkCT(nm, lst, flip)
	String nm, lst
	Variable flip
	Variable n = ItemsInList(lst), i, k, r, g, b
	Make/O/W/U/N=(n, 3) root:Packages:ColorTables:AcademicToolbox:$nm
	WAVE ct = root:Packages:ColorTables:AcademicToolbox:$nm
	for (i = 0; i < n; i += 1)
		k = (flip != 0) ? (n - 1 - i) : i
		sscanf StringFromList(k, lst), "%d,%d,%d", r, g, b
		ct[i][0] = r * 257
		ct[i][1] = g * 257
		ct[i][2] = b * 257
	endfor
	return 0
End

//  which: 1 = red, 2 = blue.  Interpolates inside the gradient so any
//  number of curves is spread evenly from dark to light.
Function AT_E_GradColor(which, i, n, r, g, b)
	Variable which, i, n
	Variable &r, &g, &b
	String lst = ksAT_E_RED
	if (which == 2)
		lst = ksAT_E_BLUE
	endif
	Variable nc = ItemsInList(lst)
	Variable f = (n <= 1) ? 0 : i / (n - 1)
	Variable x = f * (nc - 1)
	Variable k = floor(x)
	Variable t = x - k
	if (k > nc - 2)
		k = nc - 2
		t = 1
	endif
	Variable r1, g1, b1, r2, g2, b2
	sscanf StringFromList(k, lst), "%d,%d,%d", r1, g1, b1
	sscanf StringFromList(k + 1, lst), "%d,%d,%d", r2, g2, b2
	r = (r1 + (r2 - r1) * t) * 257
	g = (g1 + (g2 - g1) * t) * 257
	b = (b1 + (b2 - b1) * t) * 257
	return 0
End

//  Recolour every trace of a graph along a gradient, in trace order.
Function AT_E_RecolorGradient(gName, which)
	String gName
	Variable which
	if (strlen(gName) == 0)
		gName = WinName(0, 1)
	endif
	if (strlen(gName) == 0)
		return -1
	endif
	String tl = TraceNameList(gName, ";", 1), tn
	Variable i, n = ItemsInList(tl), r, g, b
	for (i = 0; i < n; i += 1)
		tn = StringFromList(i, tl)
		AT_E_GradColor(which, i, n, r, g, b)
		ModifyGraph/W=$gName rgb($tn) = (r, g, b)
	endfor
	return n
End

Static Function AT_E_Palette(idx, r, g, b)
	Variable idx
	Variable &r, &g, &b
	Variable k   = mod(abs(idx), kAT_E_NPAL)
	Variable cyc = floor(abs(idx) / kAT_E_NPAL)
	Variable rr, gg, bb
	sscanf StringFromList(k, ksAT_E_PAL), "%d,%d,%d", rr, gg, bb
	r = rr * 257 ; g = gg * 257 ; b = bb * 257
	if (cyc > 0)
		Variable f = min(0.55, 0.28 * cyc)
		r += (65535 - r) * f ; g += (65535 - g) * f ; b += (65535 - b) * f
	endif
End

Static Function AT_E_TraceColor(mode, ci, si, ns, k, r, g, b)
	Variable mode, ci, si, ns, k
	Variable &r, &g, &b
	Variable f
	if (mode == 1)
		AT_E_Palette(ci, r, g, b)
	elseif (mode == 2)
		AT_E_Palette(ci, r, g, b)
		f = (ns <= 1) ? 0 : 0.62 * si / (ns - 1)
		r += (65535 - r) * f
		g += (65535 - g) * f
		b += (65535 - b) * f
	elseif (mode == 4 || mode == 5)
		AT_E_GradColor(mode - 3, si, ns, r, g, b)
	else
		AT_E_Palette(k, r, g, b)
	endif
End

Static Function AT_E_NiceRange(lo, hi, loOut, hiOut, stepOut)
	Variable lo, hi
	Variable &loOut, &hiOut, &stepOut
	if (numtype(lo) != 0 || numtype(hi) != 0)
		lo = 0 ; hi = 1
	endif
	if (hi <= lo)
		hi = lo + max(1, abs(lo) * 0.1)
	endif
	Variable pad = (hi - lo) * 0.04
	lo -= pad ; hi += pad
	Variable raw  = (hi - lo) / 5
	Variable mag  = 10 ^ floor(log(raw))
	Variable norm = raw / mag
	Variable step
	if (norm <= 1)
		step = 1 * mag
	elseif (norm <= 2)
		step = 2 * mag
	elseif (norm <= 2.5)
		step = 2.5 * mag
	elseif (norm <= 5)
		step = 5 * mag
	else
		step = 10 * mag
	endif
	loOut   = floor(lo / step) * step
	hiOut   = ceil(hi / step) * step
	stepOut = step
End

Static Function AT_E_Digits(step)
	Variable step
	Variable d
	for (d = 0; d < 6; d += 1)
		if (abs(step * 10 ^ d - round(step * 10 ^ d)) < 1e-9)
			return d
		endif
	endfor
	return 3
End

//  round a positive maximum up to a friendly value: 4147 -> 4500
Static Function AT_E_CeilNice(v)
	Variable v
	if (!(v > 0))
		return 1
	endif
	Variable q = 10 ^ floor(log(v)) / 2
	return ceil(v / q) * q
End

//  zeroBase != 0 pins the axis at 0 and rounds the top up
Static Function AT_E_SetNiceAxis(gName, ax, lo, hi, reverse, zeroBase)
	String gName, ax
	Variable lo, hi, reverse, zeroBase
	Variable a, b, st
	if (zeroBase != 0 && lo >= 0)
		a = 0
		b = AT_E_CeilNice(hi)
	else
		AT_E_NiceRange(lo, hi, a, b, st)
	endif
	if (reverse)
		SetAxis/W=$gName $ax b, a
	else
		SetAxis/W=$gName $ax a, b
	endif
	ModifyGraph/W=$gName nticks($ax) = 5, minor($ax) = 0		// automatic, about 5 ticks
End

// =====================================================================
//  APPEARANCE PREFERENCES  (shared with the control panel and with
//  UVvis_Spectra.ipf -- both packages read root:Packages:AcademicToolbox)
// =====================================================================

Function AT_E_InitPrefs()
	NewDataFolder/O root:Packages
	NewDataFolder/O root:Packages:AcademicToolbox
	AT_E_DefPref("gradient",1)
	AT_E_DefPref("currentScale",1)
	AT_E_DefPref("timeScale",1)
	AT_E_DefPref("fontSize",   16)
	AT_E_DefPref("lineWidth",  2.5)
	AT_E_DefPref("axThick",    2)
	AT_E_DefPref("markerSize", 6)
	AT_E_DefPref("fixedSize",  0)
	AT_E_DefPref("widthCM",    7)
	AT_E_DefPref("heightCM",   5)
	AT_E_DefPref("winW",       720)
	AT_E_DefPref("winH",       560)
	return 0
End

Static Function AT_E_DefPref(nm, val)
	String nm
	Variable val
	NVAR/Z v = root:Packages:AcademicToolbox:$nm
	if (!NVAR_Exists(v))
		Variable/G root:Packages:AcademicToolbox:$nm = val
	endif
End

Function AT_E_ResetPrefs()
	AT_E_InitPrefs()
	String names="fontSize;lineWidth;axThick;markerSize;fixedSize;widthCM;heightCM;winW;winH"
	String values="16;2.5;2;6;0;7;5;720;560"
	Variable i
	for(i=0;i<ItemsInList(names);i+=1)
		NVAR pref=root:Packages:AcademicToolbox:$(StringFromList(i,names))
		pref=str2num(StringFromList(i,values))
	endfor
	return 0
End

//  Fonts, axis thickness and the fixed/resizable size mode.
//  doTraces != 0 also pushes the line width and marker size onto
//  every trace, which is what the panel buttons use.
Function AT_E_ApplyLook(gName, doTraces)
	String gName
	Variable doTraces
	if (strlen(gName) == 0)
		gName = WinName(0, 1)
	endif
	if (strlen(gName) == 0)
		return -1
	endif
	AT_E_InitPrefs()
	NVAR fs  = root:Packages:AcademicToolbox:fontSize
	NVAR ax  = root:Packages:AcademicToolbox:axThick
	NVAR lwv = root:Packages:AcademicToolbox:lineWidth
	NVAR mk  = root:Packages:AcademicToolbox:markerSize
	NVAR fx  = root:Packages:AcademicToolbox:fixedSize
	NVAR wcm = root:Packages:AcademicToolbox:widthCM
	NVAR hcm = root:Packages:AcademicToolbox:heightCM

	if (fx != 0)
		ModifyGraph/W=$gName width = wcm * 28.3465, height = hcm * 28.3465
	else
		ModifyGraph/W=$gName width = 0, height = 0		// 0 = fill the window (resizable)
	endif

	ModifyGraph/W=$gName gFont = "Arial", gfSize = fs
	ModifyGraph/W=$gName font = "Arial", fSize = fs
	ModifyGraph/W=$gName axThick = ax, tick = 2, mirror = 1, minor = 0, standoff = 0
	ModifyGraph/W=$gName btLen = round(3 * ax) + 2, btThick = ax
	ModifyGraph/W=$gName stLen = round(1.5 * ax) + 1, stThick = ax
	ModifyGraph/W=$gName lblMargin(left) = 4, lblMargin(bottom) = 4
	ModifyGraph/W=$gName margin(left) = 0, margin(bottom) = 0		// 0 = automatic
	ModifyGraph/W=$gName margin(right) = 16, margin(top) = 16

	if (doTraces)
		Variable i
		String tl = TraceNameList(gName, ";", 1), tn
		for (i = 0; i < ItemsInList(tl); i += 1)
			tn = StringFromList(i, tl)
			ModifyGraph/W=$gName lsize($tn) = lwv, msize($tn) = mk
		endfor
	endif
	return 0
End

Function AT_E_ApplyLookAll()
	String list = WinList("*", ";", "WIN:1")
	Variable i
	for (i = 0; i < ItemsInList(list); i += 1)
		AT_E_ApplyLook(StringFromList(i, list), 1)
	endfor
	return ItemsInList(list)
End

Static Function AT_E_Style(gName, xlab, ylab)
	String gName, xlab, ylab
	AT_E_ApplyLook(gName, 0)
	ModifyGraph/W=$gName tickUnit=1
	Label/W=$gName bottom xlab
	Label/W=$gName left   ylab
End

Static Function AT_E_PutLegend(gName, leg)
	String gName, leg
	if (strlen(leg) == 0)
		return 0
	endif
	leg = RemoveEnding(leg, "\r")
	Legend/W=$gName/C/N=legOE/J/F=0/A=RT/X=3/Y=3 leg
End

Function AT_U_LoadFolder()

	String ext = ".txt;.csv"
	Variable fmt = 1
	Variable skipLines = 0
	Variable encSel = 1
	String sep = "auto"
	Variable nCat = 3
	Variable nameMode = 1
	Variable clearFirst = 2

	Prompt ext,        "Extensions (.txt;.csv; ???? = all)"
	Prompt fmt,        "File format", popup, "JASCO ASCII (find XYDATA automatically);Plain 2-column text"
	Prompt skipLines,  "Plain text only: lines to skip before the data"
	Prompt encSel,     "Text encoding of the files", popup, "Windows-1252 (Latin 1);UTF-8;MacRoman;let Igor decide"
	Prompt sep,        "Filename separator (auto, space, or _)"
	Prompt nCat,       "Tokens AFTER the sample used as CATEGORY"
	Prompt nameMode,   "Wave names", popup, "Start at the sample token (s6_...);Full file name"
	Prompt clearFirst, "Clear data already loaded?", popup, "Yes;No"
	DoPrompt "Load UV-vis raw data", ext, fmt, skipLines, encSel, sep, nCat, nameMode, clearFirst
	if (V_flag)
		return -1
	endif

	NewPath/O/Q/M="Select the folder holding the UV-vis raw data" AT_Upath
	if (V_flag)
		return -1
	endif

	if (clearFirst == 1)
		KillDataFolder/Z root:AT_UV
	endif
	NewDataFolder/O root:AT_UV
	NewDataFolder/O root:AT_UV:Raw
	NewDataFolder/O root:AT_UV:Corr

	WAVE/Z/T chk = root:AT_UV:FileName
	if (!WaveExists(chk))
		Make/O/T/N=0 root:AT_UV:FileName, root:AT_UV:BaseName, root:AT_UV:Category, root:AT_UV:Sample
	endif
	WAVE/T fnw = root:AT_UV:FileName
	WAVE/T bnw = root:AT_UV:BaseName
	WAVE/T ctw = root:AT_UV:Category
	WAVE/T spw = root:AT_UV:Sample

	Variable i = 0, nOK = 0, nBad = 0, nNoSample = 0, nInterp = 0, rc
	String fn
	String fileList=AT_FileList("AT_Upath",ext)

	do
		fn = StringFromList(i,fileList)
		if (strlen(fn) == 0)
			break
		endif
		i += 1

		rc = AT_U_Ingest(fn, sep, nCat, nameMode, fmt, skipLines, AT_E_EncCode(encSel), nInterp)
		if (rc == 0)
			nBad += 1
		else
			nOK += 1
			if (rc == 2)
				nNoSample += 1
			endif
		endif
	while (1)

	Printf "AT_U_LoadFolder: %d spectrum/spectra loaded, %d skipped, %d re-gridded.\r", nOK, nBad, nInterp
	if (nNoSample > 0)
		Printf "  ! %d file(s) had no s1...s99 token; sample set to \"unknown\".\r", nNoSample
	endif
	WAVE/Z wlChk = root:AT_UV:Wavelength
	if (WaveExists(wlChk))
		Printf "  master wavelength axis: %d points, %.1f - %.1f nm\r", numpnts(wlChk), wlChk[0], wlChk[numpnts(wlChk) - 1]
	endif
	if (nOK == 0)
		DoAlert 0, "Nothing was loaded.\rCheck the extension and the file format setting."
	endif
	return nOK
End

//  returns 0 = on the master grid, 1 = interpolated, -1 = failed
//  Resolve encoding names through Igor; 255 is binary, NOT UTF-8.
//  UTF-8=1, MacRoman=2, Windows-1252=3, 0=let Igor decide.  JASCO and most instrument
//  exports on Windows are Windows-1252.
//  Parse the name, load the spectrum, append the metadata row.
//  Returns 0 = skipped, 1 = loaded, 2 = loaded but no sample token.
//  nInterp is incremented when the spectrum had to be re-gridded.
Static Function AT_U_Ingest(fn, sep, nCat, nameMode, fmt, skipLines, enc, nInterp)
	String fn, sep
	Variable nCat, nameMode, fmt, skipLines, enc
	Variable &nInterp

	WAVE/T fnw = root:AT_UV:FileName
	WAVE/T bnw = root:AT_UV:BaseName
	WAVE/T ctw = root:AT_UV:Category
	WAVE/T spw = root:AT_UV:Sample

	String stem = AT_E_StripExt(fn), samp = "", rest, base, cat
	Variable pos = AT_E_FindSample(stem, samp)
	rest = stem
	if (pos >= 0)
		rest = stem[pos, strlen(stem) - 1]
	else
		samp = "unknown"
	endif
	if(cmpstr(sep,"auto")==0)
		rest=ReplaceString("_",rest," ")
		sep=" "
	elseif(cmpstr(sep,"space")==0)
		sep=" "
	endif
	cat  = AT_E_CatFrom(rest, sep, nCat, pos >= 0)
	base = AT_U_UniqueBase(AT_E_MakeBase(stem, rest, nameMode))

	Variable rc = AT_U_LoadOne(fn, base, fmt, skipLines, enc)
	if (rc < 0)
		Print "  ! skipped (could not find a 2-column data block): " + fn
		return 0
	endif
	nInterp += rc

	Variable n = numpnts(fnw)
	Redimension/N=(n + 1) fnw, bnw, ctw, spw
	fnw[n] = fn
	bnw[n] = base
	ctw[n] = cat
	spw[n] = samp
	return (pos >= 0) ? 1 : 2
End

//  Load one or several individually chosen spectra instead of a folder
Function AT_U_LoadFiles()

	Variable fmt = 1
	Variable skipLines = 0
	Variable encSel = 1
	String sep = "auto"
	Variable nCat = 3
	Variable nameMode = 1
	Variable clearFirst = 2

	Prompt fmt,        "File format", popup, "JASCO ASCII (find XYDATA automatically);Plain 2-column text"
	Prompt skipLines,  "Plain text only: lines to skip before the data"
	Prompt encSel,     "Text encoding of the files", popup, "Windows-1252 (Latin 1);UTF-8;MacRoman;let Igor decide"
	Prompt sep,        "Filename separator (auto, space, or _)"
	Prompt nCat,       "Tokens AFTER the sample used as CATEGORY"
	Prompt nameMode,   "Wave names", popup, "Start at the sample token (s6_...);Full file name"
	Prompt clearFirst, "Clear data already loaded?", popup, "Yes;No"
	DoPrompt "Load individual UV-vis files", fmt, skipLines, encSel, sep, nCat, nameMode, clearFirst
	if (V_flag)
		return -1
	endif

	Variable refNum
	Open/D/R/MULT=1/M="Select one or more UV-vis data files" refNum
	String list = S_fileName
	if (strlen(list) == 0)
		return -1
	endif

	if (clearFirst == 1)
		KillDataFolder/Z root:AT_UV
	endif
	NewDataFolder/O root:AT_UV
	NewDataFolder/O root:AT_UV:Raw
	NewDataFolder/O root:AT_UV:Corr
	WAVE/Z/T chk = root:AT_UV:FileName
	if (!WaveExists(chk))
		Make/O/T/N=0 root:AT_UV:FileName, root:AT_UV:BaseName, root:AT_UV:Category, root:AT_UV:Sample
	endif

	Variable i, rc, nOK = 0, nBad = 0, nNoSample = 0, nInterp = 0
	Variable nf = ItemsInList(list, "\r")
	String full, dir, fn, psep
	for (i = 0; i < nf; i += 1)
		full = StringFromList(i, list, "\r")
		if (strlen(full) == 0)
			continue
		endif
		psep = AT_E_PathSep(full)
		dir  = ParseFilePath(1, full, psep, 1, 0)
		fn   = ParseFilePath(0, full, psep, 1, 0)
		NewPath/O/Q AT_Upath dir
		rc = AT_U_Ingest(fn, sep, nCat, nameMode, fmt, skipLines, AT_E_EncCode(encSel), nInterp)
		if (rc == 0)
			nBad += 1
		else
			nOK += 1
			if (rc == 2)
				nNoSample += 1
			endif
		endif
	endfor

	WAVE/T fnw = root:AT_UV:FileName
	Printf "AT_U_LoadFiles: %d spectrum/spectra loaded, %d skipped, %d re-gridded. Total: %d\r", nOK, nBad, nInterp, numpnts(fnw)
	if (nNoSample > 0)
		Printf "  ! %d file(s) had no s1...s99 token; sample set to \"unknown\".\r", nNoSample
	endif
	return nOK
End

Static Function AT_U_LoadOne(fn, base, fmt, skipLines, enc)
	String fn, base
	Variable fmt, skipLines, enc

	Variable firstLine = skipLines
	Variable nLines = 0
	if (fmt == 1)
		if (AT_U_ScanJASCO(fn, enc, firstLine, nLines) != 0)
			return -1
		endif
	endif

	String saveDF = GetDataFolder(1)
	KillDataFolder/Z root:AT_UV:tmp
	NewDataFolder/O/S root:AT_UV:tmp

	if (enc > 0)
		LoadWave/J/D/A=uvcol/K=0/O/Q/ENCG=(enc)/L={0, firstLine, nLines, 0, 0}/P=AT_Upath fn
	else
		LoadWave/J/D/A=uvcol/K=0/O/Q/L={0, firstLine, nLines, 0, 0}/P=AT_Upath fn
	endif
	if (V_flag < 2)
		SetDataFolder saveDF
		KillDataFolder/Z root:AT_UV:tmp
		return -1
	endif

	String names = S_waveNames
	String nX = AT_U_FindCol(names, "wavelength;lambda;nm")
	String nY = AT_U_FindCol(names, "absorbance;abs;od")
	if (strlen(nX) == 0)
		nX = StringFromList(0, names)
	endif
	if (strlen(nY) == 0 || cmpstr(nY, nX) == 0)
		nY = StringFromList(1, names)
	endif

	WAVE/Z xw = $nX
	WAVE/Z yw = $nY
	if (!WaveExists(xw) || !WaveExists(yw))
		SetDataFolder saveDF
		KillDataFolder/Z root:AT_UV:tmp
		return -1
	endif

	if (AT_U_MakeAscending(xw, yw) < 0)
		SetDataFolder saveDF
		KillDataFolder/Z root:AT_UV:tmp
		return -1
	endif
	NewDataFolder/O root:AT_UV:Native
	Duplicate/O xw,root:AT_UV:Native:$(base+"_nm")
	Duplicate/O yw,root:AT_UV:Native:$(base+"_Abs")

	Variable interped = 0
	WAVE/Z master0 = root:AT_UV:Wavelength
	if (!WaveExists(master0))							// first file defines the axis
		Duplicate/O xw, root:AT_UV:Wavelength
		Duplicate/O yw, root:AT_UV:Raw:$(base + "_Abs")
	else
		WAVE master = root:AT_UV:Wavelength
		Variable nm0 = numpnts(master), nx0 = numpnts(xw)
		if (AT_SameGrid(xw,master))
			Duplicate/O yw, root:AT_UV:Raw:$(base + "_Abs")
		else
			Make/O/D/N=(nm0) root:AT_UV:Raw:$(base + "_Abs")
			WAVE dst = root:AT_UV:Raw:$(base + "_Abs")
			dst = (master[p]<xw[0] || master[p]>xw[nx0-1]) ? NaN : interp(master[p], xw, yw)
			interped = 1
		endif
	endif

	SetDataFolder saveDF
	KillDataFolder/Z root:AT_UV:tmp
	return interped
End

//  find the XYDATA line and the NPOINTS value of a JASCO ASCII export
Static Function AT_U_ScanJASCO(fn, enc, firstLine, nLines)
	String fn
	Variable enc
	Variable &firstLine, &nLines

	Variable refNum
	if (enc > 0)
		Open/R/Z/ENCG=(enc)/P=AT_Upath refNum as fn
	else
		Open/R/Z/P=AT_Upath refNum as fn
	endif
	if (V_flag != 0)
		return -1
	endif

	String buf
	Variable i = 0, np = 0, found = -1
	do
		FReadLine refNum, buf
		if (strlen(buf) == 0)
			break
		endif
		if (strsearch(buf, "NPOINTS", 0, 2) >= 0)
			np = str2num(ReplaceString(",",ReplaceString("=",ReplaceString("NPOINTS", UpperStr(buf), "")," ")," "))
		endif
		if (strsearch(buf, "XYDATA", 0, 2) >= 0)
			found = i + 1
			break
		endif
		i += 1
		if (i > 500)
			break
		endif
	while (1)
	Close refNum

	if (found < 0 || numtype(np)!=0 || np<2)
		return -1
	endif
	firstLine = found
	nLines = (numtype(np) == 0) ? np : 0
	return 0
End

Function AT_U_ListFiles()
	WAVE/Z/T chk = root:AT_UV:BaseName
	if (!WaveExists(chk))
		Print "Nothing loaded."
		return -1
	endif
	WAVE/T bnw = root:AT_UV:BaseName
	WAVE/T ctw = root:AT_UV:Category
	WAVE/T spw = root:AT_UV:Sample
	Variable i
	Printf "%-8s %-24s %s\r", "sample", "category", "wave base name"
	for (i = 0; i < numpnts(bnw); i += 1)
		Printf "%-8s %-24s %s\r", spw[i], ctw[i], bnw[i]
	endfor
End

Function AT_U_KillAll()
	DoAlert 1, "Delete root:AT_UV completely?"
	if (V_flag == 1)
		KillDataFolder/Z root:AT_UV
	endif
End

// =====================================================================
//  2.  CORRECTION
// =====================================================================

Function AT_U_Correct()

	WAVE/Z/T chk  = root:AT_UV:BaseName
	WAVE/Z   chk2 = root:AT_UV:Wavelength
	if (!WaveExists(chk) || !WaveExists(chk2))
		DoAlert 0, "No data. Run \"Load UV-vis folder\" first."
		return -1
	endif

	Variable loNM = 1200
	Variable hiNM = 1300
	Variable doBase = 1
	Variable jLo = 850
	Variable jHi = 851
	Variable nFit = 5
	Variable nSkip = 2
	Variable doJump = 1
	Variable blankSeam = 2

	Prompt loNM,      "Baseline window, lower limit (nm)"
	Prompt hiNM,      "Baseline window, upper limit (nm)"
	Prompt doBase,    "Apply the baseline zeroing?", popup, "Yes;No"
	Prompt jLo,       "Jump: last wavelength of the vis branch (nm)"
	Prompt jHi,       "Jump: first wavelength of the NIR branch (nm)"
	Prompt nFit,      "Points fitted on EACH side of the seam"
	Prompt nSkip,     "Points skipped next to the seam (transition)"
	Prompt doJump,    "Apply the jump correction?", popup, "Yes;No"
	Prompt blankSeam, "Blank the skipped seam points?", popup, "Yes;No"
	DoPrompt "Correct UV-vis spectra", loNM, hiNM, doBase, jLo, jHi, nFit, nSkip, doJump, blankSeam
	if (V_flag)
		return -1
	endif

	String refChoice="Automatic (minimum across all spectra);"
	Variable refIndex
	for(refIndex=0;refIndex<numpnts(chk);refIndex+=1)
		refChoice+=chk[refIndex]+";"
	endfor
	Variable refSel=1
	if(doBase==1)
		Prompt refSel,"Reference spectrum for baseline minimum",popup,refChoice
		DoPrompt "Baseline reference",refSel
		if(V_flag)
			return -1
		endif
	endif
	if(numtype(loNM+hiNM+jLo+jHi+nFit+nSkip)!=0 || nFit<1 || nSkip<0)
		DoAlert 0,"Enter finite wavelengths, fit points >=1 and skip points >=0."
		return -1
	endif
	nFit=round(nFit)
	nSkip=round(nSkip)
	if(doBase==1 && (max(loNM,hiNM)<chk2[0] || min(loNM,hiNM)>chk2[numpnts(chk2)-1]))
		DoAlert 0,"The baseline window does not overlap the measured wavelengths."
		return -1
	endif
	return AT_U_CorrectCore(loNM,hiNM,doBase,jLo,jHi,nFit,nSkip,doJump,blankSeam,refSel)
End

Static Function AT_U_CorrectCore(loNM,hiNM,doBase,jLo,jHi,nFit,nSkip,doJump,blankSeam,refSel)
	Variable loNM,hiNM,doBase,jLo,jHi,nFit,nSkip,doJump,blankSeam,refSel
	WAVE     wl  = root:AT_UV:Wavelength
	WAVE/T   bnw = root:AT_UV:BaseName
	Variable ns  = numpnts(bnw)
	Variable npt = numpnts(wl)
	Variable i, j

	NewDataFolder/O root:AT_UV:Corr

	// ---- fresh copies of the raw data ------------------------------
	for (j = 0; j < ns; j += 1)
		WAVE/Z src = root:AT_UV:Raw:$(bnw[j] + "_Abs")
		if (!WaveExists(src))
			continue
		endif
		Duplicate/O src, root:AT_UV:Corr:$(bnw[j] + "_Absc")
	endfor

	// ---- grating jump: match the two branches at the seam ----------
	if (doJump == 1)
		Variable pVis = AT_U_LastIdxAtOrBelow(wl, min(jLo, jHi))
		Variable pNir = AT_U_FirstIdxAtOrAbove(wl, max(jLo, jHi))
		if (pVis < 0 || pNir < 0 || pNir <= pVis)
			DoAlert 0, "The seam wavelengths do not bracket two points.\rJump correction skipped."
		else
			Variable xSeam = 0.5 * (wl[pVis] + wl[pNir])
			Variable k = max(1, nSkip)
			if (nSkip <= 0)
				k = 0
			endif
			Variable visB = max(0, pVis - k)
			Variable visA = max(0, visB - max(2, nFit) + 1)
			Variable nirA = min(npt - 1, pNir + k)
			Variable nirB = min(npt - 1, nirA + max(2, nFit) - 1)

			Variable worse = 0
			for (j = 0; j < ns; j += 1)
				WAVE/Z w = root:AT_UV:Corr:$(bnw[j] + "_Absc")
				if (!WaveExists(w))
					continue
				endif

				Variable step0 = w[pNir] - w[pVis]			// discontinuity before
				Variable delta
				if (nFit >= 2 && visB > visA && nirB > nirA)
					Variable pv = AT_U_FitAt(wl, w, visA, visB, xSeam)
					Variable pn = AT_U_FitAt(wl, w, nirA, nirB, xSeam)
					delta = pv - pn
				else
					delta = w[pVis] - w[pNir]				// plain point match
				endif

				//  safety net: never leave a bigger step than we started with
				if (abs(step0 + delta) > abs(step0))
					delta = w[pVis] - w[pNir]
					worse += 1
				endif

				if(numtype(delta)!=0)
					Print "Jump skipped (nonfinite seam): "+bnw[j]
					continue
				endif
				w[pVis + 1, npt - 1] += delta				// shift the whole NIR branch
			endfor

			Printf "AT_U_Correct: seam at %.1f nm, NIR branch (points %d+) shifted onto the vis branch.\r", xSeam, pVis + 1
			if (worse > 0)
				Printf "  ! %d spectrum/spectra fell back to a single-point match (noisy seam).\r", worse
			endif

			if (blankSeam == 1 && k > 0)
				for (j = 0; j < ns; j += 1)
					WAVE/Z w = root:AT_UV:Corr:$(bnw[j] + "_Absc")
					if (!WaveExists(w))
						continue
					endif
					w[max(0, pVis - k + 1), min(npt - 1, pNir + k - 1)] = NaN
				endfor
				Printf "  seam points %.1f - %.1f nm blanked.\r", wl[max(0, pVis - k + 1)], wl[min(npt - 1, pNir + k - 1)]
			endif

			AT_U_ReportSeam(wl, bnw, pVis, pNir)
		endif
	endif

	// ---- baseline: one common anchor wavelength --------------------
	if (doBase == 1)
		Variable pA = AT_U_FirstIdxAtOrAbove(wl, max(wl[0],min(loNM, hiNM)))
		Variable pB = AT_U_LastIdxAtOrBelow(wl, min(wl[npt-1],max(loNM, hiNM)))
		if (pB < pA)
			DoAlert 0,"No sampled wavelength is inside the baseline window."
			return -1
		endif

		Variable pRef = -1, vRef = inf
		String refBase = ""
		for (j = 0; j < ns; j += 1)
			if(refSel>1 && j!=refSel-2)
				continue
			endif
			WAVE/Z w = root:AT_UV:Corr:$(bnw[j] + "_Absc")
			if (!WaveExists(w))
				continue
			endif
			for (i = pA; i <= pB; i += 1)
				if (numtype(w[i]) == 0 && w[i] < vRef)
					vRef = w[i]
					pRef = i
					refBase = bnw[j]
				endif
			endfor
		endfor

		if (pRef < 0)
			DoAlert 0, "No valid data inside the baseline window."
		else
			for (j = 0; j < ns; j += 1)
				WAVE/Z w = root:AT_UV:Corr:$(bnw[j] + "_Absc")
				if (!WaveExists(w))
					continue
				endif
				if(numtype(w[pRef])!=0)
					Print "Baseline skipped (missing anchor): "+bnw[j]
					continue
				endif
				Variable v0 = w[pRef]			// read BEFORE the assignment
				w -= v0
			endfor
			Printf "AT_U_Correct: baseline anchor %.1f nm (lowest absorbance %.5f, in %s)\r", wl[pRef], vRef, refBase
		endif
	endif

	String correctionNote="AcademicToolbox; jump="+num2str(doJump==1)+"; seam="+num2str(jLo)+","+num2str(jHi)+"; fit="+num2str(nFit)+"; skip="+num2str(nSkip)+"; baseline="+num2str(doBase==1)+"; window="+num2str(loNM)+","+num2str(hiNM)+"; referenceSelection="+num2str(refSel)
	for(j=0;j<ns;j+=1)
		WAVE/Z recorded=root:AT_UV:Corr:$(bnw[j]+"_Absc")
		if(WaveExists(recorded))
			Note recorded,correctionNote
		endif
	endfor
	Print "AT_U_Correct: corrected spectra are in root:AT_UV:Corr (raw data untouched)."
	return 0
End

//  print the residual step at the seam so the correction can be checked
Static Function AT_U_ReportSeam(wl, bnw, pVis, pNir)
	WAVE wl
	WAVE/T bnw
	Variable pVis, pNir
	Variable j
	Printf "  residual step at the seam (corrected - should be near 0):\r"
	for (j = 0; j < numpnts(bnw); j += 1)
		WAVE/Z c = root:AT_UV:Corr:$(bnw[j] + "_Absc")
		WAVE/Z r = root:AT_UV:Raw:$(bnw[j] + "_Abs")
		if (!WaveExists(c) || !WaveExists(r))
			continue
		endif
		Printf "    %-40s before %+8.5f   after %+8.5f\r", bnw[j], r[pNir] - r[pVis], c[pNir] - c[pVis]
	endfor
End

// =====================================================================
//  3.  PLOTTING
// =====================================================================

Function AT_U_PlotSpectra()

	WAVE/Z/T chk  = root:AT_UV:BaseName
	WAVE/Z   chk2 = root:AT_UV:Wavelength
	if (!WaveExists(chk) || !WaveExists(chk2))
		DoAlert 0, "No data. Run \"Load UV-vis folder\" first."
		return -1
	endif

	AT_E_InitPrefs()
	NVAR gLW = root:Packages:AcademicToolbox:lineWidth
	NVAR gMK = root:Packages:AcademicToolbox:markerSize
	NVAR gWW = root:Packages:AcademicToolbox:winW
	NVAR gWH = root:Packages:AcademicToolbox:winH

	String catFilter = "*"
	Variable pickMode = 2
	Variable useCorr = 1
	NVAR savedGradient=root:Packages:AcademicToolbox:gradient
	Variable colorMode = savedGradient+3
	Variable lw = gLW
	Variable xLo = 400
	Variable xHi = 1600
	Variable showLeg = 1

	Prompt catFilter, "Category filter ( * = all )"
	Prompt pickMode,   "Data selection", popup, "Everything matching the filter;Choose from a list..."
	Prompt useCorr,   "Which data?", popup, "Corrected;Raw"
	Prompt colorMode, "Colouring", popup, "One colour per category;Shades within each category;Every curve distinct;Red gradient (dark to light);Blue gradient (dark to light)"
	Prompt lw,        "Line thickness (pt)"
	Prompt xLo,       "Wavelength axis, from (nm)  [0 = auto]"
	Prompt xHi,       "Wavelength axis, to (nm)    [0 = auto]"
	Prompt showLeg,   "Legend", popup, "Show;Hide"
	DoPrompt "Plot UV-vis spectra", catFilter, pickMode, useCorr, colorMode, lw, xLo, xHi, showLeg
	if (V_flag)
		return -1
	endif

	String df  = "root:AT_UV:Raw:"
	String sfx = "_Abs"
	if (useCorr == 1)
		df  = "root:AT_UV:Corr:"
		sfx = "_Absc"
	endif

	WAVE   wl  = root:AT_UV:Wavelength
	WAVE/T bnw = root:AT_UV:BaseName
	WAVE/T ctw = root:AT_UV:Category
	WAVE/T spw = root:AT_UV:Sample

	Make/FREE/N=0 idx
	if (AT_E_Select(ctw, catFilter, idx) == 0)
		DoAlert 0, "No spectrum matches that category filter."
		return -1
	endif
	Variable m = numpnts(idx)

	if (pickMode == 2)
		m = AT_E_PickFrom(idx, bnw, ctw, spw)
		if (m <= 0)
			return -1
		endif
	endif

	Make/FREE/N=(m) ciW, siW, nsW
	String catList = AT_E_GroupIdx(ctw, idx, ciW, siW, nsW)

	if(xLo==0)
		xLo=wl[0]
	endif
	if(xHi==0)
		xHi=wl[numpnts(wl)-1]
	endif
	if(numtype(xLo+xHi)!=0 || xLo>=xHi || xHi<wl[0] || xLo>wl[numpnts(wl)-1])
		DoAlert 0,"Choose an increasing wavelength range overlapping the data."
		return -1
	endif
	Variable pA=AT_U_FirstIdxAtOrAbove(wl,max(xLo,wl[0]))
	Variable pB=AT_U_LastIdxAtOrBelow(wl,min(xHi,wl[numpnts(wl)-1]))
	if(pA<0 || pB<=pA)
		DoAlert 0,"The plot range needs at least two sampled wavelengths."
		return -1
	endif

	String gName = UniqueName("gUV", 6, 0)
	Display/N=$gName/W=(40, 40, 40 + gWW, 40 + gWH) as "UV-vis spectra"

	Variable i, nPlot = 0, ymin = inf, ymax = -inf
	String tn, leg = "", lastCat = ""

	for (i = 0; i < m; i += 1)
		WAVE/Z wy = $(df + bnw[idx[i]] + sfx)
		if (!WaveExists(wy))
			continue
		endif
		AppendToGraph/W=$gName wy vs wl
		tn = NameOfWave(wy)
		nPlot += 1

		ModifyGraph/W=$gName lsize($tn) = lw

		Variable r, g, b
		AT_E_TraceColor(colorMode, ciW[i], siW[i], nsW[i], i, r, g, b)
		ModifyGraph/W=$gName rgb($tn) = (r, g, b)

		WaveStats/Q/M=1/R=[pA, pB] wy
		ymin = min(ymin, V_min)
		ymax = max(ymax, V_max)

		if (showLeg == 1)
			if (colorMode == 1)
				if (cmpstr(ctw[idx[i]], lastCat) != 0 && siW[i] == 0)
					leg += "\\s(" + tn + ") " + ctw[idx[i]] + "\r"
					lastCat = ctw[idx[i]]
				endif
			else
				leg += "\\s(" + tn + ") " + bnw[idx[i]] + "\r"
			endif
		endif
	endfor

	if (nPlot == 0)
		KillWindow $gName
		DoAlert 0, "Nothing to plot. Did you run the correction step?"
		return -1
	endif

	AT_E_SetNiceAxis(gName, "left", ymin, ymax, 0, 0)
	AT_E_SetNiceAxis(gName, "bottom", wl[pA], wl[pB], 0, 0)
	SetAxis/W=$gName bottom wl[pA], wl[pB]				// keep exactly the requested span
	AT_E_Style(gName, "Wavelength (nm)", "Absorbance")
	if(colorMode==4 || colorMode==5)
		AT_E_RecolorGradient(gName,colorMode-3)
	endif
	AT_E_PutLegend(gName, leg)

	return 0
End

// =====================================================================
//  NAME PARSING
// =====================================================================

//  Find "s" followed by 1 or 2 digits ANYWHERE in the file name --
//  not preceded by a letter or digit, not followed by one.  This copes
//  with s6 as its own token, with B043s6, with dashes instead of
//  underscores, and with upper case S.  Returns the character position
//  of the "s" (or -1) and puts e.g. "s6" into sampOut.
//  nCat tokens of "rest" after the sample token
//  nameMode 1 = start at the sample, 2 = whole file name
Static Function/S AT_U_UniqueBase(base)
	String base
	base=base[0,220]
	String b = base
	Variable k = 1
	do
		if (!exists("root:AT_UV:Raw:" + b + "_Abs"))
			return b
		endif
		b = base + "_" + num2istr(k)
		k += 1
	while (1)
End

Static Function/S AT_U_FindCol(names, keyList)
	String names, keyList
	Variable i, j
	String s, key
	for (j = 0; j < ItemsInList(keyList); j += 1)
		key = StringFromList(j, keyList)
		for (i = 0; i < ItemsInList(names); i += 1)
			s = StringFromList(i, names)
			if ((strlen(key)>2 && stringmatch(LowerStr(s), "*" + key + "*")) || cmpstr(s,key)==0 || stringmatch(LowerStr(s),key+"_*"))
				return s
			endif
		endfor
	endfor
	return ""
End

// =====================================================================
//  NUMERIC HELPERS
// =====================================================================

Static Function AT_U_MakeAscending(xw,yw)
	WAVE xw,yw
	Variable n=numpnts(xw),i
	if(n<2 || numpnts(yw)!=n)
		return -1
	endif
	if(xw[0]>xw[n-1])
		Reverse xw
		Reverse yw
	endif
	for(i=0;i<n;i+=1)
		if(numtype(xw[i])!=0)
			return -1
		endif
		if(i>0)
			if(xw[i]<=xw[i-1])
				return -1
			endif
		endif
	endfor
	return 0
End

Static Function AT_U_NearestIdx(wl, val)
	WAVE wl
	Variable val
	Variable i, d, bd = inf, best = 0, n = numpnts(wl)
	for (i = 0; i < n; i += 1)
		d = abs(wl[i] - val)
		if (d < bd)
			bd = d
			best = i
		endif
	endfor
	return best
End

//  ascending wl assumed
Static Function AT_U_LastIdxAtOrBelow(wl, val)
	WAVE wl
	Variable val
	Variable i, n = numpnts(wl), best = -1
	for (i = 0; i < n; i += 1)
		if (wl[i] <= val + 1e-9)
			best = i
		else
			break
		endif
	endfor
	return best
End

Static Function AT_U_FirstIdxAtOrAbove(wl, val)
	WAVE wl
	Variable val
	Variable i, n = numpnts(wl)
	for (i = 0; i < n; i += 1)
		if (wl[i] >= val - 1e-9)
			return i
		endif
	endfor
	return -1
End

//  least-squares line through points pA..pB of y(wl), evaluated at xTarget
Static Function AT_U_FitAt(wl, y, pA, pB, xTarget)
	WAVE wl, y
	Variable pA, pB, xTarget
	Variable i, n = 0, sx = 0, sy = 0, sxx = 0, sxy = 0, x, v
	for (i = pA; i <= pB; i += 1)
		x = wl[i]
		v = y[i]
		if (numtype(v) != 0)
			continue
		endif
		sx += x ; sy += v ; sxx += x * x ; sxy += x * v ; n += 1
	endfor
	Variable den = n * sxx - sx * sx
	if (n < 2 || den == 0)
		return y[pB]
	endif
	Variable slope = (n * sxy - sx * sy) / den
	Variable icept = (sy - slope * sx) / n
	return icept + slope * xTarget
End

// Shared control panel

// Backward-compatible default entry point.
Function AT_Panel()
	return AT_ElectricalPanel()
End

Function AT_ElectricalPanel()
	return AT_OpenPanel(0)
End

Function AT_OECTPanel()
	return AT_OpenPanel(1)
End

Static Function AT_OpenPanel(oect)
	Variable oect
	String panelName="ATpanel", panelTitle="Academic Toolbox - Electrical / UV-vis"
	if(oect)
		panelName="AToectPanel"
		panelTitle="Academic Toolbox - OECT / UV-vis"
	endif

	AT_E_InitPrefs()
	AT_E_MakeColorTables()
	NVAR grad=root:Packages:AcademicToolbox:gradient

	DoWindow/F $panelName
	if (V_flag != 0)
		return 0
	endif

	NewPanel/K=1/N=$panelName/W=(60, 50, 450, 730) as panelTitle
	ModifyPanel fixedSize=0

	// ---------------- electrical ------------------------------------
	GroupBox gbE, win=$panelName, pos={10, 6}, size={368, 182}, title="Electrical / OECT (shared loaded data)"
	Button bLoadE, win=$panelName, pos={24, 28}, size={165, 26}, proc=AT_Button, title="Load folder..."
	Button bFileE, win=$panelName, pos={199, 28}, size={165, 26}, proc=AT_Button, title="Load single file(s)..."
	Button bListE, win=$panelName, pos={24, 60}, size={245, 26}, proc=AT_Button, title="List loaded files"
	Button bKillE, win=$panelName, pos={279, 60}, size={85, 26}, proc=AT_Button, title="Clear data..."
	if(oect)
		Button bIV, win=$panelName, pos={24, 96}, size={340, 26}, proc=AT_Button, title="Plot Id vs Vg (transfer)"
		Button bSS, win=$panelName, pos={24, 128}, size={340, 26}, proc=AT_Button, title="Plot steady-state Id vs Vg"
	else
		Button bIt, win=$panelName, pos={24, 96}, size={340, 26}, proc=AT_Button, title="Plot Id vs time"
		Button bVref, win=$panelName, pos={24, 128}, size={340, 26}, proc=AT_Button, title="Plot Vref vs time"
	endif

	// ---------------- UV-vis ----------------------------------------
	GroupBox gbU, win=$panelName, pos={10, 196}, size={368, 150}, title="UV-vis"
	Button bLoadU, win=$panelName, pos={24, 218}, size={165, 26}, proc=AT_Button, title="Load folder..."
	Button bFileU, win=$panelName, pos={199, 218}, size={165, 26}, proc=AT_Button, title="Load single file(s)..."
	Button bListU, win=$panelName, pos={24, 250}, size={245, 26}, proc=AT_Button, title="List loaded spectra"
	Button bKillU, win=$panelName, pos={279, 250}, size={85, 26}, proc=AT_Button, title="Clear data..."
	Button bCorr,  win=$panelName, pos={24, 286}, size={340, 26}, proc=AT_Button, title="Correct (jump + reference baseline)"
	Button bPlotU, win=$panelName, pos={24, 318}, size={340, 26}, proc=AT_Button, title="Plot spectra"

	// ---------------- colours ---------------------------------------
	GroupBox gbC, win=$panelName, pos={10, 354}, size={368, 92}, title="Colour gradients"
	PopupMenu pmGrad, win=$panelName, pos={24, 376}, size={200, 22}, title="Gradient ", mode=grad, proc=AT_GradientPopup, value="Red (dark to light);Blue (dark to light)"
	Button bRecolor, win=$panelName, pos={24, 406}, size={200, 26}, proc=AT_Button, title="Recolour top graph"
	Button bMakeCT,  win=$panelName, pos={232, 406}, size={132, 26}, proc=AT_Button, title="Make RGB waves"

	// ---------------- appearance ------------------------------------
	GroupBox gbA, win=$panelName, pos={10, 454}, size={368, 214}, title="Appearance   (used by every new graph)"

	SetVariable svFont, win=$panelName, pos={26, 476}, size={165, 20}, title="Font size (pt) ", limits={6, 40, 1}, value=root:Packages:AcademicToolbox:fontSize
	SetVariable svAx,   win=$panelName, pos={205, 476}, size={160, 20}, title="Axis thickness ", limits={0.5, 8, 0.5}, value=root:Packages:AcademicToolbox:axThick
	SetVariable svLine, win=$panelName, pos={26, 502}, size={165, 20}, title="Line width (pt)", limits={0.5, 10, 0.5}, value=root:Packages:AcademicToolbox:lineWidth
	SetVariable svMrk,  win=$panelName, pos={205, 502}, size={160, 20}, title="Marker size    ", limits={1, 20, 1}, value=root:Packages:AcademicToolbox:markerSize

	CheckBox cbFixed, win=$panelName, pos={26, 530}, title="Fixed plot size -- untick to let graphs resize with the window", variable=root:Packages:AcademicToolbox:fixedSize

	SetVariable svW,  win=$panelName, pos={26, 552}, size={165, 20}, title="Plot width (cm)", limits={2, 40, 0.5}, value=root:Packages:AcademicToolbox:widthCM
	SetVariable svH,  win=$panelName, pos={205, 552}, size={160, 20}, title="Plot height (cm)", limits={2, 40, 0.5}, value=root:Packages:AcademicToolbox:heightCM
	SetVariable svWW, win=$panelName, pos={26, 578}, size={165, 20}, title="Window W (pt) ", limits={200, 2000, 20}, value=root:Packages:AcademicToolbox:winW
	SetVariable svWH, win=$panelName, pos={205, 578}, size={160, 20}, title="Window H (pt)  ", limits={150, 2000, 20}, value=root:Packages:AcademicToolbox:winH

	Button bApplyTop, win=$panelName, pos={26, 606}, size={165, 26}, proc=AT_Button, title="Apply to top graph"
	Button bApplyAll, win=$panelName, pos={199, 606}, size={165, 26}, proc=AT_Button, title="Apply to ALL graphs"
	Button bDefault,  win=$panelName, pos={26, 636}, size={165, 26}, proc=AT_Button, title="Restore defaults"
	Button bClose,    win=$panelName, pos={199, 636}, size={165, 26}, proc=AT_Button, title="Close panel"

	return 0
End

Function AT_Button(ba) : ButtonControl
	STRUCT WMButtonAction &ba
	Variable n
	if (ba.eventCode != 2)					// mouse up only
		return 0
	endif

	strswitch (ba.ctrlName)
		// ---- electrical
		case "bLoadE":
			AT_E_LoadFolder()
			break
		case "bFileE":
			AT_E_LoadFiles()
			break
		case "bListE":
			AT_E_ListFiles()
			break
		case "bIt":
			AT_E_PlotTransient()
			break
		case "bVref":
			AT_E_PlotVref()
			break
		case "bIV":
			AT_E_PlotTransfer()
			break
		case "bSS":
			AT_E_PlotSteadyState()
			break
		case "bKillE":
			AT_E_KillAll()
			break

		// ---- UV-vis
		case "bLoadU":
			AT_U_LoadFolder()
			break
		case "bFileU":
			AT_U_LoadFiles()
			break
		case "bListU":
			AT_U_ListFiles()
			break
		case "bCorr":
			AT_U_Correct()
			break
		case "bPlotU":
			AT_U_PlotSpectra()
			break
		case "bKillU":
			AT_U_KillAll()
			break

		// ---- colours
		case "bRecolor":
			ControlInfo/W=$ba.win pmGrad
			n = AT_E_RecolorGradient("", V_Value)			// 1 = red, 2 = blue
			if (n < 0)
				DoAlert 0, "There is no graph window on top."
			else
				Printf "Recoloured %d trace(s).\r", n
			endif
			break
		case "bMakeCT":
			AT_E_MakeColorTables()
			Print "Colour tables written to root:Packages:ColorTables:AcademicToolbox (RedDarkToLight, RedLightToDark, BlueDarkToLight, BlueLightToDark)."
			break

		// ---- appearance
		case "bApplyTop":
			if (AT_E_ApplyLook("", 1) != 0)
				DoAlert 0, "There is no graph window on top."
			endif
			break
		case "bApplyAll":
			n = AT_E_ApplyLookAll()
			Printf "Appearance applied to %d graph(s).\r", n
			break
		case "bDefault":
			AT_E_ResetPrefs()
			break
		case "bClose":
			KillWindow/Z $ba.win
			break
	endswitch
	return 0
End

Menu "Macros"
	"Academic Toolbox - Electrical",/Q,AT_ElectricalPanel()
	"Academic Toolbox - OECT",/Q,AT_OECTPanel()
	SubMenu "Academic Toolbox - Extra tools"
		"Plot existing waves (Id vs time or UV-vis)...",/Q,AT_PlotExisting()
		"Correct spectra from top graph...",/Q,AT_CorrectGraph()
		"Label top graph...",/Q,AT_LabelGraph()
		"Convert XRD 2-theta to q...",/Q,AT_ConvertQ()
		"Stack XRD traces (display only)...",/Q,AT_StackXRD()
	End
End

Function AT_InputUnits()
	AT_E_InitPrefs()
	Variable iUnit=1,tUnit=1
	Prompt iUnit,"Current units in the source files",popup,"A;mA;µA;nA"
	Prompt tUnit,"Time units in the source files",popup,"s;ms;min;h"
	DoPrompt "Electrical input units",iUnit,tUnit
	if(V_flag)
		return -1
	endif
	NVAR isc=root:Packages:AcademicToolbox:currentScale
	NVAR tsc=root:Packages:AcademicToolbox:timeScale
	isc=10^(-3*(iUnit-1))
	tsc=str2num(StringFromList(tUnit-1,"1;0.001;60;3600"))
	return 0
End

Function AT_GradientPopup(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa
	if(pa.eventCode==2)
		NVAR grad=root:Packages:AcademicToolbox:gradient
		grad=pa.popNum
	endif
	return 0
End

Static Function AT_SameGrid(a,b)
	WAVE a,b
	Variable i,n=numpnts(a)
	if(n!=numpnts(b))
		return 0
	endif
	for(i=0;i<n;i+=1)
		if(abs(a[i]-b[i])>1e-6)
			return 0
		endif
	endfor
	return 1
End

Function AT_LabelGraph()
	String gn=WinName(0,1)
	if(strlen(gn)==0)
		DoAlert 0,"Select a graph first."
		return -1
	endif
	Variable kind=1
	Prompt kind,"Labels only (data and units are not converted)",popup,"Time (s) / Id (µA);Vg (V) / Id (µA);Wavelength (nm) / Absorbance;XRD q / Intensity;Time (h) / Conductivity;Time (h) / Relative conductivity"
	DoPrompt "Axis labels",kind
	if(V_flag)
		return -1
	endif
	String xl=StringFromList(kind-1,"Time (s);V\\BG\\M (V);Wavelength (nm);q\\Bz\\M (Å\\S-1\\M);Time (h);Time (h)")
	String yl=StringFromList(kind-1,"I\\BD\\M (µA);I\\BD\\M (µA);Absorbance;Intensity;Conductivity (S cm\\S-1\\M);Relative conductivity")
	AT_E_Style(gn,xl,yl)
	return 0
End

Function AT_PlotExisting()
	String xPath="",yPath=""
	Variable kind=1,append=2
	Prompt kind,"Plot type",popup,"Id vs time;UV-vis absorbance"
	Prompt xPath,"Full path of X wave (e.g. root:time)"
	Prompt yPath,"Full path of Y wave (e.g. root:current)"
	Prompt append,"Append to top graph?",popup,"Yes;No (new graph)"
	DoPrompt "Plot existing waves",kind,xPath,yPath,append
	if(V_flag)
		return -1
	endif
	WAVE/Z xw=$xPath,yw=$yPath
	if(!WaveExists(xw) || !WaveExists(yw))
		DoAlert 0,"Both numeric waves must exist."
		return -1
	endif
	if(WaveDims(xw)!=1 || WaveDims(yw)!=1 || numpnts(xw)!=numpnts(yw) || numpnts(xw)<2)
		DoAlert 0,"Use equal-length, one-dimensional numeric waves with at least two points."
		return -1
	endif
	AT_E_InitPrefs()
	if(kind==1)
		if(AT_InputUnits()!=0)
			return -1
		endif
	endif
	String gn=WinName(0,1)
	if(append!=1 || strlen(gn)==0)
		gn=UniqueName("ATgraph",6,0)
		Display/N=$gn as "Academic plot"
	endif
	AppendToGraph/W=$gn yw vs xw
	String traces=TraceNameList(gn,";",1)
	String tn=StringFromList(ItemsInList(traces)-1,traces)
	if(kind==1)
		NVAR isc=root:Packages:AcademicToolbox:currentScale
		NVAR tsc=root:Packages:AcademicToolbox:timeScale
		ModifyGraph/W=$gn muloffset($tn)={tsc,isc*1e6}
		AT_E_Style(gn,"Time (s)","I\\BD\\M (µA)")
		SetAxis/A/R/W=$gn left
	else
		AT_E_Style(gn,"Wavelength (nm)","Absorbance")
	endif
	AT_E_ApplyLook(gn,1)
	NVAR grad=root:Packages:AcademicToolbox:gradient
	AT_E_RecolorGradient(gn,grad)
	Legend/W=$gn/C/N=ATlegend/F=0/A=RT
	return 0
End

// Import graph XY data into this toolbox before opening its correction dialog.
// Always operates on copies. Scaled Y waves are supported; graph display offsets
// and multipliers are deliberately not baked into the source absorbance data.
Function AT_CorrectGraph()
	String gn=WinName(0,1)
	if(strlen(gn)==0)
		DoAlert 0,"Plot the UV-vis spectra first."
		return -1
	endif
	String tl=TraceNameList(gn,";",1),tn,base
	Variable i,n=ItemsInList(tl),j,k
	if(n==0)
		return -1
	endif
	// Validate every trace before changing the toolbox dataset.
	for(i=0;i<n;i+=1)
		tn=StringFromList(i,tl)
		WAVE yw=TraceNameToWaveRef(gn,tn)
		WAVE/Z xw=XWaveRefFromTrace(gn,tn)
		Duplicate/FREE yw,checkY
		Duplicate/FREE yw,checkX
		if(WaveExists(xw))
			if(numpnts(xw)!=numpnts(yw))
				DoAlert 0,"Each X/Y pair must have equal lengths."
				return -1
			endif
			checkX=xw[p]
		else
			checkX=DimOffset(yw,0)+p*DimDelta(yw,0)
		endif
		if(AT_U_MakeAscending(checkX,checkY)<0)
			DoAlert 0,"Wavelengths must be finite, strictly monotonic, and in nm."
			return -1
		endif
	endfor
	// Append to toolbox Raw; originals remain. Correction rebuilds all Corr waves.
	NewDataFolder/O root:AT_UV
	NewDataFolder/O root:AT_UV:Raw
	NewDataFolder/O root:AT_UV:Corr
	NewDataFolder/O root:AT_UV:Native
	WAVE/Z/T chk=root:AT_UV:BaseName
	if(!WaveExists(chk))
		Make/O/T/N=0 root:AT_UV:FileName,root:AT_UV:BaseName,root:AT_UV:Category,root:AT_UV:Sample
	endif
	WAVE/T bnw=root:AT_UV:BaseName,fnw=root:AT_UV:FileName,ctw=root:AT_UV:Category,spw=root:AT_UV:Sample
	for(i=0;i<n;i+=1)
		tn=StringFromList(i,tl)
		WAVE yw=TraceNameToWaveRef(gn,tn)
		WAVE/Z xw=XWaveRefFromTrace(gn,tn)
		Duplicate/FREE yw,xx
		Duplicate/FREE yw,yy
		if(WaveExists(xw))
			xx=xw[p]
		else
			xx=DimOffset(yw,0)+p*DimDelta(yw,0)
		endif
		AT_U_MakeAscending(xx,yy)
		base=AT_U_UniqueBase(CleanupName(NameOfWave(yw),0))
		Duplicate/O xx,root:AT_UV:Native:$(base+"_nm")
		Duplicate/O yy,root:AT_UV:Native:$(base+"_Abs")
		WAVE/Z master=root:AT_UV:Wavelength
		if(!WaveExists(master))
			Duplicate/O xx,root:AT_UV:Wavelength
		endif
		WAVE master=root:AT_UV:Wavelength
		Make/O/D/N=(numpnts(master)) root:AT_UV:Raw:$(base+"_Abs")
		WAVE dst=root:AT_UV:Raw:$(base+"_Abs")
		dst=(master[p]<xx[0] || master[p]>xx[numpnts(xx)-1]) ? NaN : interp(master[p],xx,yy)
		j=numpnts(bnw)
		Redimension/N=(j+1) bnw,fnw,ctw,spw
		bnw[j]=base
		fnw[j]=GetWavesDataFolder(yw,2)
		ctw[j]="GraphImport"
		spw[j]=NameOfWave(yw)
	endfor
	Print "Copied graph data into toolbox. Correction applies to all toolbox spectra. Choose the reference in the next dialog."
	return AT_U_Correct()
End

Function AT_ConvertQ()
	String path=""
	Variable lambda=1.5418
	Prompt path,"Full path of 2-theta wave (degrees)"
	Prompt lambda,"X-ray wavelength (angstrom)"
	DoPrompt "Convert 2-theta to q",path,lambda
	if(V_flag)
		return -1
	endif
	WAVE/Z deg=$path
	if(!WaveExists(deg) || numtype(lambda)!=0 || lambda<=0)
		DoAlert 0,"Select an existing numeric wave and positive wavelength."
		return -1
	endif
	String nm=UniqueName("AT_qz",1,0)
	Duplicate deg,$nm
	WAVE qz=$nm
	qz=4*pi*sin(deg[p]*pi/360)/lambda
	SetScale d,0,0,"1/Å",qz
	Print "Created "+GetWavesDataFolder(qz,2)
	return 0
End

Function AT_StackXRD()
	String gn=WinName(0,1)
	if(strlen(gn)==0)
		return -1
	endif
	Variable factor=10
	Prompt factor,"Multiplicative spacing per trace (>1); raw waves stay unchanged"
	DoPrompt "Stack XRD traces",factor
	if(V_flag)
		return -1
	endif
	if(numtype(factor)!=0 || factor<=1)
		return -1
	endif
	String tl=TraceNameList(gn,";",1),tn
	Variable i
	for(i=0;i<ItemsInList(tl);i+=1)
		tn=StringFromList(i,tl)
		ModifyGraph/W=$gn muloffset($tn)={1,factor^i}
	endfor
	ModifyGraph/W=$gn log(left)=1
	AT_E_Style(gn,"q\\Bz\\M (Å\\S-1\\M)","Intensity")
	return 0
End

// Run in a fresh experiment before loading research data.
// Creates synthetic demo waves/graphs, and leaves them available for inspection.
Function AT_SelfTest()
	if(DataFolderExists("root:AT_UV") || DataFolderExists("root:AT_Elec"))
		DoAlert 0,"Run AT_SelfTest in a fresh experiment without toolbox data."
		return -1
	endif
	Variable r,g,b,which,i,n,previous,lum
	for(which=1;which<=2;which+=1)
		for(n=1;n<=25;n+=1)
			previous=-1
			for(i=0;i<n;i+=1)
				AT_E_GradColor(which,i,n,r,g,b)
				lum=0.2126*r+0.7152*g+0.0722*b
				if(lum<=previous || min(r,min(g,b))<0 || max(r,max(g,b))>65535)
					Abort "FAIL: gradient order/range"
				endif
				previous=lum
			endfor
		endfor
	endfor
	Make/FREE/D/N=3 gridA={1,2,3},gridB={1,2.5,3},vals={3,2,1}
	if(AT_SameGrid(gridA,gridB)!=0)
		Abort "FAIL: interior grid mismatch"
	endif
	Make/FREE/D/N=3 descending={3,2,1}
	AT_U_MakeAscending(descending,vals)
	if(descending[0]!=1 || vals[0]!=1)
		Abort "FAIL: descending XY alignment"
	endif
	Make/FREE/D/N=3 repeated={1,1,2}
	if(AT_U_MakeAscending(repeated,vals)!=-1)
		Abort "FAIL: duplicate wavelength accepted"
	endif
	AT_E_InitPrefs()
	NewDataFolder/O root:AT_UV
	NewDataFolder/O root:AT_UV:Raw
	NewDataFolder/O root:AT_UV:Corr
	Make/O/D/N=1201 root:AT_UV:Wavelength
	WAVE wl=root:AT_UV:Wavelength
	wl=400+p
	Make/O/T/N=2 root:AT_UV:BaseName={"testA","testB"}
	Make/O/T/N=2 root:AT_UV:Category={"GroupA","GroupB"}
	Make/O/T/N=2 root:AT_UV:Sample={"s1","s2"}
	Make/O/T/N=2 root:AT_UV:FileName={"Synthetic A","Synthetic B"}
	Make/O/D/N=1201 root:AT_UV:Raw:testA_Abs,root:AT_UV:Raw:testB_Abs
	WAVE ya=root:AT_UV:Raw:testA_Abs,yb=root:AT_UV:Raw:testB_Abs
	ya=0.1+0.0001*(wl[p]-400)+(wl[p]>850)*0.3
	yb=0.2+0.0002*(wl[p]-400)+(wl[p]>850)*0.5
	Duplicate/FREE ya,rawCopy
	AT_U_CorrectCore(1200,1300,1,850,851,5,2,1,2,2)
	WAVE ca=root:AT_UV:Corr:testA_Absc,cb=root:AT_UV:Corr:testB_Absc
	if(abs(ca[800])>1e-10 || abs(cb[800])>1e-10 || abs(ca[451]-ca[450]-0.0001)>1e-9)
		Abort "FAIL: seam correction or common anchor"
	endif
	Duplicate/FREE ca,firstResult
	AT_U_CorrectCore(1200,1300,1,850,851,5,2,1,2,2)
	Make/FREE/D/N=1201 err=abs(ca[p]-firstResult[p])+abs(ya[p]-rawCopy[p])
	WaveStats/Q err
	if(V_max>1e-12)
		Abort "FAIL: repeat correction changed result or raw data"
	endif
	String gn=UniqueName("ATdemoUV",6,0)
	Display/N=$gn ca,cb vs wl as "Synthetic UV-vis: corrected, blue gradient"
	AT_E_Style(gn,"Wavelength (nm)","Absorbance")
	AT_E_ApplyLook(gn,1)
	AT_E_RecolorGradient(gn,2)
	NewDataFolder/O root:AT_Elec
	NewDataFolder/O root:AT_Elec:Data
	Make/O/T/N=2 root:AT_Elec:BaseName={"testA","testB"}
	Make/O/T/N=2 root:AT_Elec:Category={"GroupA","GroupB"}
	Make/O/T/N=2 root:AT_Elec:Sample={"s1","s2"}
	Make/O/T/N=2 root:AT_Elec:FileName={"Synthetic A","Synthetic B"}
	Make/O/D/N=101 root:AT_Elec:Data:testA_Time,root:AT_Elec:Data:testA_DrainI,root:AT_Elec:Data:testA_GateV
	WAVE tt=root:AT_Elec:Data:testA_Time,ii=root:AT_Elec:Data:testA_DrainI,vg=root:AT_Elec:Data:testA_GateV
	tt=p
	ii=-2e-6*(1-exp(-p/20))
	vg=-0.5
	Duplicate/O tt,root:AT_Elec:Data:testB_Time
	Duplicate/O ii,root:AT_Elec:Data:testB_DrainI
	Duplicate/O vg,root:AT_Elec:Data:testB_GateV
	WAVE ib=root:AT_Elec:Data:testB_DrainI
	ib*=2
	Make/FREE/D/N=0 holdV,holdI
	AT_E_HarvestPoints(ii,vg,10,1,holdV,holdI)
	if(numpnts(holdV)!=1 || abs(holdV[0]+0.5)>1e-12)
		Abort "FAIL: steady-state harvesting"
	endif
	gn=UniqueName("ATdemoId",6,0)
	Display/N=$gn ii,ib vs tt as "Synthetic Id: µA versus seconds, red gradient"
	ModifyGraph/W=$gn muloffset={1,1e6}
	AT_E_Style(gn,"Time (s)","I\\BD\\M (µA)")
	AT_E_ApplyLook(gn,1)
	AT_E_RecolorGradient(gn,1)
	AT_Panel()
	Print "PASS: gradients 1-25 traces; grid validation; descending XY; seam/anchor; repeatability; raw preservation; steady-state; demo styling."
	return 0
End

Function AT_TestLoaders()
	// Requires AT_SelfTest demo data; uses unique names and never clears data.
	WAVE/Z/T bnw=root:AT_Elec:BaseName
	if(!WaveExists(bnw))
		return -1
	endif
	NewPath/O/Q AT_Epath "Macintosh HD:Applications:Igor Pro 8 Folder:User Procedures:validation:"
	NewPath/O/Q AT_Upath "Macintosh HD:Applications:Igor Pro 8 Folder:User Procedures:validation:"
	NVAR isc=root:Packages:AcademicToolbox:currentScale
	NVAR tsc=root:Packages:AcademicToolbox:timeScale
	Variable oldI=isc,oldT=tsc
	isc=1e-6
	tsc=0.001
	Variable rc=AT_E_Ingest("s1_Electrical.txt","_",1,1,0,AT_E_EncCode(2))
	isc=oldI
	tsc=oldT
	if(rc==0)
		Abort "FAIL: electrical import"
	endif
	String base=bnw[numpnts(bnw)-1]
	WAVE ii=root:AT_Elec:Data:$(base+"_DrainI"),tt=root:AT_Elec:Data:$(base+"_Time")
	if(abs(ii[0]+2e-6)>1e-12 || tt[1]!=1)
		Abort "FAIL: source µA/ms conversion"
	endif
	AT_E_Ingest("s2_NoTime.txt","_",1,1,0,AT_E_EncCode(2))
	base=bnw[numpnts(bnw)-1]
	if(exists("root:AT_Elec:Data:"+base+"_Time"))
		Abort "FAIL: missing time fabricated"
	endif
	Variable regridded=0
	rc=AT_U_Ingest("s3_UV.txt","_",1,1,1,0,AT_E_EncCode(2),regridded)
	if(rc==0)
		Abort "FAIL: JASCO import"
	endif
	WAVE/T ub=root:AT_UV:BaseName
	base=ub[numpnts(ub)-1]
	WAVE raw=root:AT_UV:Raw:$(base+"_Abs")
	if(abs(raw[0]-0.1)>1e-12 || abs(raw[600]-0.2)>1e-12)
		Abort "FAIL: descending JASCO regridding"
	endif
	rc=AT_U_Ingest("s4_UVplain.txt","_",1,1,2,0,AT_E_EncCode(2),regridded)
	if(rc==0 || regridded!=2)
		Abort "FAIL: plain text import"
	endif
	Print "PASS: shared folder/single-file import core; electrical µA/ms units; missing time; JASCO header/footer; descending/regridded UV; plain text UV."
	return 0
End

Static Function/S AT_FileList(pathName,extensions)
	String pathName,extensions
	String result="",fn,ext
	Variable i,j
	for(j=0;j<ItemsInList(extensions);j+=1)
		ext=StringFromList(j,extensions)
		i=0
		do
			fn=IndexedFile($pathName,i,ext)
			if(strlen(fn)==0)
				break
			endif
			if(WhichListItem(fn,result)<0)
				result+=fn+";"
			endif
			i+=1
		while(1)
	endfor
	return SortList(result,";",16)
End

Static Function/S AT_SSName(base)
	String base
	base=base[0,220]
	String nm=base
	Variable i=1
	do
		if(!exists("root:AT_Elec:SS:"+nm+"_Id"))
			return nm
		endif
		nm=base+"_"+num2istr(i)
		i+=1
	while(1)
End

// Scriptable single-file entry point: kind=1 electrical, kind=2 UV-vis.
// Uses current input scales (default A/s); set them via AT_InputUnits first
// for files with other units. UV fmt=1 JASCO, fmt=2 plain two-column.
Function AT_LoadPath(fullPath,kind,[fmt,skipLines,encoding])
	String fullPath
	Variable kind,fmt,skipLines,encoding
	if(ParamIsDefault(fmt))
		fmt=1
	endif
	if(ParamIsDefault(skipLines))
		skipLines=0
	endif
	if(ParamIsDefault(encoding))
		encoding=TextEncodingCode("Windows-1252")
	endif
	AT_E_InitPrefs()
	if(cmpstr(IgorInfo(2),"Macintosh")==0 && cmpstr(fullPath[0],"/")==0)
		fullPath=ParseFilePath(10,fullPath,"*",0,0)
		if(strlen(fullPath)==0)
			return 0
		endif
	endif
	String sep=AT_E_PathSep(fullPath)
	String dir=ParseFilePath(1,fullPath,sep,1,0)
	String fn=ParseFilePath(0,fullPath,sep,1,0)
	Variable regrid=0
	if(kind==1)
		NewPath/O/Q/Z AT_Epath dir
		if(V_flag!=0)
			return 0
		endif
		NewDataFolder/O root:AT_Elec
		NewDataFolder/O root:AT_Elec:Data
		WAVE/Z/T ec=root:AT_Elec:FileName
		if(!WaveExists(ec))
			Make/O/T/N=0 root:AT_Elec:FileName,root:AT_Elec:BaseName,root:AT_Elec:Category,root:AT_Elec:Sample
		endif
		return AT_E_Ingest(fn,"auto",3,1,skipLines,encoding)
	elseif(kind==2)
		NewPath/O/Q/Z AT_Upath dir
		if(V_flag!=0)
			return 0
		endif
		NewDataFolder/O root:AT_UV
		NewDataFolder/O root:AT_UV:Raw
		NewDataFolder/O root:AT_UV:Corr
		WAVE/Z/T uc=root:AT_UV:FileName
		if(!WaveExists(uc))
			Make/O/T/N=0 root:AT_UV:FileName,root:AT_UV:BaseName,root:AT_UV:Category,root:AT_UV:Sample
		endif
		return AT_U_Ingest(fn,"auto",3,1,fmt,skipLines,encoding,regrid)
	endif
	return 0
End

// Regression check: folder discovery only; imports no experimental data.
Function AT_TestFolderIndex()
	NewPath/O/Q AT_IndexTest "Macintosh HD:Applications:Igor Pro 8 Folder:User Procedures:validation:"
	String files=AT_FileList("AT_IndexTest",".txt;.txt")
	String expected="s1_Electrical.txt;s2_NoTime.txt;s3_UV.txt;s4_UVplain.txt;"
	Variable i
	for(i=0;i<ItemsInList(expected);i+=1)
		if(WhichListItem(StringFromList(i,expected),files)<0)
			Abort "FAIL: folder discovery missed "+StringFromList(i,expected)
		endif
	endfor
	if(ItemsInList(files)!=4)
		Abort "FAIL: folder discovery count/deduplication"
	endif
	Print "PASS: symbolic folder lookup, .txt filtering, duplicate extension removal: "+files
	KillPath/Z AT_IndexTest
	return 0
End
