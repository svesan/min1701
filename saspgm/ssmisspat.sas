%macro misspat(__func__, data=t1, var=a b c, complete=, event=, print=N, delete=Y, out=,
               outindex=, maxlevel=999, entry=, exit=, personyear=)/des='Printout of missing patterns';

  *---------------------------------------------------------------------------;
  * DATA=........: SAS dataset name                                           ;
  * VAR=.........: List of variabels in DATA. If blank all variable are       ;
  * .............: selected.                                                  ;
  * COMPLETE=....: Output dataset for dataset with no missing data on VAR     ;
  *                variables                                                  ;
  * EVENT=.......: Event 1/0 variable                                         ;
  * PRINT=N......: Print summary table                                        ;
  * DELETE=Y.....: Delete temporary datasets                                  ;
  * OUT=.........: Output dataset of missing patterns                         ;
  * MAXLEVEL=999.: Maximum levels of missing variables to consider            ;
  * ENTRY=.......: Variable in DATA dataset expected. Only meaningful if also ;
  *                EXIT is given, then ENTRY and EXIT should be year (or age) ;
  *                at cohort entry and exit. Alternatively use PERSONYEAR     ;
  *                instead. Default ENTRY is blank.                           ;
  * EXIT=........: Variable in DATA dataset expected. Only meaningful if also ;
  *                ENTRYis given, then ENTRY and EXIT should be year (or age) ;
  *                at cohort entry and exit. Alternatively use PERSONYEAR     ;
  *                instead. Default EXIT is blank.                            ;
  * PERSONYEAR=..: Variable in DATA dataset expected. To contain person year. ;
  *                Optional. Default PERSONYEAR is blank.                     ;
  *                                                                           ;
  *---------------------------------------------------------------------------;
  %if %upcase(&__func__)=HELP %then %do;
    %put ;
    %put %str(----------------------------------------------------------------------------------------------);
    %put %str(Help on the data management macro MISSPAT ver 2.0 at 2005-07-20);
    %put %str(----------------------------------------------------------------------------------------------);
    %put %str(The macro print a list of the different missing patterns in a dataset);
    %put ;
    %put %str(The macro is defined with the following set of parameters:);
    %put %str( );
    %put %str(DATA........= Mandatory. SAS dataset name);
    %put %str(VAR.........= Optional. SAS variables to analyze. If blank all variables are selected.);
    %put %str(EVENT.......= Optional. A 0/1 variable. If specified the sum of this variable will be);
    %put %str(              printed for each missing pattern. This is to summarize the number of events );
    %put %str(              lost due to missing values.);
    %put %str(PRINT=N.....= Mandatory. Yes or No to print the missing patterns);
    %put %str(MAXLEVEL=999: Mandatory. The maximum number of variables in a missing pattern);
    %put %str( );
    %put %str(Example: '%misspat(data=cost, var=mountper veh_type, print=Y)' );
    %put %str(----------------------------------------------------------------------------------------------);
    %put ;
    %goto exit;
  %end;

  %let var=%qsysfunc(compbl(&var));

  %sca2util(___mc___=&var);
  %sca2util(_exist_=Y, __dsn__=&data);
  %if &__err__=ERROR %then %goto exit;

  %sca2util(_vexist_=Y, __dsn__=&data, __lst__=&var &event);
  %if &__err__=ERROR %then %goto exit;


  options nonotes;
  data ____m1 &complete(drop=_pattern_ _order_  i) &outindex;
    length i 4 _order_ _pattern_ $100 _temp_ _varlist_ $1000;
    retain _pattern_ _order_ _varlist_ '' _nmiss_ 0 _temp_ "&var";
    array vr(*) &var;

    set &data;

    *-- Initiate variables before looping over variables to consider;
    _pattern_=''; _varlist_=''; _nmiss_=0; _index_=_n_;
    do i=1 to dim(vr);
      if vr(i) le .z then do;
        _pattern_=left(trim(_pattern_))||'_';
        _nmiss_=_nmiss_+1;
        _varlist_=left(trim(_varlist_))||' '||compress(scan(left(trim(_temp_)),i,' '));
        _order_=left(trim(_order_))||' '||compress(put(i,4.));
      end;
      else _pattern_=left(trim(_pattern_))||'X';
    end;
    _pattern_=left(compress(_pattern_));
    _varlist_=left(compbl(_varlist_));

    *-- If entry and exit entered then calculate person years;
    %if %bquote(&personyear)^= %then *;
    %else %if %bquote(&entry)^= and %bquote(&exit)^= %then %do;
      %put Note: Calculating person year as &exit - &entry. Assuming unit year;
      __my_pyr__=&exit-&entry;
      %let personyear=__my_pyr__;
    %end;

    output ____m1;

    %if %bquote(&outindex) ^= %then %str(output &outindex;);
    %if "&complete" ne "" %then %do;
      if _nmiss_=0 then output &complete;
    %end;
  run;

  *-- Collapse missing levels;
  data ____m1a;
    set ____m1;
    if _nmiss_ > &maxlevel then do;
      _nmiss_=999; _varlist_="<< More than &maxlevel variables missing >>";
    end;
  run;

  proc format; value _sdfj_ 999="> &maxlevel"; run;


  proc summary data=____m1a nway missing;
    var _index_ &event &personyear;
    class _nmiss_ _varlist_;
    output out=____m2(drop=_type_ _freq_) n=n
      %if %bquote(&event) ne  %then sum(&event)=events;
      %if %bquote(&personyear) ne  %then sum(&personyear)=&personyear;
    ;
  run;

  *-- Calculate total number of records and person years;
  proc sql noprint;
    select nobs into : slask from dictionary.tables where libname='WORK' and memname='____M1';

    %if %bquote(&personyear) ne  %then %do;
      select sum(&personyear) into : slask_pyr from ____m2;
    %end;
  quit;

  proc sort data=____m2;by _nmiss_ descending n _varlist_;run;
  data ____m3 &out;
    attrib _nmiss_ label='Number of variables missing'
           _varlist_ label='Variables missing'
          N label ='Number of records' pct label ='%of records'
          acc_n label='Cumulative number of records' format=comma9. acc_pct label='Cumulative percent'
          %if %bquote(&event) ne  %then %str(events label='Number of events')
          %if %bquote(&personyear) ne  %then %do;
            &personyear label='Person Years'
 format=comma9.
            acc_pyr label='Cumulative person years' format=comma9.
          %end;
    ;
    retain acc_n acc_pyr 0;
    set ____m2;

    *- Cumulative number of subjects;
    acc_n   = acc_n+n;
    pct     = round(100*n/&slask, 0.1);
    acc_pct = round(100*acc_n/&slask, 0.1);

    *- Cumulative person years;
    %if %bquote(&personyear) ne  %then %do;
      acc_pyr     = acc_pyr + &personyear;
      pct         = round(100*n/&slask, 0.1);
      acc_pyr_pct = round(100*acc_n/&slask_pyr, 0.1);
    %end;
  run;

  %if "&print"="Y" and "&event" ne "" %then %do;

    proc sql noprint;
      select max(max(number),0) into : slask2 from sashelp.vtitle where type='T';
    quit;
    %let slask2=&slask2;
    %let slask2=%eval(&slask2+1);

    proc sql noprint;
      select setting into : hepp1
      from sashelp.voption where optname='LINESIZE';
    quit;

    %let hepp2=%eval(%length(&var)+25);
    %if &hepp2 LT &hepp1 %then %str(title&slask2 "Variables considered: &var";);
    %else %do;

      data _null_;
        gnu=trim("Variables considered: &var");
        gnu0=length(trim(gnu));
        gnu1=ceil(gnu0/2);

        a1=0;
        do i=gnu1-10 to 2*gnu1;

          a2=substr(gnu,i,1);

          if a2='' and a1=0 then do;
            del1=trim(substr(gnu,1,i));
            del2=left(trim(substr(gnu,i,gnu0-i)));

            a3=trim(put(%eval(&slask2+1),8.));

            call execute("title&slask2"||' "'||trim(del1)||'";');
            call execute("title"||compress(a3)||' "'||trim(del2)||'";');

            a1=i;
          end;
        end;

      run;
    %end;

    proc print data=____m3 noobs label uniform;
      var _nmiss_ _varlist_ n pct acc_n acc_pct events
          %if %bquote(&personyear) ne %then %str(&personyear acc_pyr);;
      format _nmiss_ _sdfj_. events 8.;
    run;

    title&slask2 ;

  %end;
  %else %if "&print"="Y" %then %do;

    proc sql noprint;
      select max(max(number),0) into : slask2 from sashelp.vtitle where type='T';
    quit;
    %let slask2=%eval(&slask2+1);

    title&slask2 "Variables considered: &var";

    proc print data=____m3 noobs label uniform;
      var _nmiss_ _varlist_ n pct acc_n acc_pct;
      format _nmiss_ _sdfj_.;
    run;

    title&slask2 ;
  %end;

  %if "&delete"="Y" %then %do;
    proc datasets lib=work mt=data nolist;
      delete ____m1-____m3 ____m1a;
    quit;
    proc catalog et=format cat=work.formats;
      delete _sdfj_;
    quit;

  %end;

  %exit:
  options notes;

%mend;

/**
%misspat(data=ana0, print=Y, event=event,
entry=exact_age, exit=att_age,
         var=cens dtime att_age age exact_age birth_cohort age_cat
             weight height bmi cbmi parity mensald ceduc x1age1st oc_ever oc_use x1ocdur
             smoker totsmok coffee tea cofcup1 teacup1 hrtb x1bfeed,
         maxlevel=3);
**/

%misspat(data=t7, print=Y, event=event,
         personyear=exit,
         var=censor pgf_cat pgm_cat mgf_cat mgm_cat,
         maxlevel=4);
