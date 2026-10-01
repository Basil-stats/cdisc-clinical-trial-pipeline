/*------------------------------------------------------------------------------
  Program  : f_km.sas
  Purpose  : Figure 14.2.1 - Kaplan-Meier plot of time to first dermatologic
             event with number at risk, log-rank test and Cox model
  Input    : adam.adtte
  Output   : output/f_km_sas.png, output/f_km_sas.rtf
  Author   : Basil E
------------------------------------------------------------------------------*/

proc format;
  value trtf 0  = 'Placebo'
             54 = 'Xanomeline Low Dose'
             81 = 'Xanomeline High Dose';
run;

data tte;
  set adam.adtte(where=(paramcd = 'TTDE' and saffl = 'Y'));
run;

ods graphics on / reset imagename='f_km_sas' imagefmt=png width=8in height=6in;
ods listing gpath="&root/output";
ods rtf file="&root/output/f_km_sas.rtf" style=journal;

title1 'Time to First Dermatologic Event - Safety Population';

proc lifetest data=tte plots=survival(atrisk=0 to 210 by 30 test) notable;
  time aval * cnsr(1);
  strata trtan / order=internal;
  format trtan trtf.;
  label aval = 'Days since first dose';
run;

title1 'Cox model - hazard ratio vs placebo';
proc phreg data=tte;
  class trtan(ref='0') / param=ref;
  model aval * cnsr(1) = trtan / risklimits;
  assess ph / resample seed=2026;
run;

ods rtf close;
ods graphics off;
title;
