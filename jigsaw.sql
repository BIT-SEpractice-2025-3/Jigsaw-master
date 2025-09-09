-- MySQL dump 10.13  Distrib 9.4.0, for Linux (x86_64)
--
-- Host: localhost    Database: jigsaw
-- ------------------------------------------------------
-- Server version	9.4.0

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `game_saves`
--

DROP TABLE IF EXISTS `game_saves`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `game_saves` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `save_name` varchar(100) NOT NULL,
  `difficulty` varchar(20) NOT NULL DEFAULT 'easy',
  `progress` decimal(5,2) DEFAULT '0.00' COMMENT '游戏进度百分比',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `game_mode` varchar(20) DEFAULT 'classic',
  `elapsed_seconds` int DEFAULT '0',
  `current_score` int DEFAULT '0',
  `image_source` varchar(255) DEFAULT '',
  `placed_pieces_ids` json DEFAULT NULL,
  `available_pieces_ids` json DEFAULT NULL,
  `master_pieces` longtext,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_user_save` (`user_id`,`save_name`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_game_saves_game_mode` (`game_mode`),
  KEY `idx_game_saves_user_game_difficulty` (`user_id`,`game_mode`,`difficulty`),
  CONSTRAINT `game_saves_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=218 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `game_saves`
--

LOCK TABLES `game_saves` WRITE;
/*!40000 ALTER TABLE `game_saves` DISABLE KEYS */;
INSERT INTO `game_saves` VALUES (215,1,'auto_save_1757328667','1',20.00,'2025-09-08 10:51:07','2025-09-08 10:51:08','classic',2,1246,'assets/images/default_puzzle.jpg','[null, null, null, null, null, null, 6, 7, 8]','[0, 1, 2, 3, 4, 5]','[]');
/*!40000 ALTER TABLE `game_saves` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `scores`
--

DROP TABLE IF EXISTS `scores`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `scores` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `score` int NOT NULL,
  `difficulty` varchar(20) NOT NULL DEFAULT 'easy',
  `time_taken` int NOT NULL COMMENT '完成时间（秒）',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_score` (`score`),
  KEY `idx_difficulty` (`difficulty`),
  KEY `idx_created_at` (`created_at`),
  CONSTRAINT `scores_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=19 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `scores`
--

LOCK TABLES `scores` WRITE;
/*!40000 ALTER TABLE `scores` DISABLE KEYS */;
INSERT INTO `scores` VALUES (16,1,1470,'easy',15,'2025-09-08 10:50:54'),(17,1,1918,'medium',16,'2025-09-08 10:51:28'),(18,2,1470,'easy',15,'2025-09-08 10:57:09');
/*!40000 ALTER TABLE `scores` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `users`
--

DROP TABLE IF EXISTS `users`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `username` varchar(50) NOT NULL,
  `email` varchar(100) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  UNIQUE KEY `email` (`email`),
  KEY `idx_username` (`username`),
  KEY `idx_email` (`email`)
) ENGINE=InnoDB AUTO_INCREMENT=3 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `users`
--

LOCK TABLES `users` WRITE;
/*!40000 ALTER TABLE `users` DISABLE KEYS */;
INSERT INTO `users` VALUES (1,'test1','1@123.com','96cae35ce8a9b0244178bf28e4966c2ce1b8385723a96a6b838858cdd6ca0a1e','2025-09-08 08:35:19','2025-09-08 08:35:19'),(2,'test2','2@123.com','96cae35ce8a9b0244178bf28e4966c2ce1b8385723a96a6b838858cdd6ca0a1e','2025-09-08 09:35:35','2025-09-08 09:35:35');
/*!40000 ALTER TABLE `users` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

CREATE TABLE `friendships` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `user_one_id` INT NOT NULL,
  `user_two_id` INT NOT NULL,
  `status` ENUM('pending', 'accepted', 'blocked') NOT NULL DEFAULT 'pending',
  `action_user_id` INT NOT NULL COMMENT '执行最后一次操作的用户ID',
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `unique_friendship` (`user_one_id`, `user_two_id`),
  KEY `idx_user_one` (`user_one_id`),
  KEY `idx_user_two` (`user_two_id`),
  CONSTRAINT `fk_friendships_user_one` FOREIGN KEY (`user_one_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_friendships_user_two` FOREIGN KEY (`user_two_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_friendships_action_user` FOREIGN KEY (`action_user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


CREATE TABLE `matches` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `challenger_id` INT NOT NULL COMMENT '发起挑战的用户ID',
  `opponent_id` INT NOT NULL COMMENT '接受挑战的用户ID',
  `status` ENUM('pending', 'accepted', 'in_progress', 'completed', 'cancelled', 'declined') NOT NULL DEFAULT 'pending',
  `difficulty` VARCHAR(20) NOT NULL,
  `image_source` VARCHAR(255) NOT NULL,
  `winner_id` INT DEFAULT NULL,
  `challenger_time_ms` INT DEFAULT NULL COMMENT '挑战者完成时间（毫秒）',
  `opponent_time_ms` INT DEFAULT NULL COMMENT '应战者完成时间（毫秒）',
  `created_at` TIMESTAMP NULL DEFAULT CURRENT_TIMESTAMP,
  `started_at` TIMESTAMP NULL DEFAULT NULL,
  `completed_at` TIMESTAMP NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_challenger` (`challenger_id`),
  KEY `idx_opponent` (`opponent_id`),
  KEY `idx_winner` (`winner_id`),
  CONSTRAINT `fk_matches_challenger` FOREIGN KEY (`challenger_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_matches_opponent` FOREIGN KEY (`opponent_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_matches_winner` FOREIGN KEY (`winner_id`) REFERENCES `users` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;




/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2025-09-08 11:09:02
