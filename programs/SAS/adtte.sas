/*------------------------------------------------------------------------------
  Program  : adtte.sas
  Purpose  : Create ADTTE (PARAMCD = TTDE, time to first dermatologic event)
             - independent SAS programming for QC of adtte.R
  Input    : adam.adsl, adam.adae
  Output   : adam.adtte, data/adam/sas/adtte.xpt
  Spec     : docs/adam_specs.md
  Author   : Basil E
  Note     : run 00_setup.sas, adsl.sas and adae.sas first
------------------------------------------------------------------------------*/

/* dermatologic TEAEs */
data derm;
  set adam.adae;
  where trtemfl = 'Y' and
        (aebodsys = 'SKIN AND SUBCUTANEOUS TISSUE DISORDERS' or aedecod =: 'APPLICATION SITE');
run;

proc sort data=derm; by usubjid astdt aeseq; run;

data first_derm;
  set derm;
  by usubjid;
  if first.usubjid;
  keep usubjid astdt aeseq;
run;

data adam.adtte(label='Time to Event Analysis Dataset');
  merge adam.adsl(in=a where=(saffl = 'Y')
                  keep=studyid usubjid trtsdt trtedt eosdt trt01a trt01an saffl)
        first_derm(in=e);
  by usubjid;
  if a;

  length paramcd $8 param $40 evntdesc $20 srcdom $8 srcvar $8 trta $40;

  paramcd = 'TTDE';
  param   = 'Time to First Dermatologic Event (Days)';
  startdt = trtsdt;
  trta    = trt01a;
  trtan   = trt01an;

  if e then do;
    adt      = astdt;
    cnsr     = 0;
    evntdesc = 'DERMATOLOGIC EVENT';
    srcdom   = 'ADAE';
    srcvar   = 'ASTDT';
    srcseq   = aeseq;
  end;
  else do;
    /* censor at last dose + 30 days, or end of study if earlier */
    adt      = min(trtedt + 30, eosdt);
    cnsr     = 1;
    evntdesc = 'LAST FOLLOW-UP';
    srcdom   = 'ADSL';
    srcvar   = 'LSTFUDT';
  end;

  aval = adt - startdt + 1;

  format startdt adt date9.;
  label paramcd  = 'Parameter Code'
        param    = 'Parameter'
        aval     = 'Analysis Value'
        cnsr     = 'Censor'
        startdt  = 'Time to Event Origin Date for Subject'
        adt      = 'Analysis Date'
        evntdesc = 'Event or Censoring Description'
        srcdom   = 'Source Data'
        srcvar   = 'Source Variable'
        srcseq   = 'Source Sequence Number'
        trta     = 'Actual Treatment'
        trtan    = 'Actual Treatment (N)';

  keep studyid usubjid paramcd param aval cnsr startdt adt evntdesc srcdom
       srcvar srcseq trta trtan saffl;
run;

/* checks */
proc freq data=adam.adtte;
  tables trta*cnsr / nopercent nocol;
run;

proc means data=adam.adtte n min q1 median mean q3 max;
  var aval;
run;

%write_xpt(lib=adam, ds=adtte, path=&root/data/adam/sas);
