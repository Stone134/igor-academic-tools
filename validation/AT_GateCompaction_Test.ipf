#pragma TextEncoding = "UTF-8"
#pragma rtGlobals=3
#pragma IgorVersion=8.00

#include "Academic_Toolbox"

// Native regression: open this procedure, compile, then execute
//     AT_TestGateCompaction()
// Returns the failure count (zero means PASS). Fixtures use unused sample names;
// no loaded sample, selection metadata, preferences, or user graph is changed.
// The temporary graph and fixture waves are removed after the checks.
Function AT_TestGateCompaction()
    Variable failures=0,i,result
    String base=ATGC_UnusedBase(),column,path
    String columns="GateV;DrainI;GateI;Time;Vref"
    String rawFolder="root:AT_Elec:Data:"
    String corrFolder="root:AT_Elec:Corr:"
    NewDataFolder/O root:AT_Elec
    NewDataFolder/O root:AT_Elec:Data

    for(i=0;i<ItemsInList(columns);i+=1)
        column=StringFromList(i,columns)
        path=rawFolder+column+"_"+base
        Make/D/N=15 $path
    endfor
    WAVE rawVg=$(rawFolder+"GateV_"+base)
    WAVE rawId=$(rawFolder+"DrainI_"+base)
    WAVE rawIg=$(rawFolder+"GateI_"+base)
    WAVE rawTime=$(rawFolder+"Time_"+base)
    WAVE rawRef=$(rawFolder+"Vref_"+base)
    rawVg=floor(p/5)
    rawId=100+p
    rawIg=200+p
    rawTime=10+0.5*p
    rawRef=300+p
    Note rawId,"ATGCFixture=raw current note;"
    String originalNote=note(rawId)
    Duplicate/FREE rawVg,originalVg
    Duplicate/FREE rawId,originalId
    Duplicate/FREE rawIg,originalIg
    Duplicate/FREE rawTime,originalTime
    Duplicate/FREE rawRef,originalRef

    String graph=UniqueName("ATgcTestGraph",6,0)
    Display/N=$graph as "Temporary gate-compaction regression"
    AppendToGraph/W=$graph rawId/TN=ATgcId vs rawTime
    AppendToGraph/W=$graph rawIg/TN=ATgcIg vs rawTime
    AppendToGraph/W=$graph/R rawVg/TN=ATvgOverlay vs rawTime
    AppendToGraph/W=$graph/R rawRef/TN=ATvrefOverlay vs rawTime

    Print "--- AT gate-compaction native regression: "+base+" ---"
    result=AT_E_CorrectOne(base,2,1e-4)
    failures+=ATGC_Check(result==2,"CorrectOne returns two corrected currents")
    Make/FREE/D keep={0,1,2,3,4,7,8,9,12,13,14}
    Make/FREE/D/N=11 expectedId,expectedIg,expectedVg,expectedRef,expectedTime,expectedSourceTime
    expectedId=100+keep[p]
    expectedIg=200+keep[p]
    expectedVg=floor(keep[p]/5)
    expectedRef=300+keep[p]
    expectedTime=10+0.5*p
    expectedSourceTime=10+0.5*keep[p]
    failures+=ATGC_Check(ATGC_PathMatches(corrFolder+"DrainI_"+base,expectedId),"Id retains exact rows and has no inserted NaNs")
    failures+=ATGC_Check(ATGC_PathMatches(corrFolder+"GateI_"+base,expectedIg),"Ig retains the same rows as Id")
    failures+=ATGC_Check(ATGC_PathMatches(corrFolder+"GateV_"+base,expectedVg),"Vg remains aligned with retained current rows")
    failures+=ATGC_Check(ATGC_PathMatches(corrFolder+"Vref_"+base,expectedRef),"Vref remains aligned with retained current rows")
    failures+=ATGC_Check(ATGC_PathMatches(corrFolder+"Time_"+base,expectedTime),"Time closes gaps; successive plateaus shift 2 and 4 samples")
    failures+=ATGC_Check(ATGC_PathMatches(corrFolder+"SourceTime_"+base,expectedSourceTime),"SourceTime preserves acquisition timestamps")
    failures+=ATGC_Check(ATGC_PathMatches(corrFolder+"SourceIndex_"+base,keep),"SourceIndex preserves original zero-based rows")

    if(result==2)
        AT_E_RefreshCorrectedGraphs(base)
        failures+=ATGC_Check(ATGC_TraceMatches(graph,"ATgcId",corrFolder+"DrainI_"+base,corrFolder+"Time_"+base),"Existing Id graph switches both Y and X to corrected data")
        failures+=ATGC_Check(ATGC_TraceMatches(graph,"ATgcIg",corrFolder+"GateI_"+base,corrFolder+"Time_"+base),"Existing Ig graph switches both Y and X to corrected data")
        failures+=ATGC_Check(ATGC_TraceMatches(graph,"ATvgOverlay",corrFolder+"GateV_"+base,corrFolder+"Time_"+base),"Existing Vg overlay follows corrected time")
        failures+=ATGC_Check(ATGC_TraceMatches(graph,"ATvrefOverlay",corrFolder+"Vref_"+base,corrFolder+"Time_"+base),"Existing Vref overlay follows corrected time")
    endif

    result=AT_E_CorrectOne(base,2,1e-4)
    failures+=ATGC_Check(result==2 && ATGC_PathMatches(corrFolder+"DrainI_"+base,expectedId) && ATGC_PathMatches(corrFolder+"GateI_"+base,expectedIg) && ATGC_PathMatches(corrFolder+"Time_"+base,expectedTime) && ATGC_PathMatches(corrFolder+"SourceIndex_"+base,keep),"Repeating correction does not remove additional rows")
    failures+=ATGC_Check(ATGC_PathMatches(rawFolder+"GateV_"+base,originalVg) && ATGC_PathMatches(rawFolder+"DrainI_"+base,originalId) && ATGC_PathMatches(rawFolder+"GateI_"+base,originalIg) && ATGC_PathMatches(rawFolder+"Time_"+base,originalTime) && ATGC_PathMatches(rawFolder+"Vref_"+base,originalRef),"All raw sample values and lengths remain unchanged")
    failures+=ATGC_Check(cmpstr(note(rawId),originalNote)==0,"Raw wave note remains unchanged")

    // A bad optional column must not partially overwrite a valid correction.
    Redimension/N=14 rawRef
    result=AT_E_CorrectOne(base,1,1e-4)
    failures+=ATGC_Check(result==-1 && ATGC_PathMatches(corrFolder+"DrainI_"+base,expectedId) && ATGC_PathMatches(corrFolder+"Time_"+base,expectedTime),"Unequal column lengths reject the whole correction before overwrite")
    Redimension/N=15 rawRef
    rawRef=originalRef[p]

    // Invalid settings are rejected before modifying the existing corrected bundle.
    result=AT_E_CorrectOne(base,0,1e-4)
    failures+=ATGC_Check(result==-1 && ATGC_PathMatches(corrFolder+"DrainI_"+base,expectedId),"Invalid omission count leaves previous correction intact")

    // With no transitions, all values and all acquisition times must be retained.
    rawVg=0
    result=AT_E_CorrectOne(base,2,1e-4)
    Make/FREE/D/N=15 allRows=p,allZero=0
    failures+=ATGC_Check(result==2 && ATGC_PathMatches(corrFolder+"DrainI_"+base,originalId) && ATGC_PathMatches(corrFolder+"GateI_"+base,originalIg) && ATGC_PathMatches(corrFolder+"GateV_"+base,allZero) && ATGC_PathMatches(corrFolder+"Time_"+base,originalTime) && ATGC_PathMatches(corrFolder+"SourceIndex_"+base,allRows),"No gate changes preserve the entire sample")

    failures+=ATGC_MaskTests()

    KillWindow $graph
    ATGC_RemoveFixture(base)
    Print "AT_TestGateCompaction: "+num2istr(failures)+" failure(s); temporary graph/waves removed."
    return failures
End

Static Function ATGC_MaskTests()
    Variable failures=0,result
    Make/FREE/D/N=0 mask
    Make/FREE/D vg={0,1,2,2,2,2,2}
    Make/FREE/D expected={0,1,1,1,1,0,0}
    result=AT_E_GateMask(vg,3,1e-4,mask)
    failures+=ATGC_Check(result==2 && ATGC_WavesMatch(mask,expected),"Overlapping removal windows are unioned, not counted twice")
    vg=0
    expected=0
    result=AT_E_GateMask(vg,3,1e-4,mask)
    failures+=ATGC_Check(result==0 && ATGC_WavesMatch(mask,expected),"Constant Vg leaves initial samples untouched")
    vg=0
    vg[6]=1
    expected=0
    expected[6]=1
    result=AT_E_GateMask(vg,3,1e-4,mask)
    failures+=ATGC_Check(result==1 && ATGC_WavesMatch(mask,expected),"A final-row transition clips removal at the end of the sample")
    vg=0
    vg[1]=0.00001
    expected=0
    result=AT_E_GateMask(vg,2,1e-4,mask)
    failures+=ATGC_Check(result==0 && ATGC_WavesMatch(mask,expected),"Sub-tolerance voltage noise is not a gate transition")
    failures+=ATGC_Check(AT_E_GateMask(vg,0,1e-4,mask)==-1 && AT_E_GateMask(vg,11,1e-4,mask)==-1 && AT_E_GateMask(vg,1.5,1e-4,mask)==-1 && AT_E_GateMask(vg,2,-1,mask)==-1 && AT_E_GateMask(vg,NaN,1e-4,mask)==-1,"Invalid count and tolerance inputs are rejected")
    return failures
End

Static Function ATGC_Check(condition,message)
    Variable condition
    String message
    if(condition)
        Print "PASS: "+message
        return 0
    endif
    Print "FAIL: "+message
    return 1
End

Static Function ATGC_PathMatches(path,expected)
    String path
    WAVE expected
    WAVE/Z actual=$path
    if(!WaveExists(actual))
        return 0
    endif
    return ATGC_WavesMatch(actual,expected)
End

Static Function ATGC_WavesMatch(actual,expected)
    WAVE actual,expected
    if(numpnts(actual)!=numpnts(expected))
        return 0
    endif
    Variable i
    for(i=0;i<numpnts(actual);i+=1)
        if(numtype(actual[i])!=0 || actual[i]!=expected[i])
            return 0
        endif
    endfor
    return 1
End

Static Function ATGC_TraceMatches(graph,traceName,yPath,xPath)
    String graph,traceName,yPath,xPath
    WAVE/Z yw=TraceNameToWaveRef(graph,traceName),xw=XWaveRefFromTrace(graph,traceName)
    if(!WaveExists(yw) || !WaveExists(xw))
        return 0
    endif
    return cmpstr(GetWavesDataFolder(yw,2),yPath)==0 && cmpstr(GetWavesDataFolder(xw,2),xPath)==0 && numpnts(yw)==numpnts(xw)
End

Static Function/S ATGC_UnusedBase()
    String base,columns="GateV;DrainI;GateI;Time;Vref;SourceTime;SourceIndex"
    String folders="root:AT_Elec:Data:;root:AT_Elec:Corr:",column,folder
    Variable sequence=0,i,j,occupied
    do
        base="ATgcTest"+num2istr(sequence)
        occupied=0
        for(i=0;i<ItemsInList(folders);i+=1)
            folder=StringFromList(i,folders)
            for(j=0;j<ItemsInList(columns);j+=1)
                column=StringFromList(j,columns)
                occupied=occupied || exists(folder+column+"_"+base) || exists(folder+base+"_"+column)
            endfor
        endfor
        sequence+=1
    while(occupied)
    return base
End

Static Function ATGC_RemoveFixture(base)
    String base
    String columns="GateV;DrainI;GateI;Time;Vref;SourceTime;SourceIndex"
    String folders="root:AT_Elec:Data:;root:AT_Elec:Corr:",path
    Variable i,j
    for(i=0;i<ItemsInList(folders);i+=1)
        for(j=0;j<ItemsInList(columns);j+=1)
            path=StringFromList(i,folders)+StringFromList(j,columns)+"_"+base
            KillWaves/Z $path
        endfor
    endfor
    return 0
End
