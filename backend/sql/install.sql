# TABLE attributes
DROP TABLE IF EXISTS attributes;
CREATE TABLE attributes
(
  id INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
  name VARCHAR(64) UNIQUE NOT NULL
);

# TABLE user_attributes
DROP TABLE IF EXISTS user_attributes;
CREATE TABLE user_attributes
(
  id INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
  uid VARCHAR(36) NOT NULL,
  attribute INT NOT NULL,
  value TEXT NOT NULL
);

# TABLE response_log
DROP TABLE IF EXISTS response_log;
CREATE TABLE response_log
(
  id INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
  type VARCHAR(10),
  code VARCHAR(48),
  message VARCHAR(256),
  response_time TIMESTAMP NOT NULL DEFAULT NOW(),
  user_id VARCHAR(36),
  user_ip VARCHAR(39),
  error_raw TEXT
);

# TABLE check_in
DROP TABLE IF EXISTS check_in;
CREATE TABLE check_in
(
  id INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
  uid VARCHAR(36),
  checkin_time TIMESTAMP NOT NULL DEFAULT NOW(),
  rating DOUBLE,
  message TEXT,
  image_id VARCHAR(32),
  location TEXT,
  recipients VARCHAR(128),
  type VARCHAR(12),
  flag_request BOOLEAN NOT NULL DEFAULT FALSE
);

# TABLE others_check_in
DROP TABLE IF EXISTS check_in_others;
CREATE TABLE check_in_others
(
  id INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
  recipient_uid VARCHAR(36) NOT NULL,
  checkin_id INT NOT NULL
);

# TABLE recipients
DROP TABLE IF EXISTS recipients;
CREATE TABLE recipients
(
  id INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
  owner VARCHAR(36) NOT NULL,
  uid VARCHAR(36),
  phone_number VARCHAR(16),
  email VARCHAR(254),
  name VARCHAR(64),
  deleted BOOLEAN DEFAULT FALSE
);

DROP TABLE IF EXISTS fcm_tokens;
CREATE TABLE fcm_tokens
(
  device_id VARCHAR(32) PRIMARY KEY NOT NULL,
  uid VARCHAR(36) NOT NULL,
  token TEXT NOT NULL,
  update_timestamp TIMESTAMP NOT NULL DEFAULT NOW()
);

DROP TABLE IF EXISTS devices;
CREATE TABLE devices
(
  device_id varchar(32) PRIMARY KEY NOT NULL,
  uid VARCHAR(36) NOT NULL
);

DROP TABLE IF EXISTS activity;
CREATE TABLE activity
(
  id INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
  checkin_id INT,
  uid VARCHAR(36) NOT NULL,
  title VARCHAR(64),
  summary VARCHAR(256),
  message TEXT,
  type VARCHAR(12),
  send_timestamp TIMESTAMP DEFAULT NOW(),
  viewed BOOLEAN NOT NULL DEFAULT FALSE
);

DROP TABLE IF EXISTS feedback;
CREATE TABLE feedback
(
  id INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
  timestamp DATETIME DEFAULT NOW(),
  type VARCHAR(32) NOT NULL,
  message TEXT NOT NULL
);

DROP TABLE IF EXISTS email_blacklist;
CREATE TABLE email_blacklist(
  id INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
  timestamp DATETIME DEFAULT NOW(),
  email VARCHAR(254)
);

# attributes.sql
DELETE FROM attributes;

INSERT INTO attributes (name) VALUE ('AGE');
INSERT INTO attributes (name) VALUE ('GENDER');
INSERT INTO attributes (name) VALUE ('SETTINGS');
INSERT INTO attributes (name) VALUE ('TIMEZONE');
