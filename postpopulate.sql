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
drop table IF EXISTS CatUserCount;
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
