/*------------------------------------------------------------------------------
  Program  : t_ae.sas
  Purpose  : Table 14.3.1 - Treatment-emergent adverse events by system organ
             class and preferred term (safety population)
  Input    : adam.adsl, adam.adae
  Output   : output/t_ae_sas.rtf
  Author   : Basil E
------------------------------------------------------------------------------*/

/* big N and TEAEs, each with a Total group (trtan = 99) */
data adsl;
  set adam.adsl(where=(saffl = 'Y'));
  trtan = trt01an;
  output;
  trtan = 99;
  output;
  keep usubjid trtan;
run;

data teae;
  set adam.adae(where=(saffl = 'Y' and trtemfl = 'Y'));
  output;
  trtan = 99;
  output;
  keep usubjid trtan aebodsys aedecod;
run;

proc sql noprint;
  create table bign as
  select trtan, count(distinct usubjid) as bign
  from adsl group by trtan;

  select bign into :n0  trimmed from bign where trtan = 0;
  select bign into :n54 trimmed from bign where trtan = 54;
  select bign into :n81 trimmed from bign where trtan = 81;
  select bign into :n99 trimmed from bign where trtan = 99;

  /* subjects counted once per row */
  create table cnt as
  select trtan, 0 as lvl, '' as aebodsys length=200, '' as aedecod length=200,
         count(distinct usubjid) as n
  from teae group by trtan
  union all
  select trtan, 1 as lvl, aebodsys, '' as aedecod, count(distinct usubjid) as n
  from teae group by trtan, aebodsys
  union all
  select trtan, 2 as lvl, aebodsys, aedecod, count(distinct usubjid) as n
  from teae group by trtan, aebodsys, aedecod;
quit;

/* sort order: descending total count for SOC, then PT within SOC */
proc sql;
  create table cnt2 as
  select c.*, coalesce(s.n, 0) as soc_n, coalesce(p.n, 0) as pt_n,
         b.bign
  from cnt as c
       left join cnt(where=(trtan = 99 and lvl = 1)) as s
         on c.aebodsys = s.aebodsys
       left join cnt(where=(trtan = 99 and lvl = 2)) as p
         on c.aebodsys = p.aebodsys and c.aedecod = p.aedecod
       left join bign as b
         on c.trtan = b.trtan;
quit;

data cnt2;
  set cnt2;
  length cell $25 label $200;
  cell = put(n, 3.) || ' (' || put(100 * n / bign, 5.1) || ')';
  if lvl = 0 then do;
    label = 'Subjects with at least one TEAE';
    soc_n = 99999;
  end;
  else if lvl = 1 then do;
    label = aebodsys;
    pt_n = 99999;
  end;
  else label = '   ' || aedecod;
run;

proc sort data=cnt2;
  by descending soc_n aebodsys descending pt_n aedecod label;
run;

proc transpose data=cnt2 out=ae_t(drop=_name_) prefix=trt;
  by descending soc_n aebodsys descending pt_n aedecod label;
  id trtan;
  var cell;
run;

/* a subject can have a SOC/PT in one arm and not another - show zeros */
data ae_t;
  set ae_t;
  array t {*} trt0 trt54 trt81 trt99;
  do i = 1 to dim(t);
    if missing(t{i}) then t{i} = '  0 (  0.0)';
  end;
  rowno = _n_;
  drop i;
run;

/* report ------------------------------------------------------------------- */
options orientation=landscape nodate nonumber;
ods rtf file="&root/output/t_ae_sas.rtf" style=journal;

title1 j=l 'Table 14.3.1';
title2 j=l 'Treatment-Emergent Adverse Events by System Organ Class and Preferred Term';
title3 j=l 'Safety Population';
footnote1 j=l 'TEAE: adverse event starting on or after first dose and up to 30 days after last dose.';
footnote2 j=l 'A subject is counted once per system organ class and once per preferred term.';
footnote3 j=l 'Source: ADAE. Program: programs/SAS/t_ae.sas';

proc report data=ae_t nowd split='|' style(report)=[width=100%];
  column rowno label trt0 trt54 trt81 trt99;
  define rowno / order noprint;
  define label / display 'System Organ Class|   Preferred Term'
                 style(column)=[width=40% asis=on];
  define trt0  / display "Placebo|(N=&n0)"              center;
  define trt54 / display "Xanomeline Low Dose|(N=&n54)"  center;
  define trt81 / display "Xanomeline High Dose|(N=&n81)" center;
  define trt99 / display "Total|(N=&n99)"                center;
run;

ods rtf close;
title; footnote;
