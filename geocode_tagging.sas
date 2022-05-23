
/*importing data*/
proc import datafile="LTC_file.xlsx"
	out=ltc
	dbms=EXCEL
	REPLACE;
/*can specify the sheet that you wish to import here*/
/*	sheet="All Facilities";*/
run;
/*anchored dataset*/
proc import datafile="pharm_list.xlsx"
	out=pharm
	dbms=EXCEL
	REPLACE;
/*	sheet="All Facilities";*/
run;

/*importing reference data*/
%let PATHIN=geo_mapping\geocodedata__2019__StreetLookupData_94;
%let PATHOUT=geo_mapping\geocodedata__2019__StreetLookupData_94;

libname lookup "&PATHOUT";

 /* Original source for the lookup data   */
%let source=US Census Bureau TIGER/Line files;
/* Year original data published          */
%let release=2019;

/*--- Set data set names.                                */
%let MDS=USM;   /* First geocoding lookup data set name  */
%let SDS=USS;   /* Second geocoding lookup data set name */
%let PDS=USP;   /* Third geocoding lookup data set name  */

data _null_;
  infile "&PATHIN/ReadMe.txt";
  input;
  if indexc(_infile_, ':') then do;
    if indexw(_infile_, 'Source') then
      /*--- Save data source for data set labels. */
      call symput('source', trim(left(scan(_infile_, -1, ':'))));
    else if indexw(_infile_, "Release") then do;
      /*--- Save release year for data set labels. */
      call symput('release', trim(left(scan(_infile_, -1, ':'))));
      stop;
    end;
  end;
run;

/*--- Import primary lookup data set from CSV file. */
filename csv "&PATHIN/&MDS..csv";
data lookup.&MDS (label="Primary street lookup data for PROC GEOCODE (&source &release)");
  infile csv dlm=',' missover dsd lrecl=32767 termstr=crlf;
  length Name $58 Name2 $51 City $50 City2 $45 MapIDNameAbrv $2;
  input Name $ Name2 $ City $ City2 $ MapIDNameAbrv $ ZIP ZCTA First Last;
  label Name          = 'Street name'
        Name2         = 'Street name (normalized)'
        City          = 'City name'
        City2         = 'City name (normalized)'
        MapIDNameAbrv = 'State abbreviation'
        ZIP           = 'ZIP Code'
        ZCTA          = 'ZIP Code Tabulation Area'
        First         = "First obs in &SDS data set"
        Last          = "Last obs in &SDS data set";
  format zip  z5.
         zcta z5.;
run;

/*--- Import CSV files for second lookup data set. */
filename csv ("&PATHIN/&SDS.1.csv" "&PATHIN/&SDS.2.csv" "&PATHIN/&SDS.3.csv" "&PATHIN/&SDS.4.csv" "&PATHIN/&SDS.5.csv");
data lookup.&SDS (label="Secondary street lookup data for PROC GEOCODE (&source &release)");
  infile csv dlm=',' missover dsd lrecl=32767 termstr=crlf;
  length PreDirAbrv $2 SufDirAbrv $2 PreTypAbrv $14 SufTypAbrv $12 MTFCC $5 Side $1;
  input PreDirAbrv $ SufDirAbrv $ PreTypAbrv $ SufTypAbrv $ TLID MTFCC $ Side $ FromAdd
        ToAdd BlkGrp Block Tract CountyFp N Start;
  label PreDirAbrv = 'Street direction prefix'
        SufDirAbrv = 'Street direction suffix'
        PreTypAbrv = 'Street type prefix'
        SufTypAbrv = 'Street type suffix'
        TLID       = 'TIGER/Line ID'
        MTFCC      = 'MAF/TIGER Feature Class Code'
        Side       = 'Side of street'
        FromAdd    = 'Beginning house number'
        ToAdd      = 'Ending house number'
        Blkgrp     = 'Census 2010 Block Group'
        Block      = 'Census 2010 Block'
        Tract      = 'Census 2010 Tract'
        CountyFp   = 'County FIPS Code'
        N          = "Number of obs in &PDS data set"
        Start      = "First obs in &PDS data set";
run;

/*--- Import CSV files for third lookup data set. */
filename csv ("&PATHIN/&PDS.1.csv" "&PATHIN/&PDS.2.csv" "&PATHIN/&PDS.3.csv" "&PATHIN/&PDS.4.csv");
data lookup.&PDS (label="Third street lookup data for PROC GEOCODE (&source &release)");
  infile csv dlm=',' missover dsd lrecl=32767 termstr=crlf;
  input X Y;
  label X = "Longitude (degrees)"
        Y = "Latitude (degrees)";
run;

/*--- Create indexes of MDS variables used in street method where-clauses. */
proc datasets lib=lookup;
  modify &MDS;
    index create Name2_Zip                 = (Name2 ZIP);                 /* street+zip search */
    index create Name2_Zcta                = (Name2 ZCTA);                /* street+zcta search */
    index create Name2_MapIDNameAbrv_City2 = (Name2 MapIDNameAbrv City2); /* street+city+state search */
  run;
quit;

option nosource;
%put NOTE: PROC GEOCODE lookup data set import is complete.;
%put NOTE: Data sets are compatible with SAS 9.4 and later releases.;
%put NOTE- Data source: &release &source;
%put NOTE- Data sets written to PATHOUT location:;
%put NOTE-   &PATHOUT;
%put NOTE: See the LOOKUPSTREET option in PROC GEOCODE documentation;
%put NOTE- for instructions on geocoding with these data sets.;
option source;

/*checking data for correct columns*/
/*proc print data=riverside_ltc (obs=10);*/
/*run;*/

/*data riverside_ltc; set riverside_ltc;*/
/*	city=FACILITY_CITY;*/
/*	state="CA";*/
/*	zip=FACILITY_ZIP;*/
/*run;*/

data ltc; set ltc;
	city=FACILITY_CITY;
	state="CA";
	zip=FACILITY_ZIP;
run;


proc geocode                                                                                                                            
  method=street              /* street geocoding used here */                                                                                                           
  /* lookup data sets */                                                                                                                
  lookupstreet=lookup.usm    /* preprocessed TIGER lookup data set    */                                                                                
  lookupcity=sashelp.zipcode /* set this if you do not have SAS/GRAPH */                                                                 
  /* input data and variables */                                                                                                        
  data=ltc              /* input data set */                                                                                         
  addressvar=FACILITY_ADDRESS  /* set this if "address" is not the variable name */                                                         
  /* addresscityvar=FACILITY_CITY       /*   set this if "city" is not the variable name    */                                                         
  /* addressstatevar=        /* set this if "state" is not the variable name   */                                                         
  /* addresszipvar=FACILITY_ZIP          /* set this if "zip" is not the variable name     */                                                         
  /* include variables from the lookup.uss data in your output */                                                         
  attributevar=(side)      /* include the side of the street in your output  */                                                         
  out=LTC_ll;            /* output data set */                                                                                        
run;

/*geocoding list*/

/*creating numeric for zip and CA variable*/

data pharm; set pharm;
	state="CA";
	zipnum = input(zip, 5.);
	drop zip;
	rename zipnum=zip;
run;


/*proc contents data=pharm;*/
/*run;*/


/*creating geocoded list*/
proc geocode                                                                                                                            
  method=street              /* street geocoding used here */                                                                                                           
  /* lookup data sets */                                                                                                                
  lookupstreet=lookup.usm    /* preprocessed TIGER lookup data set    */                                                                                
  lookupcity=sashelp.zipcode /* set this if you do not have SAS/GRAPH */                                                                 
  /* input data and variables */                                                                                                        
  data=pharm              /* input data set */                                                                                         
  addressvar=ADDRESS  /* set this if "address" is not the variable name */                                                         
  /* addresscityvar=FACILITY_CITY       /*   set this if "city" is not the variable name    */                                                         
  /* addressstatevar=        /* set this if "state" is not the variable name   */                                                         
  /* addresszipvar=FACILITY_ZIP          /* set this if "zip" is not the variable name     */                                                         
  /* include variables from the lookup.uss data in your output */                                                         
  attributevar=(side)      /* include the side of the street in your output  */                                                         
  out=pharm_ll;            /* output data set */                                                                                        
run;





