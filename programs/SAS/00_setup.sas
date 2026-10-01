/*------------------------------------------------------------------------------
  Program  : 00_setup.sas
  Purpose  : Paths, libraries and SDTM import. Run this first in every session.
  Notes    : Written for SAS OnDemand for Academics (SAS Studio). Upload the
             project folder to your home directory and change ROOT below.
  Author   : Basil E
------------------------------------------------------------------------------*/

%let root = /home/u00000000/cdisc-clinical-trial-pipeline;   /* <-- change */

options dlcreatedir nofmterr validvarname=upcase;

libname sdtm  "&root/data/sdtm/sas";     /* SDTM converted from xpt   */
libname adam  "&root/data/adam/sas";     /* ADaM created by SAS       */
libname radam "&root/data/adam/r";       /* ADaM created by R, for QC */

/* read one transport file into a library */
%macro read_xpt(lib=, ds=, path=);
  libname _x xport "&path/&ds..xpt";
  proc copy inlib=_x outlib=&lib;
  run;
  libname _x clear;
%mend read_xpt;

/* write one dataset out as a transport file */
%macro write_xpt(lib=, ds=, path=);
  libname _x xport "&path/&ds..xpt";
  proc copy inlib=&lib outlib=_x memtype=data;
    select &ds;
  run;
  libname _x clear;
%mend write_xpt;

%read_xpt(lib=sdtm, ds=dm, path=&root/data/sdtm);
%read_xpt(lib=sdtm, ds=ex, path=&root/data/sdtm);
%read_xpt(lib=sdtm, ds=ds, path=&root/data/sdtm);
%read_xpt(lib=sdtm, ds=ae, path=&root/data/sdtm);
%read_xpt(lib=sdtm, ds=vs, path=&root/data/sdtm);
