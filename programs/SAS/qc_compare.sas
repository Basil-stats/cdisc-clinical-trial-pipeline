/*------------------------------------------------------------------------------
  Program  : qc_compare.sas
  Purpose  : Double-programming QC - compare SAS ADaM datasets (adam.*) with
             the R versions (data/adam/*.xpt)
  Output   : qc/qc_compare_sas.pdf
  Author   : Basil E
  Note     : run 00_setup.sas, adsl.sas, adae.sas, adtte.sas first.
             Target result: "No unequal values were found" for each dataset.
             Length/label/format differences are reported but are not
             value differences.
------------------------------------------------------------------------------*/

%read_xpt(lib=radam, ds=adsl,  path=&root/data/adam);
%read_xpt(lib=radam, ds=adae,  path=&root/data/adam);
%read_xpt(lib=radam, ds=adtte, path=&root/data/adam);

%macro qc(ds=, id=);
  proc sort data=adam.&ds  out=sas_&ds; by &id; run;
  proc sort data=radam.&ds out=r_&ds;   by &id; run;

  title "QC: %upcase(&ds) - SAS (base) vs R (compare)";
  proc compare base=sas_&ds compare=r_&ds listall
               method=absolute criterion=1e-8 maxprint=(50, 500);
    id &id;
  run;
  title;
%mend qc;

ods pdf file="&root/qc/qc_compare_sas.pdf";

%qc(ds=adsl,  id=usubjid);
%qc(ds=adae,  id=usubjid aeseq);
%qc(ds=adtte, id=usubjid paramcd);

ods pdf close;
