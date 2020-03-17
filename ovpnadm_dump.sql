-- MySQL dump 10.13  Distrib 5.7.29, for Linux (x86_64)
--
-- Host: localhost    Database: ovpnadm
-- ------------------------------------------------------
-- Server version	5.7.29-0ubuntu0.16.04.1

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `clientlogin`
--

DROP TABLE IF EXISTS `clientlogin`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `clientlogin` (
  `cid` int(11) NOT NULL DEFAULT '0',
  `login` timestamp NULL DEFAULT NULL,
  `state` enum('y','n') DEFAULT NULL,
  KEY `cid` (`cid`),
  KEY `login` (`login`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COMMENT='utf8_general_ci';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `clientlogin`
--

--
-- Table structure for table `clients`
--

DROP TABLE IF EXISTS `clients`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `clients` (
  `clients_id` int(11) NOT NULL AUTO_INCREMENT,
  `subject` char(255) DEFAULT '',
  `country` char(2) DEFAULT '',
  `state` char(255) DEFAULT '',
  `orga` char(255) DEFAULT '',
  `orgunit` char(255) DEFAULT '',
  `cname` char(255) DEFAULT '',
  `email` char(255) DEFAULT '',
  `pass` char(255) DEFAULT '',
  `serial` char(10) DEFAULT '',
  `active` enum('y','n') DEFAULT 'y',
  `cert` text,
  `certkey` text,
  `reminder` datetime DEFAULT NULL,
  `comment` varchar(255) DEFAULT NULL,
  `auth_secret` varchar(255) DEFAULT NULL,
  `auth_token` varchar(255) DEFAULT NULL,
  PRIMARY KEY (`clients_id`),
  KEY `subject` (`subject`),
  KEY `email` (`email`),
  KEY `cname` (`cname`),
  KEY `active` (`active`)
) ENGINE=InnoDB AUTO_INCREMENT=83 DEFAULT CHARSET=utf8 COMMENT='utf8_general_ci';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `clients`
--



--
-- Table structure for table `clients2groups`
--

DROP TABLE IF EXISTS `clients2groups`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `clients2groups` (
  `cid` int(11) NOT NULL DEFAULT '0',
  `grpid` int(11) DEFAULT NULL,
  KEY `cid` (`cid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `clients2groups`
--

--
-- Table structure for table `grp2network`
--

DROP TABLE IF EXISTS `grp2network`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `grp2network` (
  `grpid` int(11) NOT NULL DEFAULT '0',
  `netid` int(11) DEFAULT NULL,
  KEY `grpid` (`grpid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `grp2network`
--

--
-- Table structure for table `network_groups`
--

DROP TABLE IF EXISTS `network_groups`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `network_groups` (
  `network_groups_id` int(11) NOT NULL AUTO_INCREMENT,
  `grpname` char(255) DEFAULT NULL,
  PRIMARY KEY (`network_groups_id`)
) ENGINE=InnoDB AUTO_INCREMENT=15 DEFAULT CHARSET=utf8 COMMENT='utf8_general_ci';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `network_groups`
--


--
-- Table structure for table `networks`
--

DROP TABLE IF EXISTS `networks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `networks` (
  `networks_id` int(11) NOT NULL AUTO_INCREMENT,
  `network` char(15) DEFAULT NULL,
  `mask` char(15) DEFAULT NULL,
  `name` char(255) DEFAULT NULL,
  PRIMARY KEY (`networks_id`),
  UNIQUE KEY `name` (`name`)
) ENGINE=InnoDB AUTO_INCREMENT=23 DEFAULT CHARSET=utf8 COMMENT='utf8_general_ci';
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `networks`
--
