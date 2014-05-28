

drop table IF EXISTS UUID;
create table IF NOT EXISTS UUID
(
  uid INTEGER UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(64) NOT NULL UNIQUE KEY,
  hasSurveyInterests TINYINT,
  personalizeOn TINYINT,
  installDate BIGINT UNSIGNED,
  version VARCHAR(32),
  locale VARCHAR(128),
  updateDate BIGINT UNSIGNED
);

drop table IF EXISTS Payloads;
create table IF NOT EXISTS Payloads
(
  uuid VARCHAR(64) NOT NULL ,
  days INTEGER UNSIGNED NOT NULL ,
  lastday INTEGER UNSIGNED NOT NULL
);

drop table IF EXISTS HistSize;
create table IF NOT EXISTS HistSize (
  uid INTEGER UNSIGNED NOT NULL,
  days INTEGER UNSIGNED NOT NULL,
  country VARCHAR(64),
  scoresum INTEGER UNSIGNED,
  PRIMARY KEY(uid)
);

drop table IF EXISTS Surveys;
create table IF NOT EXISTS Surveys
(
  uuid VARCHAR(64) NOT NULL,
  ReponseId INTEGER UNSIGNED NOT NULL,
  country VARCHAR(64),
  lang VARCHAR(64),
  submitted VARCHAR(64),
  users INTEGER UNSIGNED,
  PRIMARY KEY(uuid,ReponseId)
);


drop table IF EXISTS Algs;
create table IF NOT EXISTS Algs
(
  aid INTEGER UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(64) NOT NULL UNIQUE KEY
);

drop table IF EXISTS Cats;
create table IF NOT EXISTS Cats
(
  cid INTEGER UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(64) CHARACTER SET latin1 COLLATE latin1_bin UNIQUE KEY
);

drop table IF EXISTS AlgRanks;
create table IF NOT EXISTS AlgRanks (
  uid INTEGER UNSIGNED,
  aid INTEGER UNSIGNED,
  cid INTEGER UNSIGNED,
  score INTEGER UNSIGNED,
  rank INTEGER UNSIGNED,
  PRIMARY KEY (uid,aid,cid)
);

drop table IF EXISTS UserChoice;
create table IF NOT EXISTS UserChoice (
  uid INTEGER UNSIGNED,
  cid INTEGER UNSIGNED,
  choice INTEGER UNSIGNED,  ## 1 for top5 page choice, 2 for aditional page choice
  isTop5 INTEGER UNSIGNED,  ## is it a top5 interest (1 or 0)
  surveyScore INTEGER UNSIGNED,  ## score from survey
  PRIMARY KEY (uid,cid)
);

# alg name is [COUNTING_METHOD]+[NAMESPACE]+[TYPE
drop table IF EXISTS SurveyData;
create table IF NOT EXISTS SurveyData (
  uuid VARCHAR(64) NOT NULL,
  cat VARCHAR(64) NOT NULL,
  choice INTEGER UNSIGNED ,
  isTop5 INTEGER UNSIGNED ,
  surveyScore INTEGER UNSIGNED
);

drop table IF EXISTS CatStats;
create table CatStats (
  aid INTEGER UNSIGNED,
  cid INTEGER UNSIGNED,
  total INTEGER UNSIGNED,
  onTopPage INTEGER UNSIGNED,
  top INTEGER UNSIGNED,
  additional INTEGER UNSIGNED,
  hit INTEGER UNSIGNED
);

drop table IF EXISTS SubmissionData;
create table IF NOT EXISTS SubmissionData (
  user_id INTEGER UNSIGNED NOT NULL,
  type_id INTEGER UNSIGNED NOT NULL,
  namesapce_id INTEGER UNSIGNED NOT NULL,
  interest_id INTEGER UNSIGNED NOT NULL,
  day INTEGER UNSIGNED NOT NULL,
  hostCount VARCHAR(1024) NOT NULL,
  PRIMARY KEY(user_id,day,type_id,namesapce_id,interest_id)
);

drop table IF EXISTS ScriptData;
create table IF NOT EXISTS ScriptData (
  uuid VARCHAR(64) NOT NULL,
  alg VARCHAR(64) NOT NULL,
  cat VARCHAR(64) NOT NULL,
  score INTEGER UNSIGNED,
  rank INTEGER UNSIGNED
);

drop table IF EXISTS NYTUserData;
create table IF NOT EXISTS NYTUserData (
  uuid VARCHAR(64),
  ts BIGINT UNSIGNED,
  hasId TINYINT,
  webSub TINYINT,
  hdSub TINYINT,
  mobSub TINYINT,
  aritcleViews INTEGER UNSIGNED
);

drop table IF EXISTS NYTUser;
create table IF NOT EXISTS NYTUser (
  uid INTEGER UNSIGNED NOT NULL,
  ts BIGINT UNSIGNED,
  hasId TINYINT,
  webSub TINYINT,
  hdSub TINYINT,
  mobSub TINYINT,
  aritcleViews INTEGER UNSIGNED,
  PRIMARY KEY (uid, ts)
);

drop table IF EXISTS NYTVisitData;
create table IF NOT EXISTS NYTVisitData (
  uuid VARCHAR(64),
  ts BIGINT UNSIGNED,
  visitId INTEGER UNSIGNED,
  fromId INTEGER UNSIGNED,
  path VARCHAR(256),
  query VARCHAR(256),
  host VARCHAR(64),
  version VARCHAR(32)
);

drop table IF EXISTS NYTVisit;
create table IF NOT EXISTS NYTVisit (
  uid INTEGER UNSIGNED NOT NULL,
  ts BIGINT UNSIGNED,
  visitId INTEGER UNSIGNED,
  fromId INTEGER UNSIGNED,
  path VARCHAR(256),
  query VARCHAR(256),
  host VARCHAR(64),
  version VARCHAR(32),
  PRIMARY KEY (uid, ts, visitId, fromId)
);


