*-----------------------------------------------------------------------------;
* Study.......: MIN1701                                                       ;
* Name........: s_missing1.sas                                                ;
* Date........: 2017-03-22                                                    ;
* Author......: svesan                                                        ;
* Purpose.....: Summary statistics of missing data                            ;
* Note........:                                                               ;
*-----------------------------------------------------------------------------;
* Data used...:                                                               ;
* Data created:                                                               ;
*-----------------------------------------------------------------------------;
* OP..........: Linux/ SAS ver 9.04.01M2P072314                               ;
*-----------------------------------------------------------------------------;

*-- External programs --------------------------------------------------------;
*%inc saspgm(s_dm2);

*-- SAS macros ---------------------------------------------------------------;
%inc saspgm(sca2util);
%inc saspgm(misspat);

*-- SAS formats --------------------------------------------------------------;


*-- Main program -------------------------------------------------------------;

*-- Describe individuals where maternal OR paternal grand parents are missing ;
*-- or both;
data s1;
  label exit='Person years (follow-up)';
  set t7;

run;

%misspat(data=s1, print=Y, event=event,
         personyear=exit,
         var=censor pgf_cat pgm_cat mgf_cat mgm_cat,
         maxlevel=4);


title1 'Compare data distributions by missing pattern';

proc means data=s1 nway maxdec=1 mean q1 q3;
  var byear mage page exit;
  class gp_miss;
  format gp_miss gpmiss.;
run;


*-- Cleanup ------------------------------------------------------------------;
title1;footnote;
proc datasets lib=work mt=data nolist;
  delete _null_;
quit;

*-- End of File --------------------------------------------------------------;
