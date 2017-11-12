#pragma rtGlobals=1		// Use modern global access method.

#include <SQLConstants>

Menu "Macros"
	"Fetch Data", SQLHighLevelFetch()
	"Fetch Data With Indicators", SQLHighLevelFetchWithIndicators()
End

Function/S GetWMDemoConnectionString()
	// Uses DSN (Data Source Name) that you previously configured. See SQL Help file for details.
	// In this tutorial we use ensembldb.ensembl.org - a publically-accessible MySQL database that
	// hosts genome information. This database requires that we connect as user 'anonymous'
	// with no password. In real-life, you would use a real user name and password which you
	// would get from the database administrator.
	String connectionStr = "DSN=RamanDataSource;UID=root;PWD=gulliver"
	return connectionStr
End

Function PrintSQLHighLevelDiagnostics(testTitle, flag, SQLResult, rowCount, numWaves, waveNames, diagnostics)
	String testTitle
	Variable flag, SQLResult, rowCount, numWaves
	String waveNames, diagnostics

	// Print output variables
	Printf "%s: V_flag=%d, V_SQLResult=%d, V_SQLRowCount=%d, V_numWaves=%d, S_waveNames=\"%s\"\r", testTitle, flag, SQLResult, rowCount, numWaves, waveNames
	if (strlen(diagnostics) > 0)
		Printf "Diagnostics: %s\r", diagnostics
	endif
End

Function SQLHighLevelFetch()
	String connectionStr = GetWMDemoConnectionString()

	String statement = "Select * from LOGGING"
	SQLHighLevelOp /CSTR={connectionStr,SQL_DRIVER_COMPLETE} /O /E=1 statement
	
	PrintSQLHighLevelDiagnostics(statement, V_flag, V_SQLResult, V_SQLRowCount, V_numWaves, S_waveNames, S_diagnostics)
	
	SQLTextWaveToBinaryWaves(CorePressure, "CorePressureB")
	Redimension/D/E=2/N=100 CorePressureB0, CorePressureB1, CorePressureB2
End

Function SQLHighLevelFetchWithIndicators()		// Loads indicator waves as well as result waves.
	String connectionStr = GetWMDemoConnectionString()

	String statement = "Select * from CHARACTER_SETS"
	SQLHighLevelOp /CSTR={connectionStr,SQL_DRIVER_COMPLETE} /O /E=1 /LIND=1 statement
	
	PrintSQLHighLevelDiagnostics("Select loading indicators", V_flag, V_SQLResult, V_SQLRowCount, V_numWaves, S_waveNames, S_diagnostics)
End
