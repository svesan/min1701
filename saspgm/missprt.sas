options source;
%macro missprt(data=, var=, tit=Y, nomiss=Y, delete=Y, sort=Y, valid=, obs=) /des='SS macro MISSPRT. Prinout of missing distribution';

  %local var2 i _slask0_ _slask1_ _slask2_ _slask3_ _slask4_ _slask5_;

  %ssutil(___mn___=MISSPRT, ___mv___=2.0, ___mt___=SS);

  %ssutil(_yesno_=tit delete nomiss, _oblig_=data tit, _upcase_=data);
  %if &__err__=ERROR %then %goto exit2;

  %ssutil(__dsn__=&data, _exist_=Y);
  %if &__err__=ERROR %then %goto exit2;

  *-- libname and dataset name in different macro variables ;
  %let _slask2_=%scan(&data,1,'.');
  %let _slask3_=%scan(&data,2,'.');

  %if "&_slask3_" eq "" %then %do;
    %let _slask3_=&_slask2_;
    %let _slask2_=WORK;
  %end;

  options nonotes;

  *-- If VAR not specified run the macro on all the dataset variables ;
  %if "&var" ne "" %then %do;
    %ssutil(__dsn__=&data, __lst__=&var, _vexist_=Y, _vtype_=NUM, ___mc___=&var);
    %if &__err__=ERROR %then %goto exit2;
  %end;
  %else %do;
    %put Note: VAR blank and will be assigned all numeric variables.;

    proc sql;
      create table __m4__ as select name, type
      from dictionary.columns
      where libname="&_slask2_" and memname="&_slask3_";
    quit;
    data _null_;
      length slask1 slask2 $32767 _nmvar_ 5;
      retain slask1 slask2 '' _nmvar_ 0;
      set __m4__ end=eof;
      if type='num' then do;
        slask1=trim(left(slask1))||' '||trim(left(name));
        _nmvar_=_nmvar_+1;
      end;
      else slask2=trim(left(slask2))||' '||trim(left(name));
      if eof then do;
        call symput('var',left(trim(slask1)));
        call symput('_nmvar_',compress(put(_nmvar_,8.)));
        call symput('_slask5_',left(trim(slask2)));
      end;
    run;


    %if %bquote(&var)= %then %do;
      %put Note: There were no numeric variables in dataset &data;

      %if %bquote(&_slask5_)= %then %do;
        %put Note: The following character variables are defined for dataset &data.. Macro aborts.;
        %put %str(     ) &_slask5_;
      %end;

      %goto exit2;
    %end;

    %put Note: The following numeric variables were assigned to the VAR parameter;
    %put %str(     ) &var;
    %if %bquote(&_slask5_)^= %then %do;
      %put Note: The following character variables are defined for dataset &data (and not assigned to the VAR parameter);
      %put %str(     ) &_slask5_;
    %end;

  %end;


  %ssutil(___mc___=&var);

  *-- First save options to be reset at then end ;
  proc sql noprint;
    create table __m0__ as
    select setting
    from dictionary.options where optname in ('SOURCE','FMTERR');
  quit;
  options nosource nofmterr;


  %if "&valid" ne "" %then %do;
    %put Note: The missing codes &valid are considered valid and not calculated as missing;
    data _null_;
      length a $40;
      a='not in ('||tranwrd(trim(upcase(compbl("&valid"))),' ',',')||')';
      b='in ('||tranwrd(trim(upcase(compbl("&valid"))),' ',',')||')';
      call symput('valid',a);
      call symput('_slask0_',b);
    run;
  %end;


  *-- Local copy of the dataset needed since labels will be updated ;
  proc sql noprint;
    %if "&valid"="" %then %do;
      create table __m1__ as
      select *
      from &data(keep=&var
                 where=(%do i=1 %to %eval(&_nmvar_-1);
                         ( %scan(&var,&i,' ') le .z ) or
                        %end;
                        ( %scan(&var,&_nmvar_,' ') le .z) )) ;
    %end;
    %else %do;
      create table __m1__ as
      select *
      from &data(keep=&var
                 where=(%do i=1 %to %eval(&_nmvar_-1);
                         ( %scan(&var,&i,' ') le .z and %scan(&var,&i,' ') &valid) or
                        %end;
                        ( %scan(&var,&_nmvar_,' ') le .z) )) ;

    %end;


    select nobs into : _slask1_ from dictionary.tables where libname='WORK' and memname='__M1__';
  quit;


  %if &_slask1_=0 %then %do;
    %put Note: There were no missing values. Macro aborts.;
    %goto exit;
  %end;

  *-- Recode valid missing codes (VALID=) to -99 ;
  %if "&valid" ne "" %then %do;
    data __m1b__;
      set __m1__;
      %do i=1 %to &_nmvar_;
        if %scan(&var,&i,' ') &_slask0_ then %scan(&var,&i,' ') = -99;
      %end;
    run;
  %end;
  %else %do;
    proc sql;
      create table __m1b__ as select * from __m1__;
    quit;
  %end;


  *-- No of missing values for each variable;
  proc summary data=__m1b__;
    var &var;
    output out=__m2__(keep=&var) nmiss=&var;
  run;

  *-- Sort the variables in the order of the magnitude of missing values;
  proc transpose data=__m2__ out=__m3__;
    var &var;
  run;
  proc sort data=__m3__;by descending col1;run;

  *-- Create new macro variable with the variables in the order of missing values;
  data _null_;
    length var2 $1000;
    retain var2 '';
    set __m3__ end=eof;
    if not ("&nomiss"="N" and col1=0) then var2=left(trim(var2))||' '||left(trim(_name_));
    if eof then call symput('var2',trim(var2));
  run;


  *-- Add the missing values information to the variable labels;
  options nosource;
  data _null_;
    set __m3__ end=eof;
    if _n_=1 then call execute('proc datasets lib=work mt=data nolist;modify __m1__; label ');
    call execute(trim(_name_)||"='"||trim(_name_)||"£[nmiss="||compress(put(col1,8.))||"]' ");
    if eof then call execute(';quit;');
  run;

  *-- No of obs in DATA dataset for printout ;

  proc sql noprint;
    select nobs into : _slask4_ from dictionary.tables where libname="&_slask2_" and memname="&_slask3_";
  quit;
  %let _slask4_=&_slask4_;

  %if "&tit"="Y" %then title1 "Missing configuration on dataset &data.(N=&_slask4_). Amount of missing values within brackets.";;

  %if "&sort"="Y" %then %str(proc sort data=__m1__;by &var2;run;);

  %if "&obs" ne "" %then %let obs=(obs=&obs);

  proc print data=__m1__&obs label split='£';
    var &var2;
  run;

  %EXIT:
  data _null_;
    set __m0__ end=eof;
    if _n_=1 then call execute('options ');
    call execute(trim(setting));
    if eof then call execute(';');
  run;

  %if "&delete"="Y" %then %do;
    proc datasets lib=work mt=data nolist;
      delete __m0__ __m1b__ __m1__ __m2__ __m3__ __m4__;
    quit;
  %end;

  %EXIT2:
    %if "&tit"="Y" %then title;;
    %put Note: Macro MISSPRT finished execution; %put ;
    options notes;

%mend;
options nosource;

%missprt(data=t7, var=pgf_age pgm_age mgf_age mgm_age cid cid_sex cid_dob);
