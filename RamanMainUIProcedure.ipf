#pragma rtGlobals=1		// Use modern global access method.
#include <SaveRestoreWindowCoords>
#include <SQLConstants>
#include <ImageSlider>
#include <3DWaveDisplay>


Menu "Raman"
	"RamanDataBaseExplorer", /Q, ShowMyPanel()
End

Function/S GetWMDemoConnectionString()
	// Uses DSN (Data Source Name) that you previously configured. See SQL Help file for details.
	// In this tutorial we use ensembldb.ensembl.org - a publically-accessible MySQL database that
	// hosts genome information. This database requires that we connect as user 'anonymous'
	// with no password. In real-life, you would use a real user name and password which you
	// would get from the database administrator.
	// String connectionStr = "DSN=RamanDataSource;UID=root;PWD=gulliver"
	
	String connectionStr = "DSN=StageRamanDatabase;UID=root;PWD=gulliver"
	
	return connectionStr
End

Function/S CreatePopUserString(NameTextWave, SurnameTextWave)
   wave/T NameTextWave, SurnameTextWave
   variable i
	string PopupUserString = ""
	for(i=0; i < numpnts(NameTextWave)-1;  i+=1)
		PopupUserString += NameTextWave(i) + " " + SurnameTextWave(i) + ";" 
	endfor
	PopupUserString += NameTextWave(numpnts(NameTextWave)-1) + " " + SurnameTextWave(numpnts(NameTextWave)-1) 
	return PopupUserString
End

Function ShowMyPanel()
	DoWindow/F RamanDataBaseExplorer
	if( V_Flag == 0 )
		//PauseUpdate; Silent 1		// building window...
		NewPanel /W=(390,54,1495,998)/K=1
		DoWindow/C RamanDataBaseExplorer
		//ShowTools/A
		
		//PopupMenu UserPopup,mode=2,popvalue="Omer  Yaffe",value= #"\"Netanela Cohen;Omer Yaffe;Matan Menahem;Roman Korobko;Lior Segev;Maor Asher\""
		ListBox list0,pos={10.00,43.00},size={438,146.00},proc=ListBoxProc
		ListBox list0,listWave=root:listbox2dtextwave
		ListBox list0,titleWave=root:ExperimentListBoxTitles,mode= 1,selRow= 4
		Button MoveWavesTo title="Move Data To",proc=MoveDataToFolderButProc
		Button MoveWavesTo pos={19,525}
		Button MoveWavesTo size={103,20}
		
		WC_WindowCoordinatesRestore("RamanDataBaseExplorer")
		SetWindow RamanDataBaseExplorer hook(myHook)=MyWindowHook
		
		// Create Raman Application Folder
		SetDataFolder root:
		NewDataFolder/O AppData
		SetDataFolder AppData
		
		Make/O/T/N = 1 FolderDataName 
		SetVariable DataFolderCtrl value=FolderDataName[0]
		SetVariable DataFolderCtrl pos={145,525}
		SetVariable DataFolderCtrl size={200,18}
		
		// Load Popup box text
		String connectionStr = GetWMDemoConnectionString()
		// present Experiment list in a list box
		string statement = "SELECT Name, Surname, idUsers FROM ramanmeas.users "
		SQLHighLevelOp /CSTR={connectionStr,SQL_DRIVER_COMPLETE} /E=0 /O statement ///MFL=10000000
		PopupMenu UserPopup,pos={16.00,18.00},size={107.00,19.00},proc=PopMenuProc,title="User"
		PopupMenu UserPopup value=CreatePopUserString(root:AppData:Name, root:AppData:Surname)
		
	endif
End

Macro UpdateExperimentListUI(UserIndex)
	variable UserIndex
	
	String connectionStr = GetWMDemoConnectionString()
	// present Experiment list in a list box
	string statement = "SELECT idMeasConf, RangeUnits, ExperimentTitle, StartDateTime, WavelengthsArray, WavelengthsArraySize FROM ramanmeas.meas_conf "
	statement += "WHERE idUsers =" + num2str(idUsers(UserIndex)) +";"
	SQLHighLevelOp /CSTR={connectionStr,SQL_DRIVER_COMPLETE} /E=0 /O statement ///MFL=10000000
	
	Make/O/T/N = (numpnts(ExperimentTitle),3) listbox2dtextwave 
	MakeTextWaveofDateAndTime( StartDateTime )
	if (numpnts(ExperimentTitle) > 0)
		Make/O/T/N = (numpnts(ExperimentTitle)) ExperimentNumberTextwave = num2str(idMeasConf)
		listbox2dtextwave[][0] = ExperimentNumberTextwave[p]
		listbox2dtextwave[][1] = ExperimentTitle[p]
		listbox2dtextwave[][2] = DateTimeWaveString[p]
		Make/O/T/N=(3) ExperimentListBoxTitles = {"Experiment Number", "Experiment Title", "Date & Time"}
	endif
	ListBox list0, proc=ListBoxProc, titleWave=ExperimentListBoxTitles,pos={17.00,43.00},size={438.00,146.00},listWave=root:AppData:listbox2dtextwave
	Make/O/T/N = (11,2) listboxSpectroStatus2dtextwave 
	ListBox list1,proc=ListBoxProc_1, titleWave=StatusListBoxTitles,pos={17.00,212.00},size={438.00,300.00},listWave=root:AppData:listboxSpectroStatus2dtextwave
	
EndMacro

Function MyWindowHook(hs)
	STRUCT WMWinHookStruct &hs
	
	strswitch(hs.eventName)
		case "kill":
			WC_WindowCoordinatesSave(hs.winName)
			break
	endswitch
	return 0
End

Function PopMenuProc(pa) : PopupMenuControl
	STRUCT WMPopupAction &pa

	switch( pa.eventCode )
		case 2: // mouse up
			Variable popNum = pa.popNum
			String popStr = pa.popStr
			String MacroCommandStr 
			sprintf MacroCommandStr, "UpdateExperimentListUI(%d)", popNum-1
			execute MacroCommandStr
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function MakeTextWaveofDateAndTime( DateTimeWave )
	wave DateTimeWave
	variable i
	
	Make/O/T/N=(numpnts(DateTimeWave)) DateTimeWaveString
	
	for(i = 0 ; i<numpnts(DateTimeWave) ; i+=1)	
			DateTimeWaveString[i] = secs2date(DateTimeWave[i], -1) + " " + secs2time(DateTimeWave[i], -1)
	endfor					
	
End

Macro UpdateGraphUI(ExperimentIndex)
	variable ExperimentIndex
	variable arraySize
	
	
	// First Kill the graph window to permit the killing of the waves
	killwindow /Z RamanDataBaseExplorer#GraphControl
	killwindow /Z RamanDataBaseExplorer#MicroscopeImage
	
	String connectionStr = GetWMDemoConnectionString()
	// present Experiment list in a list box
	string statement = "SELECT SpectrometerCountsData,XCoorRequestedPixel, YCoorRequestedPixel FROM ramanmeas.meas_data  "
	statement += "WHERE idMeasConf = " + num2str(idMeasConf(ExperimentIndex)) +";"
	SQLHighLevelOp /CSTR={connectionStr,SQL_DRIVER_COMPLETE} /E=0 /O statement ///MFL=10000000
	arraySize = WavelengthsArraySize(ExperimentIndex)
	// Get the y axis (SpectrometerCounts)

	RedimensionSpectrometerCounts(SpectrometerCountsData, ExperimentIndex, arraySize, ExperimentTitle, idMeasConf )			
	
	// Get the x axis (wavelengths)
	Make/O/T/N=(1) WavelengthArrayString = wavelengthsarray(ExperimentIndex)
	SQLTextWaveToBinaryWaves(WavelengthArrayString, "wavelengthsarrayB")
   Redimension/D/E=2/N=(arraySize) wavelengthsarrayB0
   string TempXtitle = "X_" + ExperimentTitle(ExperimentIndex) + "_" + num2str(idMeasConf(ExperimentIndex))
  	rename wavelengthsarrayB0 $TempXtitle
  
   // Append data to graph
   AppendSpectrometerDataIntoGraph(numpnts(SpectrometerCountsData), Y_text_wave, TempXtitle, RangeUnits[0])
   
   // Create the image file!
   // Get the image data from data base
   statement = "SELECT idsample_type, idMeas_script, idmeas_setup, idObjectives, FrontEntranceSlit, Detector, GratingUnits, Grating, Accumulation, AcquisitionUnit, AcquisitionTime, MicroscopeImage, LaserCoorX, LaserCoorY FROM ramanmeas.meas_conf  "
	statement += "WHERE idMeasConf = " + num2str(idMeasConf(ExperimentIndex)) +";"
	SQLHighLevelOp /CSTR={connectionStr,SQL_DRIVER_COMPLETE} /E=0 /O statement ///MFL=10000000
	SQLTextWaveToBinaryWaves(microscopeimage, "microscopeimageB")

	// Write image data into file
	deletefile "C:/temp/temp1.jpg"
	variable refNum
   open refNum as "C:/temp/temp1.jpg"
   FBinWrite refNum, microscopeimageB0
	close refNum
    
   // Loading image file to image control
   ImageLoad/Z/O/T=jpeg/Q "C:temp:temp1.jpg"
   if (V_flag > 0)
   		Display/W=(458,44,1077,570)/HOST=# 
 		AppendImage 'temp1.jpg'
		ModifyImage 'temp1.jpg' ctab= {*,*,Grays,0}
		ModifyGraph mirror=0
		SetAxis/A/R left
		RenameWindow #,MicroscopeImage
		
   
   		// Get Map points from database
		// Append points to graph
		AppendToGraph /W=RamanDataBaseExplorer#MicroscopeImage YCoorRequestedPixel vs XCoorRequestedPixel 
		ModifyGraph /W=RamanDataBaseExplorer#MicroscopeImage mode(YCoorRequestedPixel)=3
		
		AddTags2PointsInImage()
	
		// Append Last point to graph
		AppendToGraph /W=RamanDataBaseExplorer#MicroscopeImage LaserCoorY vs LaserCoorX 
		ModifyGraph /W=RamanDataBaseExplorer#MicroscopeImage mode(LaserCoorY)=3,marker(LaserCoorY)=19
		// Laser Point
		string tagString = "tag" + num2str(numpnts(YCoorRequestedPixel))	
		Tag/C/N=$tagString/L=3 LaserCoorY, 0, "Laser"
		SetActiveSubwindow ##
	else
		killwindow /Z RamanDataBaseExplorer#MicroscopeImage
	endif
	
	// Get map script name from database
	statement = "SELECT MeasurementsetupName FROM ramanmeas.meas_setup  "
	statement += "WHERE idmeas_setup = " + num2str(idmeas_setup(0)) +";"
	SQLHighLevelOp /CSTR={connectionStr,SQL_DRIVER_COMPLETE} /E=0 /O statement ///MFL=10000000
	
	// Get Objective mag and Model
	statement = "SELECT Magnification, Micronsperpixels, ModelNumber, Manufacturer FROM ramanmeas.objectives  "
	statement += "WHERE idObjectives = " + num2str(idObjectives(0)) +";"
	SQLHighLevelOp /CSTR={connectionStr,SQL_DRIVER_COMPLETE} /E=0 /O statement ///MFL=10000000
	
	// Get Script name
	statement = "SELECT MeasScriptName FROM ramanmeas.meas_script  "
	statement += "WHERE idMeas_script = " + num2str(idMeas_script(0)) +";"
	SQLHighLevelOp /CSTR={connectionStr,SQL_DRIVER_COMPLETE} /E=0 /O statement ///MFL=10000000
	
	// Get Camera Model
	statement = "SELECT Model FROM ramanmeas.cameras  "
	statement += "WHERE idMeas_setup = " + num2str(idMeas_setup(0)) +";"
	SQLHighLevelOp /CSTR={connectionStr,SQL_DRIVER_COMPLETE} /E=0 /O statement ///MFL=10000000
	
	// Get sample type
	statement = "SELECT SampleTypeName FROM ramanmeas.sample_type  "
	statement += "WHERE idsample_type = " + num2str(idsample_type(0)) +";"
	SQLHighLevelOp /CSTR={connectionStr,SQL_DRIVER_COMPLETE} /E=0 /O statement ///MFL=10000000
	

	Make/O/T/N = (11,2) listboxSpectroStatus2dtextwave 
	listboxSpectroStatus2dtextwave[0][0] = "Acquisition (s):"
	listboxSpectroStatus2dtextwave[1][0] = "Accumulations:"
	listboxSpectroStatus2dtextwave[2][0] = "Grating:"
	listboxSpectroStatus2dtextwave[3][0] = "Front entrance slit (micron):"
	listboxSpectroStatus2dtextwave[4][0] = "Detector:"
	listboxSpectroStatus2dtextwave[5][0] = "Setup:"
	listboxSpectroStatus2dtextwave[6][0] = "Objective Magnification and Model:"
	listboxSpectroStatus2dtextwave[7][0] = "Scale (micron/pixel):"
	listboxSpectroStatus2dtextwave[8][0] = "Script:"
	listboxSpectroStatus2dtextwave[9][0] = "Camera Model:"
	listboxSpectroStatus2dtextwave[10][0] = "Sample type:"
	
	listboxSpectroStatus2dtextwave[0][1] = num2str(AcquisitionTime[0]) + " " + AcquisitionUnit[0]
	listboxSpectroStatus2dtextwave[1][1] = num2str(Accumulation[0])
	listboxSpectroStatus2dtextwave[2][1] = num2str(Grating[0]) + " (" + GratingUnits[0] + ")"  
	listboxSpectroStatus2dtextwave[3][1] = num2str(FrontEntranceSlit[0]) + " microns"
	listboxSpectroStatus2dtextwave[4][1] = Detector[0]
	listboxSpectroStatus2dtextwave[5][1] = MeasurementsetupName[0]
	listboxSpectroStatus2dtextwave[6][1] = Magnification[0] +" " + Manufacturer[0] + " " + ModelNumber[0]
	listboxSpectroStatus2dtextwave[7][1] = num2str(Micronsperpixels[0])
	listboxSpectroStatus2dtextwave[8][1] = MeasScriptName[0]
	listboxSpectroStatus2dtextwave[9][1] = Model[0]
	listboxSpectroStatus2dtextwave[10][1] = SampleTypeName[0]
	
	Make/O/T/N=(3) StatusListBoxTitles = {"Parameter", "Value"}
	
	
EndMacro


Function RedimensionSpectrometerCounts(SpectrometerCountsData, ExperimentIndex, arraySize, ExperimentTitle, idMeasConf )
	wave idMeasConf
	wave/T ExperimentTitle
	wave/T SpectrometerCountsData
	variable ExperimentIndex
	variable arraySize
	variable i
	
	KillAllSpectrometerCountsWaves()
	
	make/O/T/N=(numpnts(SpectrometerCountsData)) Y_text_wave
	//theList = WaveList("*",";","")
   //nt = ItemsInList(theList)
	//StringFromList(ic,theList)
	
	// Create text wave object that will hold all Y values according to this template
	// Y_ExperimentTitle_ExperimentNumber_ExperimentPoint
	string TempYtitle
	
	SQLTextWaveToBinaryWaves(SpectrometerCountsData, "SpectrometerCountsDataB")
   string SpectrometerCountsRef

   for(i=0;i < numpnts(SpectrometerCountsData) ; i+=1)
   		SpectrometerCountsRef = "SpectrometerCountsDataB" + num2str(i)
   		Redimension/D/E=2/N=(arraySize) $SpectrometerCountsRef
   		TempYtitle = "Y_" + ExperimentTitle(ExperimentIndex) + "_" + num2str(idMeasConf(ExperimentIndex)) + "_" + num2str(i+1)
		rename $SpectrometerCountsRef $TempYtitle
		Y_text_wave[i] = TempYtitle
   endfor	
	

End


Function KillAllSpectrometerCountsWaves()
	variable i 

	string WavesStartingwithY = WaveList("Y_*",";","")
	string WavesStartingwithX = WaveList("X_*",";","")
	
	for(i = 0 ;i < ItemsInList(WavesStartingwithY); i+=1)	
	 	killwaves /Z $(StringFromList(i, WavesStartingwithY))
	endfor
	
	for(i = 0 ;i < ItemsInList(WavesStartingwithX); i+=1)	
	 	killwaves /Z $(StringFromList(i, WavesStartingwithX))
	endfor	
	 						
End


Function AppendSpectrometerDataIntoGraph(NumberExperimentsPoints, Y_text_wave, TempXtitle, RangeUnits)
	wave/T Y_text_wave
   string TempXtitle
   variable NumberExperimentsPoints 
   string RangeUnits 
   string SpectrometerCountsRef
 	variable i
 	
    // Display Data in Graph
 
   	Display/W=(10,578,1077,932)/HOST=# 
 
   	ModifyGraph frameStyle=1
	RenameWindow #,GraphControl
	for(i=0;i < NumberExperimentsPoints ; i+=1)
   		SpectrometerCountsRef = Y_text_wave[i]
   		AppendToGraph /W=RamanDataBaseExplorer#GraphControl $SpectrometerCountsRef vs $TempXtitle	
   		ModifyGraph rgb($SpectrometerCountsRef)=(abs(enoise(64000,1)),abs(enoise(64000,1)),abs(enoise(64000,1)))
   endfor	
	Legend/C/N=text0
	Label /W=RamanDataBaseExplorer#GraphControl left "Counts";DelayUpdate
   	Label /W=RamanDataBaseExplorer#GraphControl bottom "Wave (" + RangeUnits + ")"
   SetActiveSubwindow ##
End

Function AddTags2PointsInImage()
	// Attach annotations to each point
	string tagString = "tag"
	variable i
	
	// All Map points
	for(i = 0;i < numpnts(YCoorRequestedPixel); i+=1)
		tagString = "tag" + num2str(i)	
		Tag/C/N=$tagString/L=3 YCoorRequestedPixel, i, num2str(i+1)	
	endfor						
	
End


Function CopySpecCountsWaves2Folder(FolderRefString, Y_text_wave)
	wave/T FolderRefString
	wave/T Y_text_wave
	//SVAR/Z FolderName = FolderRefString[1]
	string FolderName = FolderRefString[1]
	variable i
	
	string DestFolderandFilename
	
	// Create Folder
	NewDataFolder/O root:$FolderName
	
	// if X wave exists exit function
	// Get wave name
	string WavesStartingwithX = WaveList("X_*",";","")
	string X_wave_string = StringFromList(0, WavesStartingwithX)
	SetDataFolder root:$FolderName
 	string WavesStartingwithXInsub = WaveList(X_wave_string,";","")
 	SetDataFolder root:AppData

 	if(cmpstr(WavesStartingwithXInsub, "")) 
 	  return -1
 	endif
 	
	
	// Copy Waves into folder
	for(i = 0; i < numpnts(Y_text_wave); i+=1 )	
		Duplicate/O $Y_text_wave(i) $Y_text_wave(i)+"T"
		DestFolderandFilename = "root:" + FolderName + ":" + Y_text_wave(i)
   		Movewave $Y_text_wave(i)+"T", $DestFolderandFilename
	endfor						

	// Copy the x wave
	Duplicate/O $StringFromList(0, WavesStartingwithX) $(X_wave_string +"T")
	DestFolderandFilename = "root:" + FolderName + ":" + X_wave_string
	Movewave $(X_wave_string +"T"), $DestFolderandFilename
	
End

Function ListBoxProc(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave
	String MacroCommandStr
	sprintf MacroCommandStr, "UpdateGraphUI(%d)", row
	
	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			break
		case 3: // double click
			break
		case 4: // cell selection
			execute MacroCommandStr
		case 5: // cell selection plus shift key
			break
		case 6: // begin edit
			break
		case 7: // finish edit
			break
		case 13: // checkbox clicked (Igor 6.2 or later)
			break
	endswitch

	return 0
End

Function MoveDataToFolderButProc(ba) : ButtonControl
	STRUCT WMButtonAction &ba

	switch( ba.eventCode )
		case 2: // mouse up
			CopySpecCountsWaves2Folder(FolderDataName, Y_text_wave)
			break
		case -1: // control being killed
			break
	endswitch

	return 0
End

Function ListBoxProc_1(lba) : ListBoxControl
	STRUCT WMListboxAction &lba

	Variable row = lba.row
	Variable col = lba.col
	WAVE/T/Z listWave = lba.listWave
	WAVE/Z selWave = lba.selWave

	switch( lba.eventCode )
		case -1: // control being killed
			break
		case 1: // mouse down
			break
		case 3: // double click
			break
		case 4: // cell selection
		case 5: // cell selection plus shift key
			break
		case 6: // begin edit
			break
		case 7: // finish edit
			break
		case 13: // checkbox clicked (Igor 6.2 or later)
			break
	endswitch

	return 0
End