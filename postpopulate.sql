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

### NYT population
drop table IF EXISTS Subscriber;
create table IF NOT EXISTS Subscriber (
  uid INTEGER UNSIGNED NOT NULL,
  isSubscriber TINYINT,
  since BIGINT UNSIGNED,
  PRIMARY KEY (uid)
);

# populate subscriber table
# select submissions that haapen close to the install date
insert into Subscriber select distinct(uid), 0, 0 from NYTUser;

# if timstamp of the nyt user record within 1 days of install - assume it was subscriber always
# otherwise take the timestamp
replace into Subscriber
select NYTUser.uid, webSub, if(UUID.uid = NYTUser.uid AND (ts - updateDate) / 1000000 / 3600 / 24 < 1, 0, ts) since
  from NYTUser, UUID
  where UUID.uid = NYTUser.uid AND webSub = 1 order by ts;

drop table IF EXISTS UserGroupVisits;
create table IF NOT EXISTS  UserGroupVisits(
  uid INTEGER UNSIGNED NOT NULL,
  isSubscriber TINYINT,
  isControlGroup  TINYINT,
  isBefore  TINYINT,
  visitTs BIGINT UNSIGNED,
  subscribedTs BIGINT UNSIGNED,
  installTs BIGINT UNSIGNED
);

### populate table UserGroupVisits
### user is a subscriber if isSubscriber == 1 and visist ts > since
insert into UserGroupVisits
select NYTVisit.uid,
       if(isSubscriber AND ts > since, 1, 0) isSubscriber,
       personalizeOn isControlGroup,
       if(installDate > ts, 1, 0) isBefore,
       ts,
       since subscriptionDate,
       installDate
  from NYTVisit, UUID, Subscriber
  where NYTVisit.uid = UUID.uid AND NYTVisit.uid = Subscriber.uid
;

drop table IF EXISTS UserGroupTimeSpan;
create table IF NOT EXISTS  UserGroupTimeSpan(
  uid INTEGER UNSIGNED NOT NULL,
  isSubscriber TINYINT,
  isControlGroup  TINYINT,
  isBefore  TINYINT,
  ### timeSpan is the time in micro seconds that user was a part a particulat group
  timeSpan BIGINT UNSIGNED,
  PRIMARY KEY (uid, isSubscriber, isControlGroup, isBefore)
);


#### needed for stats computation
set @nytTotal := (select count(1) from NYTVisit);
set @nytArticles := (select sum(if(INSTR(path,"TITLE") != 0,1,0)) from NYTVisit);
set @amoPush = 1393986123000000;

create table UUID_NYT
select * from UUID
 where version >= "3.0.1"
    and installDate >= 1393986123000000;

insert into UserGroupTimeSpan
select NYTVisit.uid uid,
       if(isSubscriber AND ts > since, 1, 0) isSubscriber,
       personalizeOn isControlGroup,
       if(installDate > ts, 1, 0) isBefore,
       if(installDate > ts,
          ### for pre-install histories: if min(ts) is less then installDate, take the difference, otherwise assume 1 month
          if(min(ts) < installDate,
            installDate - min(ts),
            60*60*24*30*1000000
          ),
          ### for after install we have to handle a situation when a user becomes a subscriber after install
          if(isSubscriber,
            ### so the user had subscribed
            if(since < installDate,
               ### the user was a subscriber when addon installed
               UNIX_TIMESTAMP()*1000000 - installDate,
               ### the user subscribed between now and install date
               if(ts < since,
                  since - installDate,  ### not subscriber yet
                  UNIX_TIMESTAMP()*1000000 - since  ### is a subscriber
               )
            ),
            ### not a subscriber - use difference between now and install date
            UNIX_TIMESTAMP()*1000000 - installDate
          )
        ) timeSpan
  from NYTVisit, UUID, Subscriber
  where NYTVisit.uid = UUID.uid AND NYTVisit.uid = Subscriber.uid
  group by uid, isSubscriber, isControlGroup, isBefore
;

