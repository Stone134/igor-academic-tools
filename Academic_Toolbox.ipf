#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma IgorVersion=8.00

// Academic Toolbox, simplified 2026-10-16. Igor Pro 8+.
// Macros: Electrical / OECT and UV-vis. AT_Panel() opens Electrical / OECT.
// New plots use Thesis2, optional free sizing, and plain numeric tick labels.
// Current correction omits points with NaN in COPIES; raw data and X alignment stay intact.
// Exact palette swatches are available from Curve color in either panel.
Constant kAT_E_NPAL=8
StrConstant ksAT_E_PAL="0,114,178;213,94,0;0,158,115;204,121,167;230,159,0;86,180,233;140,86,75;90,90,90"

Function AT_E_LoadFolder()

	String ext = ".txt"
	Variable headerLine = 0
	Variable encSel = 1
	String sep = "space"
	Variable nCat = 1
	Variable nameMode = 1
	Variable clearFirst = 2

	Prompt ext,        "Extensions (.txt;.csv; ???? = all)"
	Prompt headerLine, "0-based line holding the column names"
	Prompt encSel,     "Text encoding of the files", popup, "Windows-1252 (Latin 1);UTF-8;MacRoman;let Igor decide"
	Prompt clearFirst, "Clear data already loaded?", popup, "Yes;No"
	DoPrompt "Load electrical raw data", ext, headerLine, encSel, clearFirst
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
		Printf "  ! %d file(s) had no s# token; sample set to \"unknown\".\r", nNoSample
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
    WAVE/T fnw=root:AT_Elec:FileName,bnw=root:AT_Elec:BaseName
    WAVE/T ctw=root:AT_Elec:Category,spw=root:AT_Elec:Sample
    String stem=fn,samp="",rest,base,cat="All"
    // Strip only the final extension. Preserve decimals and punctuation in sections.
    Variable dot=strsearch(fn,".",inf,1)
    stem=fn
    if(dot>0)
        stem=fn[0,dot-1]
    endif
    Variable pos=AT_E_FindSample(stem,samp)
    rest=stem
    if(pos>=0)
        rest=samp+stem[pos+strlen(samp),strlen(stem)-1]
        String after=TrimString(stem[pos+strlen(samp),strlen(stem)-1])
        if(strlen(after)>0)
            cat=StringFromList(0,after," ")
            // Read older underscore-delimited filenames as well.
            if(cmpstr(after[0],"_")==0)
                cat=StringFromList(0,after[1,strlen(after)-1],"_")
            endif
        endif
    else
        samp="unknown"
        String first=StringFromList(0,stem," ")
        if(GrepString(first,"^[Bb][0-9]+$"))
            rest=TrimString(stem[strlen(first),strlen(stem)-1])
        endif
    endif
    base=AT_E_UniqueBase(CleanupName(ReplaceString(" ",rest,"_"),1,220))
    if(AT_E_LoadOne(fn,base,headerLine,enc)!=0)
        Print "Skipped (check header row and file access): "+fn
        return 0
    endif
    Variable n=numpnts(fnw)
    Redimension/N=(n+1) fnw,bnw,ctw,spw
    fnw[n]=fn; bnw[n]=base; ctw[n]=cat; spw[n]=samp
    String df=GetDataFolder(1),nm
    SetDataFolder root:AT_Elec:Data
    String wl=WaveList("*",";","")
    Variable j
    for(j=0;j<ItemsInList(wl);j+=1)
        nm=StringFromList(j,wl)
        if(stringmatch(nm,"*_"+base))
            Note $nm,"ATSample="+samp+";ATCategory="+cat+";ATBase="+base+";ATFile="+fn+";"
        endif
    endfor
    SetDataFolder df
    return (pos>=0) ? 1 : 2
End

// Detect path format, preserving literal / characters in Mac HFS filenames.
// A POSIX colon in a filename becomes / in HFS; only a leading / means POSIX.
Static Function/S AT_E_PathSep(fullPath)
	String fullPath
	if (cmpstr(fullPath[0], "/") == 0)
		return "/"
	endif
	if (cmpstr(IgorInfo(2),"Macintosh")==0)
		return ":"
	endif
	if (strsearch(fullPath, "\\", 0) >= 0)
		return "\\"
	endif
	return ":"
End

//  Load one or several individually chosen files instead of a folder
Function AT_E_LoadFiles()

	Variable headerLine = 0
	Variable encSel = 1
	String sep = "space"
	Variable nCat = 1
	Variable nameMode = 1
	Variable clearFirst = 2

	Prompt headerLine, "0-based line holding the column names"
	Prompt encSel,     "Text encoding of the files", popup, "Windows-1252 (Latin 1);UTF-8;MacRoman;let Igor decide"
	Prompt clearFirst, "Clear data already loaded?", popup, "Yes;No"
	DoPrompt "Load individual electrical files", headerLine, encSel, clearFirst
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
		Printf "  ! %d file(s) had no s# token; sample set to \"unknown\".\r", nNoSample
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
	String nIG = AT_U_FindCol(names, "gatei;gatecurrent;ig")
	String nDV = AT_U_FindCol(names, "drainv;drainvoltage;vd")
	String nT = AT_E_FindCol(names, "time")
	String nR = AT_U_FindCol(names, "vref;referencevoltage;referenceelectrodevoltage")

	NewDataFolder/O root:AT_Elec:Native
	NewDataFolder/O root:AT_Elec:Native:$base
	Variable colIndex
	String colName, destName
	for(colIndex=0;colIndex<ItemsInList(names);colIndex+=1)
		colName=StringFromList(colIndex,names)
		// Duplicate by name also preserves text columns loaded with /K=0.
		Duplicate/O $colName,$("root:AT_Elec:Native:"+PossiblyQuoteName(base)+":"+PossiblyQuoteName(colName))
		destName=CleanupName(colName+"_"+base,1,255)
		Duplicate/O $colName,$("root:AT_Elec:Data:"+PossiblyQuoteName(destName))
	endfor
	// Recognized aliases get canonical names for the plotting routines.
	AT_E_StoreCanonical(nI,base,"DrainI","A")
	AT_E_StoreCanonical(nG,base,"GateV","V")
	AT_E_StoreCanonical(nIG,base,"GateI","A")
	AT_E_StoreCanonical(nDV,base,"DrainV","V")
	AT_E_StoreCanonical(nT,base,"Time","s")
	AT_E_StoreCanonical(nR,base,"Vref","V")

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

	String catFilter = "*"
	Variable pickMode = 2
	NVAR savedGradient=root:Packages:AcademicToolbox:gradient
	Variable colorMode = savedGradient
	Variable zeroT = 1
	Variable showLeg = 1
	Variable revY=1

	Prompt catFilter,  "Category filter ( * = all )"
	Prompt pickMode,   "Data selection", popup, "Everything matching the filter;Choose from a list..."
	Prompt colorMode,  "Colouring", popup, "Red (dark to light);Blue (dark to light);Categories blue & red;Distinct category colors"
	Prompt zeroT,      "Shift every trace so t starts at 0?", popup, "Yes;No"
	Prompt showLeg,    "Legend", popup, "Show;Hide"
	Prompt revY,"Reverse current axis?",popup,"Yes;No"
	DoPrompt "Drain current vs time", catFilter, pickMode, colorMode, zeroT, showLeg, revY
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
	Display/N=$gName as "Drain current vs time"

	Variable nPlot=0
	Variable i, ymin = inf, ymax = -inf, xmin = inf, xmax = -inf, t0
	String tn, leg = "", lastCat = ""

	for (i = 0; i < m; i += 1)
		WAVE/Z wy = $AT_E_CurrentPath(bnw[idx[i]],"DrainI")
		WAVE/Z wx = $AT_E_ColumnPath(bnw[idx[i]],"Time")
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
			if (colorMode == 4)
				if (cmpstr(ctw[idx[i]], lastCat) != 0 && siW[i] == 0)
					leg += "\\s(" + PossiblyQuoteName(tn) + ") " + ctw[idx[i]] + "\r"
					lastCat = ctw[idx[i]]
				endif
			else
				leg += "\\s(" + PossiblyQuoteName(tn) + ") " + bnw[idx[i]] + "\r"
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
	AT_RecolorGraph(gName,colorMode)
	AT_E_PutLegend(gName, leg)

	return 0
End

// Reference-electrode voltage: source and working voltage units are volts.
// Select a plotted toolbox Id trace, keeping its exact displayed time alignment.
Function AT_E_AddVg()
	return AT_E_AddVoltage(1)
End

Function AT_E_AddVref()
	return AT_E_AddVoltage(2)
End

// Optional arguments allow repeatable script-based validation without dialogs.
Function AT_E_AddVoltage(kind,[gName,currentTrace])
	Variable kind
	String gName,currentTrace
	if(kind!=1 && kind!=2)
		return -1
	endif
	if(ParamIsDefault(gName) || strlen(gName)==0)
		gName=WinName(0,1)
	endif
	if(strlen(gName)==0 || WinType(gName)!=1)
		DoAlert 0,"Select an Id vs time graph first."
		return -1
	endif
	String tl=TraceNameList(gName,";",1), candidates="", tn, info
	Variable i
	for(i=0;i<ItemsInList(tl);i+=1)
		tn=StringFromList(i,tl)
		WAVE/Z iy=TraceNameToWaveRef(gName,tn), ix=XWaveRefFromTrace(gName,tn)
		if(!WaveExists(iy) || !WaveExists(ix))
			continue
		endif
		info=TraceInfo(gName,tn,0)
		if((cmpstr(GetWavesDataFolder(iy,1),"root:AT_Elec:Data:")!=0 && cmpstr(GetWavesDataFolder(iy,1),"root:AT_Elec:Corr:")!=0) || strlen(AT_E_ColumnBase(NameOfWave(iy),"DrainI"))==0)
			continue
		endif
		String ibase=AT_E_ColumnBase(NameOfWave(iy),"DrainI")
		if(cmpstr(GetWavesDataFolder(ix,2),AT_E_ColumnPath(ibase,"Time"))!=0)
			continue
		endif
		if(cmpstr(StringByKey("YAXIS",info),"left")==0 && cmpstr(StringByKey("XAXIS",info),"bottom")==0)
			candidates+=tn+";"
		endif
	endfor
	if(ItemsInList(candidates)==0)
		DoAlert 0,"This graph has no toolbox Id vs time trace. Plot Id vs time first."
		return -1
	endif
	if(ParamIsDefault(currentTrace))
		Variable choice=1
		Prompt choice,"Sample (Id trace already in this graph)",popup,candidates
		DoPrompt "Add grey voltage vs time on right axis",choice
		if(V_flag)
			return -1
		endif
		currentTrace=StringFromList(choice-1,candidates)
	endif
	if(WhichListItem(currentTrace,candidates)<0)
		return -1
	endif
	WAVE iy=TraceNameToWaveRef(gName,currentTrace), wx=XWaveRefFromTrace(gName,currentTrace)
	String base=AT_E_ColumnBase(NameOfWave(iy),"DrainI")
	String suffix="_GateV", overlay="ATvgOverlay"
	if(kind==2)
		suffix="_Vref"
		overlay="ATvrefOverlay"
	endif
	WAVE/Z wy=$AT_E_ColumnPath(base,suffix[1,strlen(suffix)-1])
	if(!WaveExists(wy))
		DoAlert 0,"The selected sample has no "+suffix[1,strlen(suffix)-1]+" column."
		return -1
	endif
	if(numpnts(wy)==0 || numpnts(wy)!=numpnts(wx))
		DoAlert 0,"Voltage and Time must be nonempty and have equal lengths."
		return -1
	endif
	WaveStats/Q/M=1 wy
	if(numtype(V_min)!=0 || numtype(V_max)!=0)
		DoAlert 0,"The selected voltage has no finite values."
		return -1
	endif
	// Do not mix this voltage overlay with unrelated pre-existing right-axis data.
	for(i=0;i<ItemsInList(tl);i+=1)
		tn=StringFromList(i,tl)
		info=TraceInfo(gName,tn,0)
		if(cmpstr(StringByKey("YAXIS",info),"right")==0)
			WAVE/Z rightWave=TraceNameToWaveRef(gName,tn)
			if(!WaveExists(rightWave))
				return -1
			endif
			if(cmpstr(GetWavesDataFolder(rightWave,1),"root:AT_Elec:Data:")!=0 || (!(strlen(AT_E_ColumnBase(NameOfWave(rightWave),"GateV"))>0) && !(strlen(AT_E_ColumnBase(NameOfWave(rightWave),"Vref"))>0)))
				DoAlert 0,"The right axis contains data other than toolbox GateV/Vref. Use a graph with a free or voltage-only right axis."
				return -1
			endif
		endif
	endfor
	info=TraceInfo(gName,currentTrace,0)
	Variable xoff=0,yoff=0,xmul=1,ymul=1
	String pair=StringByKey("offset(x)",info,"=")
	if(strlen(pair)>0)
		sscanf pair,"{%g,%g}",xoff,yoff
	endif
	pair=StringByKey("muloffset(x)",info,"=")
	if(strlen(pair)>0)
		sscanf pair,"{%g,%g}",xmul,ymul
	endif
	if(xmul==0)
		xmul=1
	endif
	if(WhichListItem(overlay,tl)>=0)
		RemoveFromGraph/W=$gName $overlay
	endif
	AppendToGraph/W=$gName/R wy/TN=$overlay vs wx
	AT_E_InitPrefs()
	ModifyGraph/W=$gName rgb($overlay)=(32768,32768,32768)
	ModifyGraph/W=$gName offset($overlay)={xoff,0}, muloffset($overlay)={xmul,1}
	ModifyGraph/W=$gName lstyle($overlay)=2*(kind==2)
	AT_E_ApplyLook(gName,0)
	SetAxis/W=$gName/A/R right
	Label/W=$gName bottom "Time (s)"
	Label/W=$gName left "\\f02I\\BD\\M\\f00 (µA)"
	tl=TraceNameList(gName,";",1)
	Variable hasG=0,hasR=0
	for(i=0;i<ItemsInList(tl);i+=1)
		tn=StringFromList(i,tl)
		info=TraceInfo(gName,tn,0)
		if(cmpstr(StringByKey("YAXIS",info),"right")==0)
			WAVE rvoltage=TraceNameToWaveRef(gName,tn)
			hasG=hasG || (strlen(AT_E_ColumnBase(NameOfWave(rvoltage),"GateV"))>0)
			hasR=hasR || (strlen(AT_E_ColumnBase(NameOfWave(rvoltage),"Vref"))>0)
		endif
	endfor
	String rightLabel="\\f02V\\BG\\M\\f00 (V)", key=""
	if(hasR)
		rightLabel="\\f02V\\Bref\\M\\f00 (V)"
	endif
	if(hasG && hasR)
		rightLabel="\\f02V\\BG\\M\\f00, \\f02V\\Bref\\M\\f00 (V)"
	endif
	Label/W=$gName right rightLabel
	key=AT_LegendText(gName,1)
	Legend/W=$gName/C/N=ATvoltageLegend/F=0/A=RB RemoveEnding(key,"\r")
	return 0
End

Function AT_E_PlotVref()

	WAVE/Z/T chk = root:AT_Elec:BaseName
	if (!WaveExists(chk))
		DoAlert 0, "No data. Run \"Load electrical folder\" first."
		return -1
	endif

	AT_E_InitPrefs()

	String catFilter = "*"
	Variable pickMode = 2
	NVAR savedGradient=root:Packages:AcademicToolbox:gradient
	Variable colorMode = savedGradient
	Variable zeroT = 1
	Variable showLeg = 1
	Variable revY=1

	Prompt catFilter,  "Category filter ( * = all )"
	Prompt pickMode,   "Data selection", popup, "Everything matching the filter;Choose from a list..."
	Prompt colorMode,  "Colouring", popup, "Red (dark to light);Blue (dark to light);Categories blue & red;Distinct category colors"
	Prompt zeroT,      "Shift every trace so t starts at 0?", popup, "Yes;No"
	Prompt showLeg,    "Legend", popup, "Show;Hide"
	Prompt revY,"Reverse Vref axis?",popup,"Yes;No"
	DoPrompt "Reference-electrode voltage vs time", catFilter, pickMode, colorMode, zeroT, showLeg, revY
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
	Display/N=$gName as "Reference-electrode voltage vs time"

	Variable nPlot=0
	Variable i, ymin = inf, ymax = -inf, xmin = inf, xmax = -inf, t0
	String tn, leg = "", lastCat = ""

	for (i = 0; i < m; i += 1)
		WAVE/Z wy = $AT_E_ColumnPath(bnw[idx[i]],"Vref")
		WAVE/Z wx = $AT_E_ColumnPath(bnw[idx[i]],"Time")
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
			if (colorMode == 4)
				if (cmpstr(ctw[idx[i]], lastCat) != 0 && siW[i] == 0)
					leg += "\\s(" + PossiblyQuoteName(tn) + ") " + ctw[idx[i]] + "\r"
					lastCat = ctw[idx[i]]
				endif
			else
				leg += "\\s(" + PossiblyQuoteName(tn) + ") " + bnw[idx[i]] + "\r"
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
	AT_RecolorGraph(gName,colorMode)
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

	String catFilter = "*"
	Variable pickMode = 2
	NVAR savedGradient=root:Packages:AcademicToolbox:gradient
	Variable colorMode = savedGradient
	Variable showLeg = 1

	Prompt catFilter, "Category filter ( * = all )"
	Prompt pickMode,   "Data selection", popup, "Everything matching the filter;Choose from a list..."
	Prompt colorMode, "Colouring", popup, "Red (dark to light);Blue (dark to light);Categories blue & red;Distinct category colors"
	Prompt showLeg,   "Legend", popup, "Show;Hide"
	DoPrompt "Drain current vs gate voltage", catFilter, pickMode, colorMode, showLeg
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
	Display/N=$gName as "Transfer curves"

	Variable i, nPlot = 0, ymin = inf, ymax = -inf, xmin = inf, xmax = -inf
	String tn, leg = "", lastCat = ""

	for (i = 0; i < m; i += 1)
		WAVE/Z wy = $AT_E_CurrentPath(bnw[idx[i]],"DrainI")
		WAVE/Z wx = $AT_E_ColumnPath(bnw[idx[i]],"GateV")
		if (!WaveExists(wx) || !WaveExists(wy))
			continue									// no gate column in this file
		endif
		AppendToGraph/W=$gName wy vs wx
		tn = NameOfWave(wy)
		nPlot += 1

		ModifyGraph/W=$gName muloffset($tn) = {0, 1e6}

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
			if (colorMode == 4)
				if (cmpstr(ctw[idx[i]], lastCat) != 0 && siW[i] == 0)
					leg += "\\s(" + PossiblyQuoteName(tn) + ") " + ctw[idx[i]] + "\r"
					lastCat = ctw[idx[i]]
				endif
			else
				leg += "\\s(" + PossiblyQuoteName(tn) + ") " + bnw[idx[i]] + "\r"
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
	AT_RecolorGraph(gName,colorMode)
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

	String catFilter = "*"
	Variable pickMode = 2
	Variable ssMode = 1
	Variable avgPts = 10
	NVAR savedGradient=root:Packages:AcademicToolbox:gradient
	Variable colorMode = savedGradient
	Variable revX = 1
	Variable revY = 1

	Prompt catFilter, "Category filter ( * = all )"
	Prompt pickMode,   "Data selection", popup, "Everything matching the filter;Choose from a list..."
	Prompt ssMode,    "Steady-state point taken", popup, "at the end of each file;at the end of every Vg plateau"
	Prompt avgPts,    "Average the last n points of each hold"
	Prompt colorMode, "Colouring", popup, "Red (dark to light);Blue (dark to light);Categories blue & red;Distinct category colors"
	Prompt revX,      "Reverse the Vg axis?", popup, "Yes;No"
	Prompt revY,      "Reverse the Id axis?", popup, "Yes;No"
	DoPrompt "Steady-state current vs gate voltage", catFilter, pickMode, ssMode, avgPts, colorMode, revX, revY
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
			WAVE/Z wI = $AT_E_CurrentPath(bnw[i],"DrainI")
			WAVE/Z wG = $AT_E_ColumnPath(bnw[i],"GateV")
			if (!WaveExists(wI) || !WaveExists(wG))
				continue
			endif
			AT_E_HarvestPoints(wI, wG, avgPts, ssMode, vg, id)
		endfor
		Note id,"ATCategory="+cat+";ATSample="+samp+";"
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
	Display/N=$gName as "Steady-state current vs gate voltage"

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

		ModifyGraph/W=$gName muloffset($tn) = {0, 1e6}

		Variable r, g, b
		AT_E_TraceColor(colorMode, ciW[j], siW[j], nsW[j], j, r, g, b)
		ModifyGraph/W=$gName rgb($tn) = (r, g, b)

		WaveStats/Q/M=1 id
		ymin = min(ymin, V_min * 1e6)
		ymax = max(ymax, V_max * 1e6)
		WaveStats/Q/M=1 vg
		xmin = min(xmin, V_min)
		xmax = max(xmax, V_max)

		if (colorMode == 4)
			if (cmpstr(catW[j], lastCat) != 0)
				leg += "\\s(" + PossiblyQuoteName(tn) + ") " + catW[j] + "\r"
				lastCat = catW[j]
			endif
		else
			leg += "\\s(" + PossiblyQuoteName(tn) + ") " + sampW[j] + "\r"
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
	AT_RecolorGraph(gName,colorMode)
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

//  Find "s" followed by one or more digits ANYWHERE in the file name --
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
		for (d = i + 1; d < n; d += 1)
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
				continue								// s6x: not a sample
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
		if (!exists(AT_E_ColumnPath(b,"DrainI")) && !DataFolderExists("root:AT_Elec:Native:"+PossiblyQuoteName(b)))
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
	r = round((r1 + (r2 - r1) * t) * 257)
	g = round((g1 + (g2 - g1) * t) * 257)
	b = round((b1 + (b2 - b1) * t) * 257)
	return 0
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
    Variable mode,ci,si,ns,k
    Variable &r,&g,&b
    if(mode<=2)
        AT_E_GradColor(mode,si,ns,r,g,b)
    elseif(mode==3)
        AT_E_GradColor(2-mod(ci,2),si,ns,r,g,b)
    else
        AT_E_Palette(ci,r,g,b)
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
		// /R also keeps Reverse axis checked when switching back to autoscale.
		SetAxis/W=$gName/R $ax b, a
	else
		SetAxis/W=$gName $ax a, b
	endif
End

// =====================================================================
//  PANEL STATE AND THESIS2 STYLE
// =====================================================================

Function AT_E_InitPrefs()
    NewDataFolder/O root:Packages
    NewDataFolder/O root:Packages:AcademicToolbox
    AT_E_DefPref("gradient",1)
    AT_E_DefPref("uvGradient",1)
    AT_E_DefPref("currentScale",1)
    AT_E_DefPref("timeScale",1)
    AT_E_DefPref("useCorrected",0)
    AT_E_DefPref("freeGraphSize",0)
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


// Thesis2 with the requested free-size option and explicit-unit tick formatting.
Function AT_E_ApplyLook(gName, doTraces)
    String gName
    Variable doTraces // 1: explicit Apply Thesis2 also restores electrical axis direction
    if(strlen(gName)==0)
        gName=WinName(0,1)
    endif
    if(strlen(gName)==0 || WinType(gName)!=1)
        return -1
    endif
    ModifyGraph/W=$gName axThick=0.75,btLen=3,fSize=9,lsize=0.75,expand=2,font="Arial",tick=2,standoff=0
    AT_ApplyGraphSize(gName)
    // Units are explicit in axis titles. Current traces use an A-to-uA display
    // multiplier while retaining A in their wave metadata; do not repeat that
    // metadata beside ticks. Keep ordinary measurement ranges in fixed notation
    // so 1000 seconds is labelled 1000, not 1 ks. Source waves are unchanged.
    ModifyGraph/W=$gName tickUnit=1,lowTrip=1e-15,highTrip=1e15
    // Igor cannot mirror into an edge already occupied by a real axis.
    // Apply mirror=1 wherever legal, retaining right/top voltage axes.
    String axes=AxisList(gName)
    if(WhichListItem("left",axes)>=0 && WhichListItem("right",axes)<0)
        ModifyGraph/W=$gName mirror(left)=1
    endif
    if(WhichListItem("bottom",axes)>=0 && WhichListItem("top",axes)<0)
        ModifyGraph/W=$gName mirror(bottom)=1
    endif
    AT_E_FormatAxes(gName,doTraces)
    AT_UnframeLegends(gName)
    return 0
End

// Recognize electrical quantities from plotted waves, not from an axis position.
// This keeps time, wavelength and absorbance axes out of electrical formatting.
Static Function AT_E_WaveKind(w)
    WAVE/Z w
    if(!WaveExists(w))
        return 0
    endif
    String nm=NameOfWave(w)
    if(strlen(AT_E_ColumnBase(nm,"DrainI"))>0 || stringmatch(nm,"SS_*_Id"))
        return 1
    endif
    if(strlen(AT_E_ColumnBase(nm,"GateV"))>0 || strlen(AT_E_ColumnBase(nm,"Vref"))>0 || stringmatch(nm,"SS_*_Vg"))
        return 2
    endif
    return 0
End

Static Function AT_E_AxisKind(gn,ax)
    String gn,ax
    String traces=TraceNameList(gn,";",1),tn,info
    Variable i,kind=0,k
    for(i=0;i<ItemsInList(traces);i+=1)
        tn=StringFromList(i,traces)
        info=TraceInfo(gn,tn,0)
        if(cmpstr(StringByKey("YAXIS",info),ax)==0)
            WAVE/Z yw=TraceNameToWaveRef(gn,tn)
            k=AT_E_WaveKind(yw)
        elseif(cmpstr(StringByKey("XAXIS",info),ax)==0)
            WAVE/Z xw=XWaveRefFromTrace(gn,tn)
            k=AT_E_WaveKind(xw)
        else
            continue
        endif
        if(k==1)
            return 1
        endif
        kind=max(kind,k)
    endfor
    return kind
End

Static Function AT_E_FormatAxes(gn,reverseAxes)
    String gn
    Variable reverseAxes
    // Autoscaled bounds are computed during redraw, not during SetAxis.
    DoUpdate/W=$gn
    String axes=AxisList(gn),ax,info,flags
    Variable i,kind,lo,hi,a,b,step,exponent,scale,largest
    for(i=0;i<ItemsInList(axes);i+=1)
        ax=StringFromList(i,axes)
        kind=AT_E_AxisKind(gn,ax)
        if(kind==0)
            continue
        endif
        info=AxisInfo(gn,ax)
        GetAxis/W=$gn/Q $ax
        lo=min(V_min,V_max); hi=max(V_min,V_max)
        if(reverseAxes)
            flags=StringByKey("SETAXISFLAGS",info)
            if(strlen(flags)>0)
                // Retain autoscale mode, zero handling and range algorithm.
                flags=ReplaceString("/R",flags,"")+"/R"
                Execute/Q "SetAxis/W="+PossiblyQuoteName(gn)+flags+" "+PossiblyQuoteName(ax)
            else
                SetAxis/W=$gn/R $ax hi,lo
            endif
        endif
        if(kind==1 && NumberByKey("log(x)",info,"=")==0)
            // One decimal, except zero. Small currents need an explicit exponent
            // so distinct microamp values are not all rounded to 0.0.
            AT_E_NiceRange(lo,hi,a,b,step)
            largest=max(abs(lo),abs(hi))
            exponent=0
            if(largest>0 && largest<0.1)
                exponent=floor(log(largest))
            endif
            scale=10^exponent
            step=max(0.1,ceil(step/scale*10-1e-8)/10)
            ModifyGraph/W=$gn userticks($ax)=0,prescaleExp($ax)=0,manTick($ax)={0,step,exponent,1},ZisZ($ax)=1,zapTZ($ax)=0
        endif
    endfor
    return 0
End

// Refresh toolbox legend names and remove frames without moving annotations.
Static Function AT_UnframeLegends(gn)
    String gn
    String annotations=AnnotationList(gn),an,info,leg
    Variable i
    for(i=0;i<ItemsInList(annotations);i+=1)
        an=StringFromList(i,annotations)
        info=AnnotationInfo(gn,an)
        if(cmpstr(StringByKey("TYPE",info),"Legend")==0)
            if(cmpstr(an,"legOE")==0 || cmpstr(an,"ATvoltageLegend")==0)
                leg=AT_LegendText(gn,cmpstr(an,"ATvoltageLegend")==0)
                Legend/W=$gn/C/N=$an/F=0 leg
            else
                Legend/W=$gn/C/N=$an/F=0
            endif
        endif
    endfor
    return 0
End

// Change only width/height. Auto mode lets each dimension follow window resizing.
Function AT_ApplyGraphSize(gName)
    String gName
    AT_E_InitPrefs()
    if(strlen(gName)==0)
        gName=WinName(0,1)
    endif
    if(strlen(gName)==0 || WinType(gName)!=1)
        return -1
    endif
    NVAR freeSize=root:Packages:AcademicToolbox:freeGraphSize
    if(freeSize)
        ModifyGraph/W=$gName width=0,height=0
    else
        ModifyGraph/W=$gName width=170.079,height=99.2126
    endif
    return 0
End

Function AT_FreeSizeCheck(ca) : CheckBoxControl
    STRUCT WMCheckboxAction &ca
    if(ca.eventCode!=2)
        return 0
    endif
    AT_E_InitPrefs()
    NVAR freeSize=root:Packages:AcademicToolbox:freeGraphSize
    freeSize=ca.checked
    AT_ApplyGraphSize("")
    return 0
End

Static Function AT_E_Style(gName, xlab, ylab)
	String gName, xlab, ylab
	AT_E_ApplyLook(gName, 0)
	Label/W=$gName bottom xlab
	Label/W=$gName left   ylab
End

Static Function AT_E_PutLegend(gName, leg)
	String gName, leg
	if (strlen(leg) == 0)
		return 0
	endif
	AT_AddLegend(gName)
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
		Printf "  ! %d file(s) had no s# token; sample set to \"unknown\".\r", nNoSample
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
		Printf "  ! %d file(s) had no s# token; sample set to \"unknown\".\r", nNoSample
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

	String catFilter = "*"
	Variable pickMode = 2
	Variable useCorr = 1
	NVAR savedGradient=root:Packages:AcademicToolbox:uvGradient
	Variable colorMode = savedGradient
	Variable xLo = 400
	Variable xHi = 1600
	Variable showLeg = 1

	Prompt catFilter, "Category filter ( * = all )"
	Prompt pickMode,   "Data selection", popup, "Everything matching the filter;Choose from a list..."
	Prompt useCorr,   "Which data?", popup, "Corrected;Raw"
	Prompt colorMode, "Colouring", popup, "Red (dark to light);Blue (dark to light);Categories blue & red;Distinct category colors"
	Prompt xLo,       "Wavelength axis, from (nm)  [0 = auto]"
	Prompt xHi,       "Wavelength axis, to (nm)    [0 = auto]"
	Prompt showLeg,   "Legend", popup, "Show;Hide"
	DoPrompt "Plot UV-vis spectra", catFilter, pickMode, useCorr, colorMode, xLo, xHi, showLeg
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
	Display/N=$gName as "UV-vis spectra"

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


		Variable r, g, b
		AT_E_TraceColor(colorMode, ciW[i], siW[i], nsW[i], i, r, g, b)
		ModifyGraph/W=$gName rgb($tn) = (r, g, b)

		WaveStats/Q/M=1/R=[pA, pB] wy
		ymin = min(ymin, V_min)
		ymax = max(ymax, V_max)

		if (showLeg == 1)
			if (colorMode == 4)
				if (cmpstr(ctw[idx[i]], lastCat) != 0 && siW[i] == 0)
					leg += "\\s(" + PossiblyQuoteName(tn) + ") " + ctw[idx[i]] + "\r"
					lastCat = ctw[idx[i]]
				endif
			else
				leg += "\\s(" + PossiblyQuoteName(tn) + ") " + bnw[idx[i]] + "\r"
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
	AT_RecolorGraph(gName,colorMode)
	AT_E_PutLegend(gName, leg)

	return 0
End

// =====================================================================
//  NAME PARSING
// =====================================================================

//  Find "s" followed by one or more digits ANYWHERE in the file name --
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

// Two focused panels; graph controls act on the frontmost graph.
Function AT_Panel()
    return AT_ElectricalPanel()
End

Function AT_ElectricalPanel()
    return AT_OpenPanel(0)
End

Function AT_UVPanel()
    return AT_OpenPanel(1)
End

Static Function AT_OpenPanel(uv)
    Variable uv
    AT_E_InitPrefs()
    String pn="ATpanel", title="Academic Toolbox - Electrical / OECT"
    Variable graphY=292
    NVAR eg=root:Packages:AcademicToolbox:gradient,ug=root:Packages:AcademicToolbox:uvGradient
    Variable grad=eg
    if(uv)
        pn="ATuvPanel"
        title="Academic Toolbox - UV-vis"
        graphY=190
        grad=ug
    endif
    DoWindow/F $pn
    if(V_flag)
        return 0
    endif
    NewPanel/K=1/N=$pn/W=(60,50,460,50+graphY+244) as title
    if(uv)
        GroupBox gbData,win=$pn,pos={10,8},size={380,172},title="UV-vis"
        Button bLoadU,win=$pn,pos={24,30},size={170,26},proc=AT_Button,title="Load folder..."
        Button bFileU,win=$pn,pos={204,30},size={170,26},proc=AT_Button,title="Load single file(s)..."
        Button bListU,win=$pn,pos={24,62},size={240,26},proc=AT_Button,title="List loaded spectra"
        Button bKillU,win=$pn,pos={274,62},size={100,26},proc=AT_Button,title="Clear data..."
        Button bCorr,win=$pn,pos={24,100},size={350,26},proc=AT_Button,title="Correct (jump + reference baseline)"
        Button bPlotU,win=$pn,pos={24,138},size={350,26},proc=AT_Button,title="Plot spectra"
    else
        GroupBox gbData,win=$pn,pos={10,8},size={380,274},title="Electrical / OECT"
        Button bLoadE,win=$pn,pos={24,30},size={170,26},proc=AT_Button,title="Load folder..."
        Button bFileE,win=$pn,pos={204,30},size={170,26},proc=AT_Button,title="Load single file(s)..."
        Button bListE,win=$pn,pos={24,62},size={240,26},proc=AT_Button,title="List loaded files"
        Button bKillE,win=$pn,pos={274,62},size={100,26},proc=AT_Button,title="Clear data..."
        Button bIt,win=$pn,pos={24,100},size={170,26},proc=AT_Button,title="Plot Id vs time"
        Button bVref,win=$pn,pos={204,100},size={170,26},proc=AT_Button,title="Plot Vref vs time"
        Button bIV,win=$pn,pos={24,132},size={170,26},proc=AT_Button,title="Plot Id vs Vg"
        Button bSS,win=$pn,pos={204,132},size={170,26},proc=AT_Button,title="Steady-state Id vs Vg"
        Button bAddVg,win=$pn,pos={24,164},size={170,26},proc=AT_Button,title="Add Vg vs time"
        Button bAddVref,win=$pn,pos={204,164},size={170,26},proc=AT_Button,title="Add Vref vs time"
        Button bFixI,win=$pn,pos={24,202},size={350,26},proc=AT_Button,title="Correct Id / Ig (gate steps)..."
        CheckBox cbCorrected,win=$pn,pos={24,242},title="Use corrected currents when available",variable=root:Packages:AcademicToolbox:useCorrected
    endif
    GroupBox gbGraph,win=$pn,pos={10,graphY},size={380,232},title="Graph style and colors"
    Button bApplyTop,win=$pn,pos={24,graphY+24},size={170,26},proc=AT_Button,title="Apply Thesis2"
    Button bDefault,win=$pn,pos={204,graphY+24},size={170,26},proc=AT_Button,title="Restore to default"
    Button bLegend,win=$pn,pos={24,graphY+56},size={170,26},proc=AT_Button,title="Add legend"
    Button bRecolor,win=$pn,pos={204,graphY+56},size={170,26},proc=AT_Button,title="Recolor"
    CheckBox cbFreeSize,win=$pn,pos={24,graphY+94},title="Free graph size (resize window)",variable=root:Packages:AcademicToolbox:freeGraphSize,proc=AT_FreeSizeCheck
    PopupMenu pmGrad,win=$pn,pos={24,graphY+122},bodyWidth=280,title="Colors",mode=grad,proc=AT_GradientPopup,value="Red (dark to light);Blue (dark to light);Categories blue & red;Distinct category colors"
    PopupMenu pmPalette,win=$pn,pos={24,graphY+190},title="Curve color",mode=0,proc=AT_PalettePopup,value="Exact palette and curve colors..."
    AT_DrawPalette(pn,grad,graphY+154)
    return 0
End

Function AT_Button(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    strswitch(ba.ctrlName)
        case "bLoadE":
            AT_E_LoadFolder()
            break
        case "bFileE":
            AT_E_LoadFiles()
            break
        case "bListE":
            AT_E_ListFiles()
            break
        case "bKillE":
            AT_E_KillAll()
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
        case "bAddVg":
            AT_E_AddVg()
            break
        case "bAddVref":
            AT_E_AddVref()
            break
        case "bFixI":
            AT_E_CorrectCurrents()
            break
        case "bLoadU":
            AT_U_LoadFolder()
            break
        case "bFileU":
            AT_U_LoadFiles()
            break
        case "bListU":
            AT_U_ListFiles()
            break
        case "bKillU":
            AT_U_KillAll()
            break
        case "bCorr":
            AT_U_Correct()
            break
        case "bPlotU":
            AT_U_PlotSpectra()
            break
        case "bApplyTop":
            AT_E_ApplyLook("",1)
            break
        case "bDefault":
            AT_RestoreDefault("")
            break
        case "bLegend":
            AT_AddLegend("")
            break
        case "bRecolor":
            ControlInfo/W=$ba.win pmGrad
            AT_RecolorGraph("",V_Value)
            break
    endswitch
    return 0
End

Function AT_GradientPopup(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode!=2)
        return 0
    endif
    String key="gradient"
    Variable y=446
    if(cmpstr(pa.win,"ATuvPanel")==0)
        key="uvGradient"
        y=344
    endif
    NVAR grad=root:Packages:AcademicToolbox:$key
    grad=pa.popNum
    AT_DrawPalette(pa.win,grad,y)
    return 0
End

Static Function AT_DrawPalette(pn,mode,y)
    String pn
    Variable mode,y
    Variable i,n=14,r,g,b
    SetDrawLayer/W=$pn/K UserBack
    for(i=0;i<n;i+=1)
        if(mode<=2)
            AT_E_GradColor(mode,i,n,r,g,b)
        elseif(mode==3)
            AT_E_GradColor(2-floor(i/7),mod(i,7),7,r,g,b)
        else
            AT_E_Palette(i,r,g,b)
        endif
        SetDrawEnv/W=$pn xcoord=abs,ycoord=abs,fillfgc=(r,g,b),linethick=0
        DrawRect/W=$pn 24+i*25,y,49+i*25,y+20
    endfor
End

Menu "Macros"
    "Academic Toolbox - Electrical / OECT",/Q,AT_ElectricalPanel()
    "Academic Toolbox - UV-vis",/Q,AT_UVPanel()
End

// Backward-compatible entry point; all electrical input is A, V and s.
Function AT_InputUnits()
	AT_E_InitPrefs()
	NVAR isc=root:Packages:AcademicToolbox:currentScale
	NVAR tsc=root:Packages:AcademicToolbox:timeScale
	isc=1
	tsc=1
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
// Electrical input units are fixed A, V, s. UV fmt=1 JASCO, fmt=2 plain two-column.
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
		return AT_E_Ingest(fn,"space",1,1,skipLines,encoding)
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


// New imports use column-first names. Existing experiments remain readable.
Static Function/S AT_E_ColumnPath(base,column)
	String base,column
	String path="root:AT_Elec:Data:"+PossiblyQuoteName(column+"_"+base)
	if(exists(path))
		return path
	endif
	return "root:AT_Elec:Data:"+PossiblyQuoteName(base+"_"+column)
End

Static Function/S AT_E_ColumnBase(nm,column)
	String nm,column
	Variable n=strlen(column)
	if(strsearch(nm,column+"_",0)==0)
		return nm[n+1,strlen(nm)-1]
	endif
	if(stringmatch(nm,"*_"+column))
		return nm[0,strlen(nm)-n-2]
	endif
	return ""
End

Static Function AT_E_StoreCanonical(sourceName,base,column,units)
	String sourceName,base,column,units
	if(strlen(sourceName)==0)
		return 0
	endif
	WAVE/Z src=$sourceName
	if(!WaveExists(src) || WaveType(src)==0)
		return 0
	endif
	String dest="root:AT_Elec:Data:"+PossiblyQuoteName(column+"_"+base)
	Duplicate/O src,$dest
	WAVE dst=$dest
	SetScale d,0,0,units,dst
	return 0
End


// ---------- Graph actions ----------
Function AT_AddLegend(gn)
    String gn
    if(strlen(gn)==0)
        gn=WinName(0,1)
    endif
    if(strlen(gn)==0 || WinType(gn)!=1)
        return -1
    endif
    String leg=AT_LegendText(gn,0)
    if(strlen(leg)==0)
        return 0
    endif
    // Named update retains an existing legend's location and text appearance.
    if(WhichListItem("legOE",AnnotationList(gn))>=0)
        Legend/W=$gn/C/N=legOE/F=0 leg
    else
        Legend/W=$gn/N=legOE/F=0 leg
    endif
    if(WhichListItem("ATvoltageLegend",AnnotationList(gn))>=0)
        leg=AT_LegendText(gn,1)
        Legend/W=$gn/C/N=ATvoltageLegend/F=0 leg
    endif
    return 0
End

// One entry per data trace, regardless of the selected colour scheme.
// Managed voltages have a separate key and must not appear twice.
Static Function/S AT_LegendText(gn,overlays)
    String gn
    Variable overlays
    String traces=TraceNameList(gn,";",1),tn,leg="",prefix=""
    Variable i,isOverlay
    for(i=0;i<ItemsInList(traces);i+=1)
        tn=StringFromList(i,traces)
        isOverlay=(cmpstr(tn,"ATvgOverlay")==0 || cmpstr(tn,"ATvrefOverlay")==0)
        if(isOverlay!=overlays)
            continue
        endif
        prefix=""
        if(isOverlay)
            prefix=SelectString(cmpstr(tn,"ATvgOverlay")==0,"Vref: ","Vg: ")
        endif
        leg+="\\s("+PossiblyQuoteName(tn)+") "+prefix+AT_TraceLegendName(gn,tn)+"\r"
    endfor
    return RemoveEnding(leg,"\r")
End

Static Function/S AT_TraceLegendName(gn,tn)
    String gn,tn
    WAVE/Z w=TraceNameToWaveRef(gn,tn)
    if(!WaveExists(w))
        return tn
    endif
    String nm=NameOfWave(w),samp=StringByKey("ATSample",note(w),"=",";"),cat=StringByKey("ATCategory",note(w),"=",";")
    String base=StringByKey("ATBase",note(w),"=",";"),folder,candidate
    Variable kind,i,found=0
    if(strlen(samp)==0 || cmpstr(samp,"unknown")==0 || strlen(cat)==0)
        for(kind=0;kind<2;kind+=1)
            folder=SelectString(kind,"root:AT_Elec:","root:AT_UV:")
            WAVE/Z/T bn=$(folder+"BaseName"),ct=$(folder+"Category"),sp=$(folder+"Sample")
            if(!WaveExists(bn) || !WaveExists(ct) || !WaveExists(sp))
                continue
            endif
            for(i=0;i<numpnts(bn);i+=1)
                candidate=bn[i]
                if(cmpstr(base,candidate)==0 || stringmatch(nm,"*_"+candidate) || cmpstr(nm,candidate+"_Abs")==0 || cmpstr(nm,candidate+"_Absc")==0)
                    samp=sp[i]; cat=ct[i]; base=candidate
                    found=1
                    break
                endif
            endfor
            if(found)
                break
            endif
        endfor
    endif
    if(strlen(samp)==0 || cmpstr(samp,"unknown")==0)
        AT_E_FindSample(nm,samp)
    endif
    if(strlen(samp)>0 && cmpstr(samp,"unknown")!=0)
        if(strlen(cat)==0)
            cat=AT_TraceCategory(gn,tn)
        endif
        return samp+"_"+ReplaceString(" ",cat,"_")
    endif
    // A file without an s# token has no sample number to invent.
    if(strlen(base)>0)
        return base
    endif
    return nm
End

// Rebuild the same plot with Igor factory defaults. Data, axis assignments,
// error bars, label text and display unit/time transformations are retained.
// The original is kept until the replacement has been built successfully.
Function AT_RestoreDefault(gn)
    String gn
    if(strlen(gn)==0)
        gn=WinName(0,1)
    endif
    if(strlen(gn)==0 || WinType(gn)!=1)
        return -1
    endif
    String recreation=WinRecreation(gn,0),df=GetDataFolder(1),line,newGN="",tl=TraceNameList(gn,";",1)
    if(ItemsInList(tl)==0 || strlen(ImageNameList(gn,";"))+strlen(ContourNameList(gn,";"))>0 || strlen(ChildWindowList(gn))>0)
        DoAlert 0,"Restore supports standalone curve graphs. This graph was left unchanged."
        return -1
    endif
    Variable i,j,k,err=0,oldPrefs
    Preferences/Q 0
    oldPrefs=V_flag
    try
        for(i=0;i<ItemsInList(recreation,"\r");i+=1)
            line=TrimString(StringFromList(i,recreation,"\r"))
            if(stringmatch(line,"SetDataFolder root*") || stringmatch(line,"SetDataFolder 'root*"))
                Execute/Q/Z line
                if(V_flag)
                    Abort "Cannot restore graph data folder."
                endif
            elseif(stringmatch(line,"Display *") || stringmatch(line,"Display/*"))
                j=strsearch(line,"/W=",0)
                if(j>=0)
                    k=strsearch(line,")",j)
                    line=line[0,j-1]+line[k+1,strlen(line)-1]
                endif
                Execute/Q/Z line
                if(V_flag)
                    Abort "Cannot rebuild graph."
                endif
                newGN=WinName(0,1)
            elseif(stringmatch(line,"AppendToGraph*") || stringmatch(line,"ErrorBars*") || stringmatch(line,"Label *"))
                if(strlen(newGN)==0)
                    Abort "No graph created."
                endif
                Execute/Q/Z line
                if(V_flag)
                    Abort "Cannot rebuild a graph component."
                endif
            endif
        endfor
        if(strlen(newGN)==0 || cmpstr(TraceNameList(newGN,";",1),tl)!=0)
            Abort "Graph trace reconstruction mismatch."
        endif
        // Unit conversions and time-zero alignment describe the plotted data.
        // Preserve them separately from appearance, to keep the labels truthful.
        String tn,info,pair
        Variable xo,yo,xm,ym
        for(i=0;i<ItemsInList(tl);i+=1)
            tn=StringFromList(i,tl)
            info=TraceInfo(gn,tn,0)
            pair=StringByKey("offset(x)",info,"=")
            xo=0; yo=0
            if(strlen(pair)>0)
                sscanf pair,"{%g,%g}",xo,yo
            endif
            pair=StringByKey("muloffset(x)",info,"=")
            xm=0; ym=0
            if(strlen(pair)>0)
                sscanf pair,"{%g,%g}",xm,ym
            endif
            ModifyGraph/W=$newGN offset($tn)={xo,yo},muloffset($tn)={xm,ym}
        endfor
    catch
        err=GetRTError(1)
        if(strlen(newGN)>0 && cmpstr(newGN,gn)!=0)
            KillWindow/Z $newGN
        endif
        SetDataFolder df
        Preferences/Q oldPrefs
        DoAlert 0,"Could not rebuild this graph. The original graph is unchanged."
        return -1
    endtry
    SetDataFolder df
    Preferences/Q oldPrefs
    KillWindow $gn
    DoWindow/W=$newGN/C $gn
    return 0
End

Static Function/S AT_TraceCategory(gn,tn)
    String gn,tn
    WAVE/Z w=TraceNameToWaveRef(gn,tn)
    if(!WaveExists(w))
        return "Uncategorized"
    endif
    String cat=StringByKey("ATCategory",note(w),"=",";")
    if(strlen(cat)>0)
        return cat
    endif
    String nm=NameOfWave(w),base,folder
    Variable kind,i
    for(kind=0;kind<2;kind+=1)
        folder=SelectString(kind,"root:AT_Elec:","root:AT_UV:")
        WAVE/Z/T bn=$(folder+"BaseName"),ct=$(folder+"Category")
        if(!WaveExists(bn) || !WaveExists(ct))
            continue
        endif
        for(i=0;i<numpnts(bn);i+=1)
            base=bn[i]
            if(stringmatch(nm,"*_"+base) || cmpstr(nm,base+"_Abs")==0 || cmpstr(nm,base+"_Absc")==0)
                return ct[i]
            endif
        endfor
    endfor
    String samp=""
    Variable pos=AT_E_FindSample(nm,samp)
    if(pos>=0)
        cat=StringFromList(0,nm[pos+strlen(samp)+1,strlen(nm)-1],"_")
        if(strlen(cat)>0)
            return cat
        endif
    endif
    return "Uncategorized"
End

// Fill an exact planned color for each data trace, in trace order. Overlays stay grey.
Static Function AT_GraphColors(gn,mode,colors,traces)
    String gn
    Variable mode
    WAVE colors
    WAVE/T traces
    String all=TraceNameList(gn,";",1),tn,cats="",cat
    Variable i,n=0,ci,r,g,b
    Redimension/N=(ItemsInList(all)) traces
    for(i=0;i<ItemsInList(all);i+=1)
        tn=StringFromList(i,all)
        if(cmpstr(tn,"ATvgOverlay")!=0 && cmpstr(tn,"ATvrefOverlay")!=0)
            traces[n]=tn
            n+=1
        endif
    endfor
    Redimension/N=(n) traces
    Redimension/N=(n,3) colors
    Make/FREE/N=(n) group,ordinal,count=0
    for(i=0;i<n;i+=1)
        cat=AT_TraceCategory(gn,traces[i])
        ci=WhichListItem(cat,cats)
        if(ci<0)
            cats+=cat+";"
            ci=ItemsInList(cats)-1
        endif
        group[i]=ci
        ordinal[i]=count[ci]
        count[ci]+=1
    endfor
    if(mode==3 && ItemsInList(cats)>2)
        Print "Blue/red mode alternates blue and red for more than two categories; use Distinct category colors for a unique category palette."
    endif
    for(i=0;i<n;i+=1)
        if(mode<=2)
            AT_E_GradColor(mode,i,n,r,g,b)
        elseif(mode==3)
            AT_E_GradColor(2-mod(group[i],2),ordinal[i],count[group[i]],r,g,b)
        else
            AT_E_Palette(group[i],r,g,b)
        endif
        colors[i][0]=round(r); colors[i][1]=round(g); colors[i][2]=round(b)
    endfor
    return n
End

Function AT_RecolorGraph(gn,mode)
    String gn
    Variable mode
    if(strlen(gn)==0)
        gn=WinName(0,1)
    endif
    if(strlen(gn)==0)
        return -1
    endif
    Make/FREE/D/N=(0,3) colors
    Make/FREE/T/N=0 traces
    Variable i,n=AT_GraphColors(gn,mode,colors,traces)
    for(i=0;i<n;i+=1)
        ModifyGraph/W=$gn rgb($traces[i])=(colors[i][0],colors[i][1],colors[i][2])
    endfor
    return n
End

Function AT_PalettePopup(pa) : PopupMenuControl
    STRUCT WMPopupAction &pa
    if(pa.eventCode==2)
        ControlInfo/W=$pa.win pmGrad
        AT_ColorPicker(WinName(0,1),V_Value)
    endif
    return 0
End

// The internal waves below only drive the swatch UI; no color-table export feature.
Function AT_ColorPicker(gn,mode)
    String gn
    Variable mode
    if(strlen(gn)==0)
        DoAlert 0,"Plot a graph first, then open Curve color."
        return -1
    endif
    AT_E_InitPrefs()
    KillWindow/Z ATcolorPicker
    NewDataFolder/O root:Packages:AcademicToolbox:Picker
    String/G root:Packages:AcademicToolbox:Picker:graph=gn
    String/G root:Packages:AcademicToolbox:Picker:traceList=TraceNameList(gn,";",1)
    Make/FREE/D/N=(0,3) planned
    Make/FREE/T/N=0 traces
    Variable n=AT_GraphColors(gn,mode,planned,traces),i,r,g,b,row,total=n+22
    Make/O/T/N=(total,3) root:Packages:AcademicToolbox:Picker:labels
    Make/O/D/N=(total+1,3) root:Packages:AcademicToolbox:Picker:colors=65535
    Make/O/W/U/N=(total,3,2) root:Packages:AcademicToolbox:Picker:selection=0
    WAVE/T labels=root:Packages:AcademicToolbox:Picker:labels
    WAVE colors=root:Packages:AcademicToolbox:Picker:colors,sel=root:Packages:AcademicToolbox:Picker:selection
    SetDimLabel 1,0,Color,labels
    SetDimLabel 1,1,Source,labels
    SetDimLabel 1,2,RGB_16bit,labels
    SetDimLabel 2,1,backColors,sel
    String label,rgb
    for(row=0;row<total;row+=1)
        if(row<n)
            r=planned[row][0]; g=planned[row][1]; b=planned[row][2]
            label="Graph: "+traces[row]
        elseif(row<n+14)
            i=row-n
            AT_E_GradColor(1+floor(i/7),mod(i,7),7,r,g,b)
            label=SelectString(i>=7,"Red ","Blue ")+num2istr(mod(i,7)+1)
        else
            i=row-n-14
            AT_E_Palette(i,r,g,b)
            label="Category "+num2istr(i+1)
        endif
        colors[row+1][0]=r; colors[row+1][1]=g; colors[row+1][2]=b
        labels[row][0]=""
        labels[row][1]=label
        sprintf rgb,"%d, %d, %d",r,g,b
        labels[row][2]=rgb
        sel[row][0][1]=row+1
    endfor
    NewPanel/K=1/N=ATcolorPicker/W=(150,100,850,540) as "Exact curve colors"
    PopupMenu pmTrace,pos={14,14},bodyWidth=540,title="Curve",mode=1,value=#"root:Packages:AcademicToolbox:Picker:traceList"
    ListBox lbColors,pos={14,50},size={670,330},listWave=labels,selWave=sel,colorWave=colors,mode=2,selRow=0,widths={52,390,210}
    Button bColorApply,pos={14,396},size={220,26},proc=AT_ColorApply,title="Apply selected color to curve"
    TitleBox hint,pos={250,402},title="RGB uses Igor's exact 0-65535 values.",frame=0
    return 0
End

Function AT_ColorApply(ba) : ButtonControl
    STRUCT WMButtonAction &ba
    if(ba.eventCode!=2)
        return 0
    endif
    SVAR gn=root:Packages:AcademicToolbox:Picker:graph
    if(WinType(gn)!=1)
        DoAlert 0,"The selected graph has closed. Reopen Curve color."
        return -1
    endif
    ControlInfo/W=ATcolorPicker pmTrace
    String tn=S_Value
    if(WhichListItem(tn,TraceNameList(gn,";",1))<0)
        return -1
    endif
    ControlInfo/W=ATcolorPicker lbColors
    Variable row=V_Value+1
    WAVE colors=root:Packages:AcademicToolbox:Picker:colors
    if(row<1 || row>=DimSize(colors,0))
        return -1
    endif
    ModifyGraph/W=$gn rgb($tn)=(colors[row][0],colors[row][1],colors[row][2])
    return 0
End

// ---------- Gate-step artifact correction ----------
Static Function/S AT_E_CurrentPath(base,column)
    String base,column
    NVAR/Z use=root:Packages:AcademicToolbox:useCorrected
    String path="root:AT_Elec:Corr:"+PossiblyQuoteName(column+"_"+base)
    if(NVAR_Exists(use))
        if(use && exists(path)==1)
            return path
        endif
    endif
    return AT_E_ColumnPath(base,column)
End

// Start at the first sample carrying the NEW GateV. Adjacent masks are unioned.
// No points are removed at the beginning unless a recorded gate change occurs.
Function AT_E_GateMask(vg,omit,tol,mask)
    WAVE vg,mask
    Variable omit,tol
    if(numtype(omit+tol)!=0 || omit<1 || omit>10 || omit!=round(omit) || tol<0)
        return -1
    endif
    Variable i,j,n=numpnts(vg),changes=0
    Redimension/N=(n) mask
    mask=0
    for(i=1;i<n;i+=1)
        if(numtype(vg[i])==0 && numtype(vg[i-1])==0 && abs(vg[i]-vg[i-1])>tol)
            changes+=1
            for(j=i;j<min(n,i+omit);j+=1)
                mask[j]=1
            endfor
        endif
    endfor
    return changes
End

Function AT_E_CorrectOne(base,omit,tol)
    String base
    Variable omit,tol
    WAVE/Z vg=$AT_E_ColumnPath(base,"GateV")
    if(!WaveExists(vg))
        return -1
    endif
    Make/FREE/D/N=0 mask
    Variable changes=AT_E_GateMask(vg,omit,tol,mask),i,done=0
    if(changes<0)
        return -1
    endif
    NewDataFolder/O root:AT_Elec:Corr
    String column,dest
    for(i=0;i<2;i+=1)
        column=StringFromList(i,"DrainI;GateI")
        WAVE/Z raw=$AT_E_ColumnPath(base,column)
        if(!WaveExists(raw))
            continue
        endif
        if(numpnts(raw)!=numpnts(vg))
            Print "Skipped unequal GateV/"+column+" lengths: "+base
            continue
        endif
        dest="root:AT_Elec:Corr:"+PossiblyQuoteName(column+"_"+base)
        Duplicate/O raw,$dest
        WAVE corrected=$dest
        Redimension/D corrected
        corrected=mask[p] ? NaN : raw[p]
        Note corrected,"ATCorrection=gate-step omission;ATRemovePoints="+num2istr(omit)+";ATToleranceV="+num2str(tol)+";ATSource="+GetWavesDataFolder(raw,2)+";"
        done+=1
    endfor
    Print base+": "+num2istr(changes)+" gate changes; "+num2istr(sum(mask))+" points omitted in "+num2istr(done)+" current wave(s)."
    return done
End

Function AT_E_CorrectCurrents()
    WAVE/Z/T bn=root:AT_Elec:BaseName,ct=root:AT_Elec:Category,sp=root:AT_Elec:Sample
    if(!WaveExists(bn))
        DoAlert 0,"Load electrical data first."
        return -1
    endif
    Variable omit=1,tol=1e-4
    Prompt omit,"Number of points to omit at each gate change (integer 1-10)"
    Prompt tol,"Gate-change tolerance (V)"
    DoPrompt "Correct Id and Ig (raw data preserved)",omit,tol
    if(V_flag)
        return -1
    endif
    if(numtype(omit+tol)!=0 || omit<1 || omit>10 || omit!=round(omit) || tol<0)
        DoAlert 0,"Use an integer from 1 to 10 and a nonnegative voltage tolerance."
        return -1
    endif
    Make/FREE/N=(numpnts(bn)) idx=p
    Variable n=AT_E_PickFrom(idx,bn,ct,sp),i,done=0
    if(n<=0)
        return -1
    endif
    for(i=0;i<n;i+=1)
        done+=max(0,AT_E_CorrectOne(bn[idx[i]],omit,tol))
    endfor
    AT_E_InitPrefs()
    NVAR use=root:Packages:AcademicToolbox:useCorrected
    use=1
    // Existing plots of selected raw current waves are switched to the copies.
    String graphs=WinList("*",";","WIN:1"),gn,tl,tn,base,col,newPath
    Variable j,k,q
    for(j=0;j<ItemsInList(graphs);j+=1)
        gn=StringFromList(j,graphs)
        tl=TraceNameList(gn,";",1)
        for(k=0;k<ItemsInList(tl);k+=1)
            tn=StringFromList(k,tl)
            WAVE/Z plotted=TraceNameToWaveRef(gn,tn)
            if(!WaveExists(plotted))
                continue
            endif
            for(q=0;q<n;q+=1)
                base=bn[idx[q]]
                for(i=0;i<2;i+=1)
                    col=StringFromList(i,"DrainI;GateI")
                    WAVE/Z original=$AT_E_ColumnPath(base,col)
                    newPath=AT_E_CurrentPath(base,col)
                    if(WaveExists(original) && cmpstr(GetWavesDataFolder(plotted,2),GetWavesDataFolder(original,2))==0)
                        WAVE/Z copy=$newPath
                        if(WaveExists(copy))
                            ReplaceWave/W=$gn trace=$tn,copy
                        endif
                    endif
                endfor
            endfor
        endfor
    endfor
    Print "Corrected copies: root:AT_Elec:Corr. NaNs omit artifacts without shifting Time/GateV. Uncheck Use corrected to use raw currents in new plots."
    return done
End
