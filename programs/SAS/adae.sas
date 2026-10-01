/*------------------------------------------------------------------------------
  Program  : adae.sas
  Purpose  : Create ADAE - independent SAS programming for QC of adae.R
  Input    : sdtm.ae, adam.adsl
  Output   : adam.adae, data/adam/sas/adae.xpt
  Spec     : docs/adam_specs.md
  Author   : Basil E
  Note     : run 00_setup.sas and adsl.sas first
------------------------------------------------------------------------------*/

proc sort data=sdtm.ae out=ae; by usubjid aeseq; run;

data adae1;
  merge ae(in=a keep=studyid usubjid aeseq aeterm aedecod aebodsys aesev aeser
                     aerel aestdtc aeendtc)
        adam.adsl(in=b keep=usubjid trtsdt trtedt trt01a trt01an saffl);
  by usubjid;
  if a;

  length trta $40 astdtf $1 trtemfl $1;
  trta  = trt01a;
  trtan = trt01an;

  /* AE start date. partial dates are imputed to the 1st of the month (D) or
     1st Jan (M), but moved up to TRTSDT if first dose falls in that period */
  select (length(aestdtc));
    when (10) astdt = input(aestdtc, yymmdd10.);
    when (7) do;
      astdt  = input(cats(aestdtc, '-01'), yymmdd10.);
      maxdt  = intnx('month', astdt, 0, 'end');
      astdtf = 'D';
    end;
    when (4) do;
      astdt  = mdy(1, 1, input(aestdtc, 4.));
      maxdt  = mdy(12, 31, input(aestdtc, 4.));
      astdtf = 'M';
    end;
    otherwise;
  end;
  if astdtf ne '' and not missing(trtsdt) then do;
    if astdt < trtsdt <= maxdt then astdt = trtsdt;
  end;

  aendt = input(aeendtc, ?? yymmdd10.);

  /* study day, no day 0 */
  if nmiss(astdt, trtsdt) = 0 then astdy = astdt - trtsdt + (astdt >= trtsdt);
  if nmiss(aendt, trtsdt) = 0 then aendy = aendt - trtsdt + (aendt >= trtsdt);

  /* treatment emergent: on/after first dose, up to last dose + 30 days */
  if nmiss(trtsdt, astdt) = 0 then do;
    if astdt >= trtsdt and (missing(trtedt) or astdt <= trtedt + 30) then trtemfl = 'Y';
  end;

  format astdt aendt date9.;
  drop maxdt trt01a trt01an;
run;

/* first occurrence of each PT per subject, TEAEs only */
proc sort data=adae1(where=(trtemfl = 'Y')) out=teae;
  by usubjid aebodsys aedecod astdt aeseq;
run;

data first_pt;
  set teae;
  by usubjid aebodsys aedecod astdt aeseq;
  length aoccpfl $1;
  if first.aedecod then do;
    aoccpfl = 'Y';
    output;
  end;
  keep usubjid aeseq aoccpfl;
run;

proc sort data=first_pt; by usubjid aeseq; run;

data adam.adae(label='Adverse Events Analysis Dataset');
  merge adae1 first_pt;
  by usubjid aeseq;
  label astdt   = 'Analysis Start Date'
        astdtf  = 'Analysis Start Date Imputation Flag'
        aendt   = 'Analysis End Date'
        astdy   = 'Analysis Start Relative Day'
        aendy   = 'Analysis End Relative Day'
        trta    = 'Actual Treatment'
        trtan   = 'Actual Treatment (N)'
        trtemfl = 'Treatment Emergent Analysis Flag'
        aoccpfl = '1st Occurrence within PT Flag';
run;

/* checks */
proc freq data=adam.adae;
  tables astdtf trtemfl aoccpfl / missing;
run;

proc print data=adam.adae(where=(astdtf ne ''));
  var usubjid aestdtc trtsdt astdt astdtf;
run;

%write_xpt(lib=adam, ds=adae, path=&root/data/adam/sas);
