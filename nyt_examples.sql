#### create subscriber table
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
select NYTUser.uid, webSub, if(UUID.uid = NYTUser.uid AND (ts - installDate) / 1000000 / 3600 / 24 < 1, 0, ts) since 
  from NYTUser, UUID 
  where UUID.uid = NYTUser.uid AND webSub = 1 order by ts;

### example of how to compute a week from timestamp
select DATE_FORMAT(FROM_UNIXTIME(UNIX_TIMESTAMP()),"%Y.%U");

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
  ### uncomment the line bellow to count recommendation clicks instead of page loads
  # AND NYTVisit.query like "%src=rec%"
;

### compute total visits per user for isSubscriber x isControlGroup x isBefore
select isControlGroup, isSubscriber, isBefore
       , count(distinct(uid)) users
       , count(1) loads
       , count(1) / count(distinct(uid)) avgPerUser
  from UserGroupVisits
  group by isControlGroup, isSubscriber, isBefore
;

### compute distinct visit days  visits per user for user groups
select isControlGroup, isSubscriber, isBefore 
       , count(distinct(uid)) users
       , count(distinct(DATE_FORMAT(FROM_UNIXTIME(visitTs/1000000),"%Y.%m.%d"))) days
       , count(distinct(uid)) users
       , count(distinct(DATE_FORMAT(FROM_UNIXTIME(visitTs/1000000),"%Y.%m.%d"))) / count(distinct(uid)) daysPerUser
  from UserGroupVisits
  group by isControlGroup, isSubscriber, isBefore
;

#### compute intraday frequency per user
select uid, isControlGroup, isSubscriber, isBefore
       ,count(distinct(DATE_FORMAT(FROM_UNIXTIME(visitTs/1000000),"%Y.%m.%d"))) dayCount
       ,count(1) loads
       ,count(1) / count(distinct(DATE_FORMAT(FROM_UNIXTIME(visitTs/1000000),"%Y.%m.%d"))) avgLoadsPerVisitDay
  from UserGroupVisits
  group by uid, isControlGroup, isSubscriber, isBefore
;

### compute average intraday frequency for each group
select isControlGroup, isSubscriber, isBefore
       , count(distinct(uid)) users
       , AVG(avgLoadsPerVisitDay)
  from (
    select uid, isControlGroup, isSubscriber, isBefore
         ,count(distinct(DATE_FORMAT(FROM_UNIXTIME(visitTs/1000000),"%Y.%m.%d"))) dayCount
         ,count(1) loads
         ,count(1) / count(distinct(DATE_FORMAT(FROM_UNIXTIME(visitTs/1000000),"%Y.%m.%d"))) avgLoadsPerVisitDay
    from UserGroupVisits
    group by uid, isControlGroup, isSubscriber, isBefore
   ) as x
   group by isControlGroup, isSubscriber, isBefore
;


### table to record time spans for various groups
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

#### compute weekly frequency per user
select uv.uid, uv.isControlGroup, uv.isSubscriber, uv.isBefore
       , count(1) loads
       , timeSpan / 1000000 / 3600 / 24 / 7 weeks
       , count(1) / (timeSpan / 1000000 / 3600 / 24 / 7) pageViewsPerWeek
  from UserGroupVisits uv, UserGroupTimeSpan ut
  where uv.uid = ut.uid 
        AND uv.isControlGroup = ut.isControlGroup
        AND uv.isSubscriber = ut.isSubscriber
        AND uv.isBefore = ut.isBefore
  group by uid, isControlGroup, isSubscriber, isBefore
;

### compute average weekly frequency for each group
select isControlGroup, isSubscriber, isBefore, count(distinct(uid)) users, AVG(pageViewsPerWeek)
  from (
    select uv.uid, uv.isControlGroup, uv.isSubscriber, uv.isBefore
         , count(1) loads
         , timeSpan / 1000000 / 3600 / 24 / 7 weeks
         , count(1) / (timeSpan / 1000000 / 3600 / 24 / 7) pageViewsPerWeek
    from UserGroupVisits uv, UserGroupTimeSpan ut
    where uv.uid = ut.uid 
          AND uv.isControlGroup = ut.isControlGroup
          AND uv.isSubscriber = ut.isSubscriber
          AND uv.isBefore = ut.isBefore
    group by uid, isControlGroup, isSubscriber, isBefore
  ) as x
  group by isControlGroup, isSubscriber, isBefore
;
