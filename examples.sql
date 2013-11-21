
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

#### show how categories were presented and choosen by a user
select Cats.name ,
       sum(choice = 1) as topInterested ,
       sum(if(choice != 0,1,0)) as interested ,
       sum(isTop5) as onFirstPage,
       sum(1) as overAll
from UserChoice, Cats
where Cats.cid = UserChoice.cid
group by Cats.name
order by interested desc;

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
where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid and al.name = "daycount.combined.edrules"
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
      and ar.rank <= 5
      and ar.score > 5
      and al.name = "daycount.rules.edrules"
group by al.name , ct.name
order by all_prec desc;

#### compute and AVG precision for an alg
select name alg, AVG(top_prec) top_precision_avg, AVG(overall_precision) overall_precision_avg, AVG(users) user_reach_avg
from
 (select al.name as name, ct.name as cat , COUNT(1) as users, SUM(us.choice = 1) / SUM(us.isTop5) as top_prec, SUM(us.choice != 0) / COUNT(1) as overall_precision
  from AlgRanks ar , UserChoice us, Algs al , Cats ct , HistSize hs
  where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid
      and hs.uid = us.uid
      and hs.days > 5
      and ar.rank <= 5
      and ar.score > 5
  group by al.name , ct.name
  having users > 5
 ) as apres
group by name
order by overall_precision_avg desc;


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
      and ar.rank <= 5
      and ar.score > 5
      and ct.name = "Sports"
group by al.name , ct.name
having total_shown > 5
order by all_prec desc;

# compute all algs perf for all cats
select ct.name interest, al.name alg,
       COUNT(1) users,
       SUM(us.choice = 1) / SUM(us.isTop5) top_prec,
       SUM(us.choice != 0) / COUNT(1) overall_prec
from AlgRanks ar , UserChoice us, Algs al , Cats ct , HistSize hs
where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid
      and hs.uid = us.uid
      and hs.days > 5
      and ar.rank <= 10
      and ar.score > 5
      and ct.name = "Entrepreneur"
group by al.name , ct.name
having users > 5
order by interest, overall_prec desc;


# compute number of interest an alg assigns to a user
select name alg, AVG(cnumber) assigned_cats, COUNT(1) users
from (
select al.name as name, us.uid as uid, count(DISTINCT(ct.cid)) as cnumber
from AlgRanks ar , UserChoice us, Algs al , Cats ct , HistSize hs
where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid
  and hs.uid = us.uid
  and hs.days > 5
  and ar.rank <= 5
  and ar.score > 5
group by al.name , us.uid
) as ausers
group by alg
having users > 5;





