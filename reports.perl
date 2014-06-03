my $VAR1 = {
  _CONF => {
    outdir => "reports"
  },
  "Users Stats" => [
    {
      title => "Total Number of Users",
      query => "select count(1) users from UUID;"
    },
    {
      title => "Users by addon version",
      query => "select version, count(1) total_users, sum(if( uuid is not NULL, 1, 0)) surveyed_users
                from (select version, name, uuid from UUID left join Surveys on Surveys.uuid = UUID.name) as x group by version;"
    },
    {
      title => "Users by history size",
      query => "select round(days / 5 + 1)*5 up_to_days, count(1) users from HistSize group by up_to_days;"
    },
    {
      title => "Users by Country",
      query => "select country, count(1) users from Surveys group by country order by users desc limit 100;"
    }
  ],
  "Interests Stats" => [
    {
      title => "Base line precision and usage",
      query => 'select cat, total_shown presented, interested, basePrec basePrecision from CatUserCount order by basePrecision desc;'
    },
    {
      title => "Base line precision and usage of US vs. non-US population",
      query => '
        select us.* , non.presented non_us_presented, non.interested non_us_interested,
               non.basePrecision non_us_basePrecision, us.basePrecision - non.basePrecision delta
          from (
          select Cats.name ,
                 sum(1) as presented ,
                 sum(if(choice != 0,1,0)) as interested ,
                 ROUND(sum(choice = 1) * 100/ sum(1),1)  basePrecision
          from UserChoice, Cats , HistSize
          where Cats.cid = UserChoice.cid
                and HistSize.uid = UserChoice.uid
                and HistSize.country = "United States"
                #and HistSize.days > 5
          group by Cats.name
          ) as us
          join
          (
          select Cats.name ,
                 sum(1) as presented ,
                 sum(if(choice != 0,1,0)) as interested ,
                 ROUND(sum(choice = 1) * 100/ sum(1),1)  basePrecision
          from UserChoice, Cats , HistSize
          where Cats.cid = UserChoice.cid
                and HistSize.uid = UserChoice.uid
                and HistSize.country != "United States"
                #and HistSize.days > 5
          group by Cats.name
          ) as non
          on us.name = non.name
          order by us.basePrecision desc;
      '
    },
    {
      title => "Current Performance for 'daycount.combined.edrules' algorithm",
      query => '
        select ct.name as cat ,
               COUNT(1) as users,
               SUM(us.choice != 0) / COUNT(1) as prec,
               catu.basePrec basePrecision,
               SUM(us.choice != 0) / catu.interested as total_recall
        from AlgRanks ar , UserChoice us, Algs al , Cats ct , HistSize hs, CatUserCount catu
        where us.cid = ar.cid
            and us.uid = ar.uid
            and ct.cid = ar.cid
            and al.aid = ar.aid
            and al.name = "daycount.combined.edrules"
            and catu.cid = ct.cid
            and hs.uid = us.uid
            and hs.days > 5
            #and hs.country = "United States"
            and ar.rank <= 10
            #and ar.score > 5
        group by al.name , ct.name
        having users > 5
              and  cat IN (select cat from CatUserCount where total_shown > 100)
        order by prec desc;'
    },
    {
      title => "Most Accurate Algorithms per Interest",
      query => '
        select cat category , name alg, prec total_precision, basePrecision, total_recall, users user_reach_avg,
             users / (select count(1) from HistSize where days > 5) as pct_of_total_users
        from
         (select al.name as name,
                 ct.name as cat ,
                 COUNT(1) as users,
                 SUM(us.choice != 0) / COUNT(1) as prec,
                 catu.basePrec basePrecision,
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
     '
    },
    {
      title => "Best Coverage Algorithms per Interest",
      query => '
        select cat category , name alg, prec total_precision, basePrecision, total_recall, users user_reach_avg,
             users / (select count(1) from HistSize where days > 5) as pct_of_total_users
        from
         (select al.name as name,
                 ct.name as cat ,
                 COUNT(1) as users,
                 SUM(us.choice != 0) / COUNT(1) as prec,
                 catu.basePrec basePrecision,
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
          order by total_recall desc
         ) as apres
        group by category
        order by total_precision desc;
     '
    },
  ],
  "Algorithms Stats" => [
    {
      title => "Average metrics across all categories",
      query => '
        select name alg, count(distinct(cat)) catnb,
               ROUND(AVG(overall_precision),3) precision_avg,
               ROUND(AVG(overall_recall),3) recall_avg,
               ROUND(AVG(overallF),3) f_avg
        from
         (select al.name as name, ct.name as cat , COUNT(1) as users,
                 SUM(us.choice = 1) / SUM(us.isTop5) as top_prec,
                 SUM(us.choice != 0) / COUNT(1) as overall_precision ,
                 SUM(us.choice != 0) / catu.interested overall_recall ,
                 2 * (SUM(us.choice != 0) / COUNT(1) * SUM(us.choice != 0) / catu.interested) / (SUM(us.choice != 0) / COUNT(1) +
                 SUM(us.choice != 0) / catu.interested) overallF
          from AlgRanks ar , UserChoice us, Algs al , Cats ct , HistSize hs, CatUserCount catu
          where us.cid = ar.cid and us.uid = ar.uid and ct.cid = ar.cid and al.aid = ar.aid
              and hs.uid = us.uid
              and hs.days > 5
              and (hs.scoresum / hs.days ) > 0
              and catu.cid = ar.cid
              and ar.rank <= 10
          group by al.name , ct.name
          having users > 5
            and cat IN (select cat from CatUserCount where total_shown > 100)
         ) as apres
        group by name
      order by f_avg desc;'
    },
    {
      title => "Improvement over base line for daycount.combined.edrules",
      query => '
      select ct.name catn,
        COUNT(1) presented,
        SUM(us.choice != 0) interested,
        ROUND(SUM(us.choice != 0) * 100 / COUNT(1),1) prec,
        ROUND(catu.basePrec * 100 , 1) basePrecision,
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
            and al.name = "daycount.rules.edrules"
      group by ct.name , al.name
      having presented > 5
      order by prec desc;'
    },
    {
      title => "Improvement over base line for daycount.rules.edrules",
      query => '
      select ct.name catn,
        #al.name algn ,
        COUNT(1) presented,
        SUM(us.choice != 0) interested,
        ROUND(SUM(us.choice != 0) * 100 / COUNT(1),1) prec,
        ROUND(catu.basePrec * 100 , 1) basePrecision,
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
            and al.name = "daycount.combined.edrules"
      group by ct.name , al.name
      having presented > 5
      order by prec desc;'
    },
    {
      title => "Precision dependency on history for daycount.combined.edrules algorithm",
      query => '
        call computeHistRanks("daycount.combined.edrules", 1);
        drop table IF EXISTS t1;
        create table t1 select * from tbl;
        call computeHistRanks("daycount.combined.edrules", 2);
        drop table IF EXISTS t2;
        create table t2 select * from tbl;
        call computeHistRanks("daycount.combined.edrules", 3);
        drop table IF EXISTS t3;
        create table t3 select * from tbl;
        call computeHistRanks("daycount.combined.edrules", 4);
        drop table IF EXISTS t4;
        create table t4 select * from tbl;
        select t1.days_in_history,
               t1.prec_avg_rank rank_1_only,
               t2.prec_avg_rank upto_rank_2,
               t3.prec_avg_rank upto_rank_3,
               t4.prec_avg_rank upto_rank_4
        from t1,t2,t3,t4
        where t1.days_in_history = t2.days_in_history
              and t2.days_in_history = t3.days_in_history
              and t3.days_in_history = t4.days_in_history;
      '
    },
    {
      title => "Precision dependency on history for daycount.rules.edrules algorithm",
      query => '
        call computeHistRanks("daycount.rules.edrules", 1);
        drop table IF EXISTS t1;
        create table t1 select * from tbl;
        call computeHistRanks("daycount.rules.edrules", 2);
        drop table IF EXISTS t2;
        create table t2 select * from tbl;
        call computeHistRanks("daycount.rules.edrules", 3);
        drop table IF EXISTS t3;
        create table t3 select * from tbl;
        call computeHistRanks("daycount.rules.edrules", 4);
        drop table IF EXISTS t4;
        create table t4 select * from tbl;
        select t1.days_in_history,
               t1.prec_avg_rank rank_1_only,
               t2.prec_avg_rank upto_rank_2,
               t3.prec_avg_rank upto_rank_3,
               t4.prec_avg_rank upto_rank_4
        from t1,t2,t3,t4
        where t1.days_in_history = t2.days_in_history
              and t2.days_in_history = t3.days_in_history
              and t3.days_in_history = t4.days_in_history;
      '
    }
  ],
};
