*-----------------------------------------------------------------------------;
* Study.......: MIN1701                                                       ;
* Name........:                                                               ;
* Date........: 2017-03-22                                                    ;
* Author......: svesan                                                        ;
* Purpose.....:                                                               ;
* Note........:                                                               ;
*-----------------------------------------------------------------------------;
* Data used...:                                                               ;
* Data created:                                                               ;
*-----------------------------------------------------------------------------;
* OP..........: Linux/ SAS ver 9.04.01M2P072314                               ;
*-----------------------------------------------------------------------------;

*-- External programs --------------------------------------------------------;

*-- SAS macros ---------------------------------------------------------------;

*-- SAS formats --------------------------------------------------------------;

*-- Main program -------------------------------------------------------------;

*-- Cleanup ------------------------------------------------------------------;
title1;footnote;
proc datasets lib=work mt=data nolist;
  delete _null_;
quit;

*-- End of File --------------------------------------------------------------;
