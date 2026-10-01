/*------------------------------------------------------------------------------
  Program  : adsl.sas
  Purpose  : Create ADSL - independent SAS programming for QC of adsl.R
  Input    : sdtm.dm, sdtm.ex, sdtm.ds, sdtm.vs
  Output   : adam.adsl, data/adam/sas/adsl.xpt
  Spec     : docs/adam_specs.md
  Author   : Basil E
  Note     : run 00_setup.sas first
------------------------------------------------------------------------------*/

/* first and last exposure dates.
   missing EXENDTC -> use EXSTDTC of the same record */
data ex1;
  set sdtm.ex;
  exstdt = input(exstdtc, ?? yymmdd10.);
  exendt = input(exendtc, ?? yymmdd10.);
  if missing(exendt) then exendt = exstdt;
  format exstdt exendt date9.;
run;

proc sql;
  create table trtdt as
  select usubjid,
         min(exstdt) as trtsdt format=date9.,
         max(exendt) as trtedt format=date9.
  from ex1
  where not missing(exstdt)
  group by usubjid
  order by usubjid;
quit;

/* randomisation date and end of study */
data rand(keep=usubjid randdt)
     eos(keep=usubjid eosdt eosstt dcsreas);
  set sdtm.ds;
  length eosstt $12 dcsreas $40;
  if dsdecod = 'RANDOMIZED' then do;
    randdt = input(dsstdtc, ?? yymmdd10.);
    output rand;
  end;
  else if dscat = 'DISPOSITION EVENT' then do;
    eosdt = input(dsstdtc, ?? yymmdd10.);
    if dsdecod = 'COMPLETED' then eosstt = 'COMPLETED';
    else do;
      eosstt  = 'DISCONTINUED';
      dcsreas = dsdecod;
    end;
    output eos;
  end;
  format randdt eosdt date9.;
run;

proc sort data=rand; by usubjid; run;
proc sort data=eos;  by usubjid; run;

/* baseline weight (VSBLFL=Y) and height (screening) */
proc sql;
  create table bl as
  select usubjid,
         max(case when vstestcd = 'WEIGHT' and vsblfl = 'Y' then vsstresn else . end) as weightbl,
         max(case when vstestcd = 'HEIGHT' and visit = 'SCREENING 1' then vsstresn else . end) as heightbl
  from sdtm.vs
  where vstestcd in ('WEIGHT', 'HEIGHT')
  group by usubjid
  order by usubjid;
quit;

proc sort data=sdtm.dm out=dm; by usubjid; run;

data adam.adsl(label='Subject-Level Analysis Dataset');
  merge dm(in=a) trtdt rand eos bl;
  by usubjid;
  if a;

  length trt01p trt01a $40 agegr1 $5 ittfl saffl $1;

  trt01p = arm;
  trt01a = actarm;
  if      trt01p = 'Placebo'              then trt01pn = 0;
  else if trt01p = 'Xanomeline Low Dose'  then trt01pn = 54;
  else if trt01p = 'Xanomeline High Dose' then trt01pn = 81;
  if      trt01a = 'Placebo'              then trt01an = 0;
  else if trt01a = 'Xanomeline Low Dose'  then trt01an = 54;
  else if trt01a = 'Xanomeline High Dose' then trt01an = 81;

  if nmiss(trtsdt, trtedt) = 0 then trtdurd = trtedt - trtsdt + 1;

  if not missing(age) then do;
    if age < 65 then do;       agegr1 = '<65';   agegr1n = 1; end;
    else if age <= 80 then do; agegr1 = '65-80'; agegr1n = 2; end;
    else do;                   agegr1 = '>80';   agegr1n = 3; end;
  end;

  dthdt = input(dthdtc, ?? yymmdd10.);

  if nmiss(weightbl, heightbl) = 0 then bmibl = weightbl / (heightbl / 100)**2;

  ittfl = ifc(not missing(randdt), 'Y', 'N');
  saffl = ifc(not missing(trtsdt), 'Y', 'N');

  format randdt trtsdt trtedt eosdt dthdt date9.;

  label agegr1   = 'Pooled Age Group 1'
        agegr1n  = 'Pooled Age Group 1 (N)'
        trt01p   = 'Planned Treatment for Period 01'
        trt01pn  = 'Planned Treatment for Period 01 (N)'
        trt01a   = 'Actual Treatment for Period 01'
        trt01an  = 'Actual Treatment for Period 01 (N)'
        randdt   = 'Date of Randomization'
        trtsdt   = 'Date of First Exposure to Treatment'
        trtedt   = 'Date of Last Exposure to Treatment'
        trtdurd  = 'Total Treatment Duration (Days)'
        eosdt    = 'End of Study Date'
        eosstt   = 'End of Study Status'
        dcsreas  = 'Reason for Discontinuation from Study'
        dthdt    = 'Date of Death'
        heightbl = 'Baseline Height (cm)'
        weightbl = 'Baseline Weight (kg)'
        bmibl    = 'Baseline BMI (kg/m2)'
        ittfl    = 'Intent-To-Treat Population Flag'
        saffl    = 'Safety Population Flag';

  keep studyid usubjid subjid siteid age ageu agegr1 agegr1n sex race ethnic
       country arm actarm trt01p trt01pn trt01a trt01an randdt trtsdt trtedt
       trtdurd eosdt eosstt dcsreas dthfl dthdt heightbl weightbl bmibl
       ittfl saffl;
run;

/* checks */
proc freq data=adam.adsl;
  tables trt01p*trt01a ittfl*saffl eosstt*dcsreas / list missing;
run;

%write_xpt(lib=adam, ds=adsl, path=&root/data/adam/sas);
