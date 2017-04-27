*%let rot = C:\psync\mssm\Studies\min1701\sasdsn\;

*libname  study  "/folders/myfolders/min1701/sasdsn" access=readonly;
libname  study   "/home/sandis01/pCloudDrive/mssm/Studies/min1701/sasdsn/" access=readonly;
filename saspgm  "/home/sandis01/pCloudDrive/mssm/Studies/min1701/saspgm";

*filename saspgm "&rot.saspgm";

options notes details stimer;


proc sql;
  create table t1(label='All children in the cohort') as
  select pid as cid, dob as cid_dob, dod as cid_dod, doem_first as cid_doe,
         sex as cid_sex
  from study.demog_new
  where in_cohort=1
  ;

  *-- Add in IDs for the grand parents;
  create table t2 as
  select a.*, b.fid, b.mid, b.pgf_id, b.pgm_id, b.mgf_id, b.mgm_id
  from t1 as a
    left join study.fam_ancestors_new(keep=cid mid fid pgf_id pgm_id mgf_id mgm_id) as b
      on a.cid = b.cid
  ;

  *-- Add demographic for the parents;
  create table t3 as
  select a.*, b.dob as p_dob, c.dob as m_dob
  from t2 as a
    left join study.demog_new(keep=pid dob) as b
      on a.fid = b.pid
    left join study.demog_new(keep=pid dob) as c
      on a.mid = c.pid
  ;
proc sql;
  *-- Add demographic for the grand parents ;
  create table t4 as
  select a.*,
         b.dob as pgf_dob, c.dob as pgm_dob,
         d.dob as mgf_dob, e.dob as mgm_dob,
         int( (a.cid_dob-p_dob)/365.25 ) as page length=4 label='Paternal Age',
         int( (a.cid_dob-m_dob)/365.25 ) as mage length=4 label='Maternal Age',

         int( (a.p_dob-b.dob)/365.25 ) as pgf_age length=4 label='Pat. Grand Father Age',
         int( (a.p_dob-c.dob)/365.25 ) as pgm_age length=4 label='Pat. Grand Mother Age',
         int( (a.m_dob-d.dob)/365.25 ) as mgf_age length=4 label='Mat. Grand Father Age',
         int( (a.m_dob-e.dob)/365.25 ) as mgm_age length=4 label='Mat. Grand Mother Age'

  from t3 as a
    left join study.demog_new(keep=pid dob) as b
      on a.pgf_id = b.pid
    left join study.demog_new(keep=pid dob) as c
      on a.pgm_id = c.pid
    left join study.demog_new(keep=pid dob) as d
      on a.mgf_id = d.pid
    left join study.demog_new(keep=pid dob) as e
      on a.mgm_id = e.pid
  ;
quit;

proc sort data=t4;by cid;run;
proc sort data=study.asd_cond_new(keep=cid asd asd_type do1st_asd) out=t5;by cid;run;
data t6;
  length ad_exit asd_exit 6 ad_cens asd_cens 3;
  attrib ad_event  length=3 label='AD'
         asd_event length=3 label='ASD'
  ;
  merge t4 t5;
  by cid;

  *-- ASD (AD, F841 atypical, F845 Asperger, F849 PPPD);
  if asd>0 then do; asd_cens=0; asd_exit=(do1st_asd - cid_dob)/365.25; end;
  else if cid_dod>.z then do; asd_cens=1; asd_exit=(cid_dod - cid_dob)/365.25; end;
  else if cid_doe>.z then do; asd_cens=2; asd_exit=(cid_doe - cid_dob)/365.25; end;
  else do; asd_cens=3; asd_exit=('31Dec2014'd - cid_dob)/365.25; end;
  asd_exit=round(asd_exit,0.1);

  *-- AD F840;
  if asd_type=1 then do; ad_cens=0; ad_exit=(do1st_asd - cid_dob)/365.25; end;
  else if cid_dod>.z then do; ad_cens=1; ad_exit=(cid_dod - cid_dob)/365.25; end;
  else if cid_doe>.z then do; ad_cens=2; ad_exit=(cid_doe - cid_dob)/365.25; end;
  else do; ad_cens=3; ad_exit=('31Dec2014'd - cid_dob)/365.25; end;
  ad_exit=round(ad_exit,0.1);

  ad_event =1-ad_cens;
  asd_event=1-asd_cens;
run;

%macro agecat(var, out, type=1);
  if &var le .z then &out = .u;
  else if &var lt 20 then &out = 1;
  else if &var le 24 then &out = 2;
  else if &var le 29 then &out = 3;
  else if &var le 34 then &out = 4;
  else if &var le 39 then &out = 5;
  else if &var le 44 then &out = 6;
  else if &var le 49 then &out = 7;
  else &out = 8;                          *-- Max category is >= 50 ;

  if "&type"="2" and &out>7 then &out=7;  *-- Max category is >= 45 ;
  if "&type"="3" and &out>6 then &out=6;  *-- Max category is >= 40 ;
%mend;

proc format;
  value age1fmt 1='<20'   2='20-24' 3='25-29' 4='30-34' 5='35-39'
                6='40-44' 7='45-49' 8='>=50'
  ;
  value age2fmt 1='<20'   2='20-24' 3='25-29' 4='30-34' 5='35-39'
                6='40-44' 7='>=45'
  ;
  value age3fmt 1='<20'   2='20-24' 3='25-29' 4='30-34' 5='35-39'
                6='>=40'
  ;
  value gpmiss 0='Complete data'
               1='All grand parents missing'
               2='Grand PATERNAL ages missing'
               3='Grand MATERNAL ages missing'
  ;
run;

data t7;
  length pg_miss mg_miss pm_miss 3;

  attrib byear length=4 label='Year of Birth'
         pat_cat length=4 label='Paternal age' format=age2fmt.
         mat_cat length=4 label='Maternal age' format=age2fmt.
         pgf_cat length=4 label='Pat Grand-Paternal' format=age2fmt.
         pgm_cat length=4 label='Pat Grand-Maternal' format=age2fmt.
         mgf_cat length=4 label='Mat Grand-Paternal' format=age2fmt.
         mgm_cat length=4 label='Mat Grand-Maternal' format=age2fmt.
         gp_miss length=3 label='Grand Parental Missing Pattern'
  ;
  keep byear cid_sex mage page pgf_age mgf_age gp_miss
       asd_cens asd_event asd_exit
       ad_cens ad_event ad_exit
       mat_cat pat_cat pgf_cat pgm_cat mgf_cat mgm_cat
       pgf_age pgm_age mgf_age mgm_age
  ;
  set t6;
  byear=year(cid_dob);

  %agecat(mage, mat_cat, type=2);
  %agecat(page, pat_cat, type=2);

  %agecat(pgf_age, pgf_cat, type=2);
  %agecat(pgm_age, pgm_cat, type=2);
  %agecat(mgf_age, mgf_cat, type=2);
  %agecat(mgm_age, mgm_cat, type=2);

  *-- Create variable indexing amoun of missing grand parental info;
  if pgf_cat le .z and pgm_cat le .z then pg_miss=1;else pg_miss=0;
  if mgf_cat le .z and mgm_cat le .z then mg_miss=1;else mg_miss=0;

  if pg_miss=1 and mg_miss=1 then pm_miss=1; else pm_miss=0;

  gp_miss=0;
  if pm_miss then gp_miss=1;
  else if pg_miss then gp_miss=2;
  else if mg_miss then gp_miss=3;
run;
proc freq;table mat_cat pat_cat;run;

/*proc phreg data=t7;
  class byear(ref='1998') cid_sex(ref='0');
  model exit*censor(1,2,3) = byear cid_sex page mage
  / ;
  hazardratio cid_sex / cl=both diff=ref;
  hazardratio mage / units=5 cl=both diff=ref;
  hazardratio page / units=5 cl=both diff=ref;
run;
*/
data t8;
  drop asd_cens asd_exit asd_event ad_cens ad_exit ad_event;
  set t7;
  outcome='ASD'; cens=asd_cens; exit=asd_exit; event=asd_event; output;
  outcome='AD';  cens=ad_cens;  exit=ad_exit;  event=ad_event; output;
run;
proc sort data=t8;by outcome;run;

data s1;
  set t8(keep=pgf_cat pgm_cat mgf_cat mgm_cat mat_cat pat_cat
              outcome byear cid_sex cens event exit gp_miss) ;
  if gp_miss > 0 then delete;
  if exit le 1 then delete;
  ;
run;

title1 'Model M0. Birth + Pat Age + Mat Age. Validation model';
ods output hazardratios=matpat_hz2 parameterestimates=matpat_pe2;
proc phreg data=s1 ;
  class byear(ref='1998') cid_sex(ref='0')
        mat_cat(ref='25-29') pat_cat(ref='25-29') / order=internal;
  model exit*cens(1,2,3) = byear mat_cat pat_cat
  / rl=pl alpha=0.05;
  hazardratio byear / cl=PL   diff=ref;
  by outcome;
run;

ods trace off;
title1 'Model M2. MGM';
ods output hazardratios=hz2 parameterestimates=pe2;
proc phreg data=s1;
  class byear(ref='1998') cid_sex(ref='0')
        mgf_cat(ref='25-29') mgm_cat(ref='25-29')
        ;
  model exit*cens(1,2,3) = byear
                           mgm_cat
  / rl=pl alpha=0.05;
  hazardratio mgm_cat / cl=both diff=ref;
  by outcome;
run;

title1 'Model M3. MGF';
ods output hazardratios=hz3 parameterestimates=pe3;
proc phreg data=s1;
  class byear(ref='1998') cid_sex(ref='0')
        mgf_cat(ref='25-29') mgm_cat(ref='25-29')
        ;
  model exit*cens(1,2,3) = byear
                             mgf_cat
  / rl=pl alpha=0.05 ;
  hazardratio mgf_cat / cl=both diff=ref;
  by outcome;
run;

title1 'Model M4. MGM + MGF';
ods output hazardratios=hz4 parameterestimates=pe4;
proc phreg data=s1;
  class byear(ref='1998') cid_sex(ref='0')
        mgf_cat(ref='25-29') mgm_cat(ref='25-29')
        ;
  model exit*cens(1,2,3) = byear
                             pgf_cat pgm_cat
  / rl=pl alpha=0.05 ;
  hazardratio pgf_cat / cl=both diff=ref;
  hazardratio pgm_cat / cl=both diff=ref;
  by outcome;
run;

title1 'Model M5. PGM';
ods output hazardratios=hz5 parameterestimates=pe5;
proc phreg data=s1;
  class byear(ref='1998') cid_sex(ref='0')
        pgm_cat(ref='25-29')
        ;
  model exit*cens(1,2,3) = byear
                             pgm_cat
  / rl=pl alpha=0.05 ;
  hazardratio pgm_cat / cl=both diff=ref;
  by outcome;
run;

title1 'Model M6. PGF';
ods output hazardratios=hz6 parameterestimates=pe6;
proc phreg data=s1;
  class byear(ref='1998') cid_sex(ref='0')
        pgf_cat(ref='25-29')
        ;
  model exit*cens(1,2,3) = byear
                             pgf_cat
  / rl=pl alpha=0.05 ;
  hazardratio pgf_cat / cl=both diff=ref;
  by outcome;
run;

title1 'Model M7. PGM + PGF';
ods output hazardratios=hz7 parameterestimates=pe7;
proc phreg data=s1;
  class byear(ref='1998') cid_sex(ref='0')
        pgf_cat(ref='25-29') pgm_cat(ref='25-29')
        ;
  model exit*cens(1,2,3) = byear
                             pgf_cat pgm_cat
  / rl=pl alpha=0.05 ;
  hazardratio pgf_cat / cl=both diff=ref;
  hazardratio pgm_cat / cl=both diff=ref;
  by outcome;
run;

title1 'Model M8. MGM + MGF';
ods output hazardratios=hz8 parameterestimates=pe8;
proc phreg data=s1;
  class byear(ref='1998')
        mgf_cat(ref='25-29') mgm_cat
        ;
  model exit*cens(1,2,3) = byear
                             mgf_cat mgm_cat
  / rl=pl alpha=0.05;
  hazardratio mgf_cat / cl=both diff=ref;
  hazardratio mgm_cat / cl=both diff=ref;
  by outcome;
run;


data comb_pe;
  set pe7(in=pe7)
      pe8(in=pe8)
  ;

  if pe7 then do;mid=7; model='PGM + PGF';  end;
  if pe7 then do;mid=8; model='MGM + MGF';  end;

run;
proc sort data=comb_pe;
  by outcome model;
run;

proc freq data=s1;
where outcome='AD';
table mgf_cat * cens / nopercent nocol;
run;
