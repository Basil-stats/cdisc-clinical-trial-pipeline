/*------------------------------------------------------------------------------
  Program  : t_demog.sas
  Purpose  : Table 14.1.1 - Demographic and baseline characteristics
             (safety population, by actual treatment)
  Input    : adam.adsl
  Output   : output/t_demog_sas.rtf
  Author   : Basil E
------------------------------------------------------------------------------*/

/* add a Total group (trt01an = 99) */
data adsl;
  set adam.adsl(where=(saffl = 'Y'));
  output;
  trt01an = 99;
  output;
run;

proc sql noprint;
  select count(distinct usubjid) into :n0  trimmed from adsl where trt01an = 0;
  select count(distinct usubjid) into :n54 trimmed from adsl where trt01an = 54;
  select count(distinct usubjid) into :n81 trimmed from adsl where trt01an = 81;
  select count(distinct usubjid) into :n99 trimmed from adsl where trt01an = 99;
quit;

/* continuous variables ----------------------------------------------------- */
%macro cont(var=, label=, ord=, dp=1, mmdp=1);
  proc means data=adsl noprint nway;
    class trt01an;
    var &var;
    output out=_s n=n mean=mean std=sd median=median min=min max=max;
  run;

  data _c;
    set _s;
    length stat $40 value $25;
    ord = &ord;
    stat = "&label"; sub = 0; value = ''; output;
    sub = 1; stat = 'n';         value = strip(put(n, 8.)); output;
    sub = 2; stat = 'Mean (SD)';
    value = strip(put(mean, 8.&dp)) || ' (' || strip(put(sd, 8.%eval(&dp + 1))) || ')'; output;
    sub = 3; stat = 'Median';    value = strip(put(median, 8.&dp)); output;
    sub = 4; stat = 'Min, Max';
    value = strip(put(min, 8.&mmdp)) || ', ' || strip(put(max, 8.&mmdp)); output;
    keep ord sub stat trt01an value;
  run;

  proc append base=demog data=_c force; run;
%mend cont;

/* categorical variables ---------------------------------------------------- */
%macro cat(var=, label=, ord=, levels=);
  proc freq data=adsl noprint;
    tables trt01an*&var / out=_f(drop=percent);
  run;

  /* shell with every level for every group so zero counts show */
  data _shell;
    length level $40;
    do trt01an = 0, 54, 81, 99;
      sub = 0;
      do level = &levels;
        sub = sub + 1;
        output;
      end;
    end;
  run;

  proc sql;
    create table _c as
    select s.trt01an, s.sub, s.level as stat length=40,
           coalesce(f.count, 0) as n,
           case s.trt01an when 0 then &n0 when 54 then &n54
                          when 81 then &n81 else &n99 end as bign
    from _shell as s left join _f as f
      on s.trt01an = f.trt01an and s.level = f.&var
    order by s.trt01an, s.sub;
  quit;

  data _c;
    set _c;
    length value $25;
    ord = &ord;
    value = put(n, 3.) || ' (' || put(100 * n / bign, 5.1) || ')';
    output;
    if sub = 1 then do;
      sub = 0; stat = "&label, n (%)"; value = ''; output;
    end;
    keep ord sub stat trt01an value;
  run;

  proc append base=demog data=_c force; run;
%mend cat;

proc datasets lib=work nolist nowarn; delete demog; quit;

%cont(var=age,      label=Age (years),          ord=1, mmdp=0);
%cat (var=agegr1,   label=Age group, ord=2, levels=%str('<65', '65-80', '>80'));
%cat (var=sex,      label=Sex,       ord=3, levels=%str('F', 'M'));
%cat (var=race,     label=Race,      ord=4,
      levels=%str('WHITE', 'BLACK OR AFRICAN AMERICAN', 'AMERICAN INDIAN OR ALASKA NATIVE'));
%cont(var=weightbl, label=Baseline weight (kg),  ord=5);
%cont(var=heightbl, label=Baseline height (cm),  ord=6);
%cont(var=bmibl,    label=Baseline BMI (kg/m2),  ord=7);

proc sort data=demog; by ord sub stat; run;

proc transpose data=demog out=demog_t(drop=_name_) prefix=trt;
  by ord sub stat;
  id trt01an;
  var value;
run;

/* report ------------------------------------------------------------------- */
options orientation=landscape nodate nonumber;
ods rtf file="&root/output/t_demog_sas.rtf" style=journal;

title1 j=l 'Table 14.1.1';
title2 j=l 'Demographic and Baseline Characteristics';
title3 j=l 'Safety Population';
footnote1 j=l 'Percentages are based on the number of subjects in each treatment group.';
footnote2 j=l 'Source: ADSL. Program: programs/SAS/t_demog.sas';

proc report data=demog_t nowd split='|' style(report)=[width=100%];
  column ord sub stat trt0 trt54 trt81 trt99;
  define ord   / order noprint;
  define sub   / order noprint;
  define stat  / display '' style(column)=[width=34% asis=on];
  define trt0  / display "Placebo|(N=&n0)"              center;
  define trt54 / display "Xanomeline Low Dose|(N=&n54)"  center;
  define trt81 / display "Xanomeline High Dose|(N=&n81)" center;
  define trt99 / display "Total|(N=&n99)"                center;
  compute stat;
    if sub > 0 then stat = '   ' || stat;
  endcomp;
run;

ods rtf close;
title; footnote;
