

drop table IF EXISTS UUID;
create table IF NOT EXISTS UUID
(
  uid INTEGER UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(64) NOT NULL UNIQUE KEY
);

drop table IF EXISTS Payloads;
create table IF NOT EXISTS Payloads
(
  uuid VARCHAR(64) NOT NULL
);

drop table IF EXISTS Surveys;
create table IF NOT EXISTS Surveys
(
  uuid VARCHAR(64) NOT NULL,
  ReponseId INTEGER UNSIGNED NOT NULL,
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

drop table IF EXISTS UserScore;
create table IF NOT EXISTS UserScore (
  uid INTEGER UNSIGNED,
  cid INTEGER UNSIGNED,
  score INTEGER UNSIGNED,
  PRIMARY KEY (uid,cid)
);

drop table IF EXISTS ScriptData;
create table IF NOT EXISTS ScriptData (
  uuid VARCHAR(64) NOT NULL,
  alg VARCHAR(64) NOT NULL,
  cat VARCHAR(64) NOT NULL,
  score INTEGER UNSIGNED,
  rank INTEGER UNSIGNED
);

drop table IF EXISTS SurveyData;
create table IF NOT EXISTS SurveyData (
  uuid VARCHAR(64) NOT NULL,
  cat VARCHAR(64) NOT NULL,
  score INTEGER UNSIGNED
);




