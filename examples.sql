#### insert into CatStats statistics for cats with rank <= 15
delete from CatStats;
insert into CatStats
  select aid ,
         ar.cid  ,
         count(1) as total ,
         sum(us.isTop5 != 0) as onTopPage ,
         sum(if(us.choice=1,1,0)) as top,
         sum(if(us.choice=2,1,0)) as additional,
         sum(if(us.choice!=0,1,0)) as hit
  from  AlgRanks ar , UserChoice us
  where ar.uid = us.uid and ar.cid = us.cid and ar.rank <= 15
  group by aid,cid;

delete from HistSize;
insert into HistSize select UUID.uid , days , country , sum( AlgRanks.score) score_sum
  from UUID , Payloads , Surveys , AlgRanks
  where UUID.name = Payloads.uuid
    and Surveys.uuid = UUID.name
    and AlgRanks.uid = UUID.uid
group by UUID.uid;

### populate CatUserCount
drop table CatUserCount;
create table CatUserCount
    select Cats.cid as cid, Cats.name cat, sum(1) as total_shown , sum(choice = 1) as topInterested , sum(if(choice != 0,1,0)) as interested ,
           sum(choice = 1) / sum(1)  topBasePrec ,
           2 * (sum(choice = 1) / sum(1)) / ( 1 + sum(choice = 1) / sum(1)) topBaseF,
           sum(if(choice != 0,1,0)) / sum(1) basePrec ,
           2 * (sum(if(choice != 0,1,0)) / sum(1)) / ( 1 + sum(if(choice != 0,1,0)) / sum(1)) baseF
    from UserChoice, Cats , HistSize
    where Cats.cid = UserChoice.cid
      and HistSize.uid = UserChoice.uid
      and HistSize.days > 5
  group by Cats.cid;


#### show how categories were presented and choosen by a user
select Cats.name ,
         #sum(choice = 1) as topInterested ,
         #sum(isTop5) as onFirstPage,
         sum(1) as presented ,
         sum(if(choice != 0,1,0)) as interested ,
         ROUND(sum(choice = 1) * 100/ sum(1),1)  basePrecision
         #,2 * (sum(choice = 1) / sum(1)) / ( 1 + sum(choice = 1) / sum(1)) topBaseF,
         #sum(if(choice != 0,1,0)) / sum(1) basePrec ,
         #2 * (sum(if(choice != 0,1,0)) / sum(1)) / ( 1 + sum(if(choice != 0,1,0)) / sum(1)) baseF
  from UserChoice, Cats , HistSize
  where Cats.cid = UserChoice.cid
        and HistSize.uid = UserChoice.uid
        and HistSize.country = "United States"
        #and HistSize.days > 5
  group by Cats.name
  order by basePrecision desc;

#### base line
select us.* , non.presented non_us_presented, non.interested non_us_interested, non.basePrecision non_us_basePrecision, us.basePrecision - non.basePrecision delta
  from (
  select Cats.name ,
         #sum(choice = 1) as topInterested ,
         #sum(isTop5) as onFirstPage,
         sum(1) as presented ,
         sum(if(choice != 0,1,0)) as interested ,
         ROUND(sum(choice = 1) * 100/ sum(1),1)  basePrecision
         #,2 * (sum(choice = 1) / sum(1)) / ( 1 + sum(choice = 1) / sum(1)) topBaseF,
         #sum(if(choice != 0,1,0)) / sum(1) basePrec ,
         #2 * (sum(if(choice != 0,1,0)) / sum(1)) / ( 1 + sum(if(choice != 0,1,0)) / sum(1)) baseF
  from UserChoice, Cats , HistSize
  where Cats.cid = UserChoice.cid
        and HistSize.uid = UserChoice.uid
        and HistSize.country = "United States"
        #and HistSize.days > 5
  group by Cats.name
  #order by basePrecision desc;
  ) as us
  join
  (
  select Cats.name ,
         #sum(choice = 1) as topInterested ,
         #sum(isTop5) as onFirstPage,
         sum(1) as presented ,
         sum(if(choice != 0,1,0)) as interested ,
         ROUND(sum(choice = 1) * 100/ sum(1),1)  basePrecision
         #,2 * (sum(choice = 1) / sum(1)) / ( 1 + sum(choice = 1) / sum(1)) topBaseF,
         #sum(if(choice != 0,1,0)) / sum(1) basePrec ,
         #2 * (sum(if(choice != 0,1,0)) / sum(1)) / ( 1 + sum(if(choice != 0,1,0)) / sum(1)) baseF
  from UserChoice, Cats , HistSize
  where Cats.cid = UserChoice.cid
        and HistSize.uid = UserChoice.uid
        and HistSize.country != "United States"
        #and HistSize.days > 5
  group by Cats.name
  #order by basePrecision desc;
  ) as non
  on us.name = non.name
  order by us.basePrecision desc;

#### show how different algorithms perform for a given Category precision-wise
select Algs.name,
         Cats.name,
         top * 100 / total top_prec,
         hit * 100 / total all_prec ,
         total as presented ,
         onTopPage as firstPage
  from CatStats cs, Cats, Algs
  where Cats.cid = cs.cid and Cats.name = 'Technology' and Algs.aid = cs.aid
  order by presented desc;

### show categorization results for a given alg and user
select Algs.name , Cats.name , score , rank
  from AlgRanks , Algs, Cats
  where Cats.cid = AlgRanks.cid and AlgRanks.aid = Algs.aid and uid = 2 and Algs.name = "daycount.rules.edrules"
  order by score desc;


### show how a given algorithm does for a given category
select al.name , ct.name, ar.score , rank , us.choice user_choise, us.isTop5 as topPage
  from AlgRanks ar , UserChoice us, Algs al , Cats ct
  where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid and al.name = "daycount.combined.edrules" and ct.name = "Do-It-Yourself"
  order by ar.score desc;

### show how an algorithm does for all cagtegories
select al.name , ct.name, ar.score , rank , us.choice user_choise, us.isTop5 as topPage
  from AlgRanks ar , UserChoice us, Algs al , Cats ct
  where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid and al.name = "daycount.combined.edrules"
  order by ct.name,ar.score desc;

#### compute algs precision for all categories
select al.name , ct.name,
         AVG(ar.score) ,
         AVG(rank) ,
         MAX(rank) ,
         COUNT(1) presented,
         SUM(us.isTop5 = 1) firstPage,
         SUM(us.choice = 1) top,
         SUM(us.choice = 2) additional,
         SUM(us.choice != 0) / COUNT(1) overall_precision
  from AlgRanks ar , UserChoice us, Algs al , Cats ct
  where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid
      and al.name = "daycount.combined.edrules"
  group by al.name , ct.name
  order by overall_precision desc;

#### compute algs precision for all categorie that it assigned rank <= 5 and hisory size > 5 and score > 5
select al.name , ct.name,
         AVG(ar.score) ,
         AVG(rank) ,
         SUM(us.isTop5) top_shown,
         COUNT(1) total_shown,
         SUM(us.choice = 1) top,
         SUM(us.choice = 2) additional,
         SUM(us.choice = 1) / SUM(us.isTop5) top_prec,
         SUM(us.choice != 0) / COUNT(1) all_prec
  from AlgRanks ar , UserChoice us, Algs al , Cats ct , HistSize hs
  where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid
        and hs.uid = us.uid
        and hs.days > 5
        and hs.country = "United States"
        and ar.rank <=10
        and ar.score > 5
        and al.name = "daycount.rules.edrules"
        #and ct.name IN ("Do-It-Yourself","Technology","Android","Politics","Programming","Music","Entrepreneur","Business","Apple","Science",'Humor','Movies','Video-Games','Gossip','Sports')
  group by al.name , ct.name
  having total_shown > 5
  order by all_prec desc;

#### compute and AVG precision for an alg
select name alg, count(distinct(cat)) catnb, ROUND(AVG(top_prec),3) top_precision_avg,
         ROUND(AVG(overall_precision),3) precision_avg,
         ROUND(AVG(overall_recall),3) recall_avg,
         ROUND(AVG(overallF),3) f_avg,
         ROUND(AVG(overallF05),3) f05_avg
  from
   (select al.name as name, ct.name as cat , COUNT(1) as users,
           SUM(us.choice = 1) / SUM(us.isTop5) as top_prec,
           SUM(us.choice != 0) / COUNT(1) as overall_precision ,
           SUM(us.choice != 0) / catu.interested overall_recall ,
           2 * (SUM(us.choice != 0) / COUNT(1) * SUM(us.choice != 0) / catu.interested) / (SUM(us.choice != 0) / COUNT(1) + SUM(us.choice != 0) / catu.interested) overallF,
           (1+0.25) * (SUM(us.choice != 0) / COUNT(1) * SUM(us.choice != 0) / catu.interested) / (0.25 * SUM(us.choice != 0) / COUNT(1) + SUM(us.choice != 0) / catu.interested) overallF05
    from AlgRanks ar , UserChoice us, Algs al , Cats ct , HistSize hs, CatUserCount catu
    where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid
        and hs.uid = us.uid
        #and hs.country = "United States"
        and hs.days > 5
        and (hs.scoresum / hs.days ) > 0
        and catu.cid = ar.cid
        and ar.rank <= 10
        #and ar.score > 5
    group by al.name , ct.name
    having users > 5
      #and overall_precision >= 0.6
      and cat IN (select cat from CatUserCount where total_shown > 100)
      #and al.name like "sqrt_hcnt.keywords.rules_synthetic"
   ) as apres
  group by name
  order by f05_avg desc;

#compute all algs perfromance for a given cat
select ct.name, al.name ,
         AVG(ar.score) ,
         AVG(rank) ,
         SUM(us.isTop5) top_shown,
         COUNT(1) total_shown,
         SUM(us.choice = 1) top,
         SUM(us.choice = 2) additional,
         SUM(us.choice = 1) / SUM(us.isTop5) top_prec,
         SUM(us.choice != 0) / COUNT(1) all_prec
  from AlgRanks ar , UserChoice us, Algs al , Cats ct , HistSize hs
  where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid
        and hs.uid = us.uid
        and hs.days > 5
        and ar.rank <= 10
        and ar.score > 5
        and ct.name = "Gossip"
  group by al.name , ct.name
  having total_shown > 5
  order by all_prec desc;

# compute all algs perf for all cats
select ct.name interest, al.name alg,
         COUNT(1) users, SUM(us.choice != 0) correct,
         SUM(us.choice = 1) / SUM(us.isTop5) top_prec,
         SUM(us.choice = 1) / catu.topInterested top_recall ,
         2 * ((SUM(us.choice = 1) / SUM(us.isTop5) * SUM(us.choice = 1) / catu.topInterested)) / ((SUM(us.choice = 1) / SUM(us.isTop5) + SUM(us.choice = 1) / catu.topInterested)) topF ,
         SUM(us.choice != 0) / COUNT(1) overall_prec ,
         SUM(us.choice != 0) / catu.interested overall_recall ,
         2 * (SUM(us.choice != 0) / COUNT(1) * SUM(us.choice != 0) / catu.interested) / (SUM(us.choice != 0) / COUNT(1) + SUM(us.choice != 0) / catu.interested) overallF
  from AlgRanks ar , UserChoice us, Algs al , Cats ct , HistSize hs , CatUserCount catu
  where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid
        and hs.uid = us.uid
        and hs.country = "United States"
        and hs.days > 5
        and catu.cid = ct.cid
        and ar.rank <= 1
        and ar.score > 3
        and catu.total_shown > 100
        #and ct.name = "Parenting"
        and al.name = "daycount.combined.edrules_extended"
  group by al.name , ct.name
    #having users > 5
  order by  overall_prec desc;


# compute number of interest an alg assigns to a user
select name alg, AVG(cnumber) assigned_cats, COUNT(1) users
  from (
  select al.name as name, us.uid as uid, count(DISTINCT(ct.cid)) as cnumber
  from AlgRanks ar , UserChoice us, Algs al , Cats ct , HistSize hs
  where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid
    and hs.uid = us.uid
    and hs.days > 5
    and ar.rank <= 10
    and ar.score > 5
  group by al.name , us.uid
  ) as ausers
  group by alg
  having users > 5;

select cat category , AVG(top_prec) top_precision_avg, AVG(overall_precision) overall_precision_avg, AVG(users) user_reach_avg
  from
   (select al.name as name, ct.name as cat , COUNT(1) as users, SUM(us.choice = 1) / SUM(us.isTop5) as top_prec, SUM(us.choice != 0) / COUNT(1) as overall_precision
    from AlgRanks ar , UserChoice us, Algs al , Cats ct , HistSize hs
    where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid
        and hs.uid = us.uid
        and hs.days > 5
        #and hs.country = "United States"
        and ar.rank <= 10
        #and ar.score > 5
    group by al.name , ct.name
    having users > 5
          and  cat IN (select cat from CatUserCount where total_shown > 100)
    order by overall_precision desc
   ) as apres
  group by category
  order by overall_precision_avg desc;


select cat category , name alg, prec total_precision, total_recall, users user_reach_avg,
       users / (select count(1) from HistSize where days > 5) as pct_total_users
  from
   (select al.name as name,
           ct.name as cat ,
           COUNT(1) as users,
           SUM(us.choice != 0) / COUNT(1) as prec,
           SUM(us.choice != 0) / catu.interested as total_recall
    from AlgRanks ar , UserChoice us, Algs al , Cats ct , HistSize hs, CatUserCount catu
    where us.cid = ar.cid
        and us.uid = ar.uid
        and ct.cid = ar.cid
        and al.aid = ar.aid
        and catu.cid = ct.cid
        and hs.uid = us.uid
        and hs.days > 5
        #and hs.country = "United States"
        and ar.rank <= 10
        #and ar.score > 5
    group by al.name , ct.name
    having users > 5
          and  cat IN (select cat from CatUserCount where total_shown > 100)
    order by prec desc
   ) as apres
  group by category
  order by total_precision desc;



# shows per user alg+cat data
select Algs.name , Cats.name ,  rank , choice
  from AlgRanks , Algs, Cats , HistSize , UserChoice , UUID , Surveys
  where UserChoice.uid = HistSize.uid
    and UUID.name = Surveys.uuid
    and Surveys.country = "United States"
    and UUID.uid = HistSize.uid
    and UserChoice.cid = Cats.cid
    and Cats.cid = AlgRanks.cid
    and AlgRanks.aid = Algs.aid
    and Algs.name = "daycount.rules.edrules"
    and Cats.name = "Programming"
    and HistSize.uid = AlgRanks.uid
    and HistSize.days > 5;

#### show best family of algs for allcats
SELECT * FROM (
  select ct.name catn, SUBSTR(al.name,1,1) algn, al.name fname ,
        SUM(us.isTop5) top_shown,
        COUNT(1) total_shown,
        catu.topBasePrec,
        catu.topBaseF,
        catu.basePrec basePrec,
        catu.baseF baseF,
        SUM(us.choice = 1) / SUM(us.isTop5) top_prec,
        SUM(us.choice = 1) / catu.topInterested top_recall ,
        2 * ((SUM(us.choice = 1) / SUM(us.isTop5) * SUM(us.choice = 1) / catu.topInterested)) / ((SUM(us.choice = 1) / SUM(us.isTop5) + SUM(us.choice = 1) / catu.topInterested)) topF ,
        SUM(us.choice != 0) / COUNT(1) all_prec ,
        SUM(us.choice != 0) / catu.interested all_recall ,
        2 * (SUM(us.choice != 0) / COUNT(1) * SUM(us.choice != 0) / catu.interested) / (SUM(us.choice != 0) / COUNT(1) + SUM(us.choice != 0) / catu.interested) allF
  from AlgRanks ar ,
       UserChoice us,
       Algs al ,
       Cats ct ,
       HistSize hs ,
       CatUserCount catu
  where us.cid = ar.cid
        and us.uid = ar.uid
        and ct.cid = ar.cid
        and al.aid = ar.aid
        and hs.uid = us.uid
        and hs.days > 5
        and hs.country = "United States"
        and catu.cid = ct.cid
        and ar.rank <= 10
        and ar.score > 5
  #      and al.name like "daycount.rules%"
  group by al.name , ct.name
  having total_shown > 5
         and catn IN (select cat from CatUserCount where total_shown > 100)
  order by ct.name , allF desc) x
  GROUP BY catn,algn
  order by catn,allF desc;

#### show best algs for allcats
SELECT * FROM (
  select ct.name catn, al.name algn ,
        SUM(us.isTop5) top_shown,
        COUNT(1) total_shown,
        catu.topBasePrec,
        catu.topBaseF,
        catu.basePrec basePrec,
        catu.baseF baseF,
        SUM(us.choice = 1) top,
        SUM(us.choice = 2) additional,
        SUM(us.choice = 1) / SUM(us.isTop5) top_prec,
        SUM(us.choice != 0) / COUNT(1) all_prec,
        SUM(us.choice != 0) / catu.interested all_recall ,
        2 * (SUM(us.choice != 0) / COUNT(1) * SUM(us.choice != 0) / catu.interested) / (SUM(us.choice != 0) / COUNT(1) + SUM(us.choice != 0) / catu.interested) allF
  from AlgRanks ar ,
       UserChoice us,
       Algs al ,
       Cats ct ,
       HistSize hs ,
       CatUserCount catu
  where us.cid = ar.cid
        and us.uid = ar.uid
        and ct.cid = ar.cid
        and al.aid = ar.aid
        and hs.uid = us.uid
        and hs.days > 5
        and hs.country = "United States"
        and catu.cid = ct.cid
        #and ar.rank <= 10
        #and ar.score > 5
        and al.name = "daycount.rules.rules_synthetic"
  group by ct.name , algn
  having total_shown > 5
         and catn IN (select cat from CatUserCount where total_shown > 100)
  order by ct.name , all_prec desc) x
  GROUP BY catn
  order by all_prec desc;
select us.uid , ct.name as cat , us.choice, hs.days
    from AlgRanks ar , UserChoice us, Algs al , Cats ct , HistSize hs
    where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid
        and hs.uid = us.uid
        and hs.country = "United States"
        and hs.days > 5
        and ar.rank <= 10
        and ar.score > 5
        and al.name = "daycount.keywords.edrules_extended"
        order by us.uid, ar.rank;


select x.name, news_page , news_home_page from (select Algs.name, count(distinct(AlgRanks.uid)) users , SUM(score) news_page from HistSize, Algs, AlgRanks , Cats where HistSize.uid = AlgRanks.uid and HistSize.country = "United States" and Algs.name like '%.rules.%' and Algs.aid = AlgRanks.aid and Cats.cid = AlgRanks.cid and Cats.name = "__news_counter" group by Algs.name) x , (select Algs.name, count(distinct(AlgRanks.uid)) users, SUM(score) news_home_page from HistSize, Algs, AlgRanks , Cats where HistSize.uid = AlgRanks.uid and HistSize.country = "United States" and Algs.name like '%.rules.%' and Algs.aid = AlgRanks.aid and Cats.cid = AlgRanks.cid and Cats.name = "__news_home_counter" group by Algs.name) y where x.name = y.name;


# computing relative performance betwix two algorithms
select al.name as name, ct.name as cat , COUNT(1) as users,
        SUM(us.choice = 1) / SUM(us.isTop5) as top_prec,
        SUM(us.choice != 0) / COUNT(1) as overall_precision ,
        SUM(us.choice != 0) / catu.interested overall_recall ,
        2 * (SUM(us.choice != 0) / COUNT(1) * SUM(us.choice != 0) / catu.interested) / (SUM(us.choice != 0) / COUNT(1) + SUM(us.choice != 0) / catu.interested) overallF,
       (1+0.25) * (SUM(us.choice != 0) / COUNT(1) * SUM(us.choice != 0) / catu.interested) / (0.25 * SUM(us.choice != 0) / COUNT(1) + SUM(us.choice != 0) / catu.interested) overallF05
  from AlgRanks ar ,
   UserChoice us,
   Algs al ,
   Cats ct ,
   HistSize hs,
   CatUserCount catu
  where us.cid = ar.cid
   and us.uid = ar.uid
   and ct.cid = ar.cid
   and al.aid = ar.aid
   and hs.uid = us.uid
   and hs.country = "United States"
   and hs.days > 5
   and (hs.scoresum / hs.days ) > 0
   and catu.cid = ar.cid
   and ar.rank <= 10
   and ar.score > 5   group by al.name ,
   ct.name   having users > 5
   and cat IN (select cat from CatUserCount where total_shown > 100)
   and al.name like "daycount.combined.edrules_extended" or al.name like "daycount.combined.edrules"
  order by cat, overallF05 desc;

select al.name as alg, al.aid as aid,
         ct.name as cat , ct.cid as cid ,
         #COUNT(distinct(us.uid)) as users,
         COUNT(1) total ,
         SUM(us.choice != 0) correct ,
         #SUM(us.choice != 0) / COUNT(1) as overall_precision ,
         #SUM(us.choice != 0) / catu.interested overall_recall ,
         #AVG(rank),
         #AVG(score),
         #score score_sec
         #FLOOR(score * 10 / hs.days)  confid
         #score confid
         rank confid
  into outfile '/tmp/daycount.all'
  from AlgRanks ar ,
   UserChoice us,
   Algs al ,
   Cats ct ,
   HistSize hs,
   CatUserCount catu
  where us.cid = ar.cid
   and us.uid = ar.uid
   and ct.cid = ar.cid
   and al.aid = ar.aid
   and hs.uid = us.uid
   #and hs.country = "United States"
   #and hs.days > 5
   and catu.cid = ar.cid
   and catu.total_shown >= 100
   #and ar.score > 3
   and al.name like "daycount%"
   #and ct.name = "Boxing"
  group by alg,cat,confid
   #having users > 5
  order by alg,cat,confid;

select count(distinct(us.uid))
  from AlgRanks ar ,
   UserChoice us,
   Algs al ,
   Cats ct ,
   HistSize hs,
   CatUserCount catu
  where us.cid = ar.cid
   and us.uid = ar.uid
   and ct.cid = ar.cid
   and al.aid = ar.aid
   and hs.uid = us.uid
   and hs.country = "United States"
   and hs.days > 5
   and catu.cid = ar.cid
   and catu.total_shown >= 100
   #and ar.score > 5
   #and al.name = "sqrt_hcnt.combined.rules_synthetic"
   and al.name = "daycount.rules.rules_synthetic"
   and ct.name = "Video-Games";


select alg, AVG(overall_prec) as prec, AVG(overall_recall) recall
  from (
  select ct.name interest, al.name alg,
         COUNT(1) users, SUM(us.choice != 0) correct, rank,
         SUM(us.choice = 1) / SUM(us.isTop5) top_prec,
         SUM(us.choice = 1) / catu.topInterested top_recall ,
         2 * ((SUM(us.choice = 1) / SUM(us.isTop5) * SUM(us.choice = 1) / catu.topInterested)) / ((SUM(us.choice = 1) / SUM(us.isTop5) + SUM(us.choice = 1) / catu.topInterested)) topF ,
         SUM(us.choice != 0) / COUNT(1) overall_prec ,
         SUM(us.choice != 0) / catu.interested overall_recall ,
         2 * (SUM(us.choice != 0) / COUNT(1) * SUM(us.choice != 0) / catu.interested) / (SUM(us.choice != 0) / COUNT(1) + SUM(us.choice != 0) / catu.interested) overallF
  from AlgRanks ar , UserChoice us, Algs al , Cats ct , HistSize hs , CatUserCount catu
  where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid
        and hs.uid = us.uid
        #and hs.country = "United States"
        and hs.days > 5
        and catu.cid = ct.cid
        and ar.rank <= 10
        #and ar.score > 5
        and catu.total_shown > 100
        #and ct.name = "Parenting"
        #and al.name = "daycount.combined.edrules_extended"
  group by al.name , ct.name
    #having users > 5
  order by  overall_prec desc
  ) as x
  group by alg
  order by prec desc;

select alg,
         ROUND(AVG(cats),3) cats_shown,
         #ROUND(STD(cats),3) deviation,
         ROUND(AVG(prec) * 100,1) prec
  from
  (
  select hs.uid user, al.name alg, rank,
         SUM(if(rank<=10,1,0)) cats,
         #SUM(us.choice != 0) correct ,
         #SUM(us.choice != 0) / COUNT(1)
         SUM(if(rank<=10,us.choice != 0,0)) correct,
         SUM(if(rank<=10,us.choice != 0,0)) / SUM(if(rank<=10,1,0)) prec
  from AlgRanks ar , UserChoice us, Algs al , Cats ct , HistSize hs , CatUserCount catu
  where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid
        and hs.uid = us.uid
        and hs.country != "United States"
        #and hs.days >= 50
        and catu.cid = ct.cid
        #and ar.rank <= 10
        #and ar.score > 5
        and catu.total_shown > 100
        #and ct.name = "Parenting"
        #and al.name like "daycount.%"
  group by user, al.name
    #having users > 5
  #order by  overall_prec desc;
  ) as x
  group by alg
  order by prec desc;


## compute comulative prec relative to history size
set @rlevel := 1; ### rank level
set @csum := 0 , @usum := 0;
select days days_in_history,
       (@csum := @csum + xyz) as  prec_sum,
       (@usum := @usum + users) as users_sum ,
       @csum / @usum as prec_avg_rank
from (
  select days ,
         COUNT(1) users,
         SUM(prec) xyz
  from
  (
  select hs.uid user,
         (FLOOR(hs.days / 5)) * 5 days,
         al.name alg,
         SUM(if(rank<=@rlevel,us.choice != 0,0)) correct,
         if( SUM(if(rank<=@rlevel,1,0)) > 0, SUM(if(rank<=@rlevel,us.choice != 0,0)) / SUM(if(rank<=@rlevel,1,0)), 0) prec
  from AlgRanks ar , UserChoice us, Algs al , Cats ct , HistSize hs , CatUserCount catu
  where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid
        and hs.uid = us.uid
        #and hs.country = "United States"
        #and hs.days > 30
        and catu.cid = ct.cid
        #and ar.rank <= 10
        #and ar.score > 5
        and catu.total_shown > 100
        #and ct.name = "Parenting"
        and al.name like "daycount.rules.edrules"
  group by user
    #having users > 5
  #order by  overall_prec desc;
  ) as x
  group by days
  order by days desc
) as y
order by days desc;

#### create comparative table

select t1.days_in_history, t1.prec_avg_rank rank_1_only, t2.prec_avg_rank upto_rank_2, t3.prec_avg_rank upto_rank_3, t4.prec_avg_rank upto_rank_3 from t1,t2,t3,t4 where t1.days_in_history = t2.days_in_history and t2.days_in_history = t3.days_in_history and t3.days_in_history = t4.days_in_history;


# stored procedure to compute combined ranks table
drop PROCEDURE if EXISTS computeHistRanks;
delimiter //
CREATE PROCEDURE computeHistRanks(IN algName CHAR(64), IN x INT)
 BEGIN
    set @rlevel := x; ### rank level
    set @csum := 0 , @usum := 0;
    drop table IF EXISTS tbl;
    create table tbl
    select days days_in_history,
           (@csum := @csum + xyz) as  prec_sum,
           (@usum := @usum + users) as users_sum ,
           @csum / @usum as prec_avg_rank
    from (
      select days ,
             COUNT(1) users,
             SUM(prec) xyz
      from
      (
      select hs.uid user,
             (FLOOR(hs.days / 5)) * 5 days,
             al.name alg,
             SUM(if(rank<=@rlevel,us.choice != 0,0)) correct,
             if( SUM(if(rank<=@rlevel,1,0)) > 0, SUM(if(rank<=@rlevel,us.choice != 0,0)) / SUM(if(rank<=@rlevel,1,0)), 0) prec
      from AlgRanks ar , UserChoice us, Algs al , Cats ct , HistSize hs , CatUserCount catu
      where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid
            and hs.uid = us.uid
            and catu.cid = ct.cid
            and catu.total_shown > 100
            and al.name = algName
      group by user
      ) as x
      group by days
      order by days desc
    ) as y
    order by days desc;
 END;
//
delimiter ;




select hs.uid user, hs.days , ct.name , (us.choice != 0) correct , rank , score
  from AlgRanks ar , UserChoice us, Algs al , Cats ct , HistSize hs , CatUserCount catu
  where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid
        and hs.uid = us.uid
        and hs.country = "United States"
        and hs.days > 5
        and catu.cid = ct.cid
        #and ar.rank = 1
        #and ar.score > 5
        and catu.total_shown > 100
        #and ct.name = "Android"
        and hs.uid = 448
        and al.name = "daycount.combined.edrules_extended"
  order by rank;

select ct.name catn,
        #al.name algn ,
        #SUM(us.isTop5) top_shown,
        COUNT(1) presented,
        #catu.topBasePrec,
        #catu.topBaseF,
        #catu.basePrec basePrec,
        #catu.baseF baseF,
        #SUM(us.choice = 1) top,
        SUM(us.choice != 0) interested,
        ROUND(SUM(us.choice != 0) * 100 / COUNT(1),1) prec,
        ROUND(catu.basePrec * 100 , 1) basePrecision,
        #SUM(us.choice = 1) / SUM(us.isTop5) top_prec,
        #SUM(us.choice != 0) / catu.interested all_recall ,
        #2 * (SUM(us.choice != 0) / COUNT(1) * SUM(us.choice != 0) / catu.interested) / (SUM(us.choice != 0) / COUNT(1) + SUM(us.choice != 0) / catu.interested) allF
        ROUND((SUM(us.choice != 0) / COUNT(1) - catu.basePrec) * 100,1) delta,
        ROUND(((SUM(us.choice != 0) / COUNT(1) - catu.basePrec) / catu.basePrec ) * 100,1) pct
  from AlgRanks ar ,
       UserChoice us,
       Algs al ,
       Cats ct ,
       HistSize hs ,
       CatUserCount catu
  where us.cid = ar.cid
        and us.uid = ar.uid
        and ct.cid = ar.cid
        and al.aid = ar.aid
        and hs.uid = us.uid
        and hs.days > 5
        #and hs.country = "United States"
        and catu.cid = ct.cid
        and ar.rank <= 10
        #and ar.score > 5
        and al.name = "daycount.rules.edrules"
  group by ct.name , al.name
  having presented > 5
         #and catn IN (select cat from CatUserCount where total_shown > 100)
  order by prec desc;

drop table IF EXISTS RankConfidence;
create table IF NOT EXISTS RankConfidence (
    algorithm VARCHAR(64) NOT NULL,
    aid INTEGER UNSIGNED NOT NULL,
    category VARCHAR(64) NOT NULL,
    cid INTEGER UNSIGNED NOT NULL,
    rank INTEGER UNSIGNED,
    confidence FLOAT
  );

load data infile '/Users/maximzhilyaev/quick-upstudy/daycount.all.smothed' into table RankConfidence;

select alg,
         ROUND(AVG(cats),3) cats_shown,
         #ROUND(STD(cats),3) deviation,
         ROUND(AVG(prec) * 100,1) prec
  from
  (
  select hs.uid user, al.name alg, rank,
         SUM(if(rank<=10,1,0)) cats,
         #SUM(us.choice != 0) correct ,
         #SUM(us.choice != 0) / COUNT(1)
         SUM(if(rank<=10,us.choice != 0,0)) correct,
         SUM(if(rank<=10,us.choice != 0,0)) / SUM(if(rank<=10,1,0)) prec
  from AlgRanks ar , UserChoice us, Algs al , Cats ct , HistSize hs , CatUserCount catu
  where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid
        and hs.uid = us.uid
        #and hs.country != "United States"
        #and hs.days >= 50
        and catu.cid = ct.cid
        #and ar.rank <= 10
        #and ar.score > 5
        and catu.total_shown > 100
        #and ct.name = "Parenting"
        and al.name like "daycount.%"
  group by user, al.name
    #having users > 5
  #order by  overall_prec desc;
  ) as x
  group by alg
  order by prec desc;


set @lastu := 0;
set @rank := 1;
select alg, AVG(cats) , AVG(prec) prec
  from
  (
    select alg
     , user
     , SUM(if(rank<=10,1,0)) cats
     , SUM(if(rank<=10,guess,0)) correct
     , SUM(if(rank<=10,guess,0)) / SUM(if(rank<=10,1,0)) prec
    from
    (
      select if( @lastu != user , @rank := 1, @rank := @rank + 1) dummy
        , (@lastu := user) as user
        , cat
        , @rank rank
        , guess
        , alg
        , conf
      from (
        select hs.uid user
               , al.name alg
               , ct.name  cat
               , ar.rank  orank
               , confidence conf
               #SUM(if(rank<=10,1,0)) cats,
               #SUM(us.choice != 0) correct ,
               , (us.choice != 0) guess
               #SUM(us.choice != 0) / COUNT(1)
               #SUM(if(rank<=10,us.choice != 0,0)) correct,
               #SUM(if(rank<=10,us.choice != 0,0)) / SUM(if(rank<=10,1,0)) prec
        from AlgRanks ar , UserChoice us, Algs al , Cats ct , HistSize hs , CatUserCount catu , RankConfidence rc
        where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid
              and rc.cid = ct.cid
              and rc.rank = ar.rank
              and rc.aid = al.aid
              and hs.uid = us.uid
              #and hs.country != "United States"
              #and hs.days >= 50
              and catu.cid = ct.cid
              #and ar.rank <= 10
              #and ar.score > 5
              and catu.total_shown > 100
              #and ct.name = "Parenting"
              #and al.name like "daycount.rules.rules_synthetic"
        order by al.name, user, confidence desc
      ) as x
    ) as y
    group by alg, user
    order by alg, user
  ) as z
  group by alg
  order by prec desc
  ;

select alg,
         ROUND(AVG(checked),3) cats_shown,
         #ROUND(STD(cats),3) deviation,
         ROUND(AVG(prec) * 100,1) prec
  from
  (
  select hs.uid user, al.name alg, ar.rank,
         SUM(if(ar.rank<=10 AND rc.confidence > 0.7,1,0)) checked,
         SUM(if(ar.rank<=10 AND rc.confidence > 0.7,us.choice != 0,0)) correct,
         SUM(if(ar.rank<=10 AND rc.confidence > 0.7,us.choice != 0,0)) / SUM(if(ar.rank<=10 AND rc.confidence > 0.7 ,1,0)) prec
  from AlgRanks ar , UserChoice us, Algs al , Cats ct , HistSize hs , CatUserCount catu , RankConfidence rc
  where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid
        and rc.cid = ct.cid
        and rc.rank = ar.rank
        and rc.aid = al.aid
        and hs.uid = us.uid
        #and hs.country != "United States"
        and hs.days >= 30
        and catu.cid = ct.cid
        #and ar.rank <= 10
        #and ar.score > 5
        and catu.total_shown > 100
        #and ct.name = "Parenting"
        and al.name like "daycount.%"
  group by user, al.name
    #having users > 5
  #order by  overall_prec desc;
  ) as x
  group by alg
  order by prec desc;


# generating uuid to interest mapping
select UUID.name, Cats.name , choice, isTop5 into outfile '/tmp/survey.txt' from UserChoice , Cats , UUID where Cats.cid = UserChoice.cid and UUID.uid = UserChoice.uid and choice > 0 order by UUID.name;

