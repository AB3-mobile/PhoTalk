-- =====================================================================
-- PhoTalk 메신저 + 사진 스키마 (MySQL 8.0)
-- DB: PhoTalk_db
--
-- - 모든 CREATE는 IF NOT EXISTS → 이미 있는 테이블은 건너뜀
--   (기존 테이블 구조를 바꾸려면 아래 DROP 구간 주석을 풀고 실행)
-- - 문자셋·정렬규칙은 DB 기본값을 따름 (FK로 연결된 문자열 컬럼끼리
--   정렬규칙이 다르면 FK 생성 오류가 나기 때문)
-- =====================================================================
CREATE DATABASE IF NOT EXISTS PhoTalk_db
  DEFAULT CHARACTER SET utf8mb4;
USE PhoTalk_db;

-- ---------------------------------------------------------------------
-- (선택) 기존 메신저/사진 테이블 초기화 — 데이터가 모두 삭제됨!
-- 자식 테이블부터 지워야 FK 오류가 나지 않음
-- ---------------------------------------------------------------------
-- SET FOREIGN_KEY_CHECKS = 0;
-- DROP TABLE IF EXISTS photo_face, photo_data, photo,
--   message_keyword, participant, message_block,
--   chatroom_relationship, people_photo, chatroom_people,
--   message_summarize, message_mood, known_person, chatroom;
-- SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- 1. 사용자 / 질의
-- =====================================================================
CREATE TABLE IF NOT EXISTS `user` (
  `user_id`  CHAR(36) NOT NULL,
  CONSTRAINT `PK_USER` PRIMARY KEY (`user_id`)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `query` (
  `query_id`       CHAR(36)       NOT NULL,
  `user_id`        CHAR(36)       NOT NULL,
  `context`        TEXT           NULL,
  `response_date`  DATETIME       NULL,
  `response_time`  DECIMAL(10, 5) NULL,
  `scope`          ENUM('local', 'global', 'other') NULL,
  `model_name`     VARCHAR(100)   NULL,
  `input_tokens`   INT            NULL,
  `output_tokens`  INT            NULL,
  `cost_usd`       DECIMAL(10, 5) NULL,
  `answer`         TEXT           NULL,
  `refer_kg`       JSON           NULL,
  CONSTRAINT `PK_QUERY` PRIMARY KEY (`query_id`),
  CONSTRAINT `FK_user_TO_query`
    FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`)
    ON DELETE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- 2. 채팅방 (인덱싱 단위)
-- =====================================================================
CREATE TABLE IF NOT EXISTS `chatroom` (
  `chatroom_id`       CHAR(40)       NOT NULL,
  `index_date`        DATETIME       NOT NULL,
  `user_id`           CHAR(36)       NOT NULL,
  `chatroom_name`     VARCHAR(255)   NOT NULL,
  `message_platform`  VARCHAR(50)    NULL,
  `message_count`     INT            NULL,
  `index_time`        VARCHAR(50)    NULL,
  `llm_model`         VARCHAR(100)   NULL,
  `embed_model`       VARCHAR(100)   NULL,
  `llm_calls`         INT            NULL,
  `input_tokens`      INT            NULL,
  `output_tokens`     INT            NULL,
  `embed_calls`       INT            NULL,
  `embed_tokens`      INT            NULL,
  `total_tokens`      INT            NULL,
  `cost_usd`          DECIMAL(12, 6) NULL,
  `node_count`        INT            NULL,
  `edge_count`        INT            NULL,
  CONSTRAINT `PK_CHATROOM` PRIMARY KEY (`chatroom_id`, `index_date`, `user_id`),
  CONSTRAINT `FK_user_TO_chatroom`
    FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`)
    ON DELETE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- 3. 인물 마스터 (채팅방·인덱싱과 무관한 고정 인물)
-- =====================================================================
CREATE TABLE IF NOT EXISTS `known_person` (
  `person_id`     CHAR(36)     NOT NULL,
  `user_id`       CHAR(36)     NOT NULL,
  `display_name`  VARCHAR(255) NOT NULL,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT `PK_KNOWN_PERSON` PRIMARY KEY (`person_id`),
  CONSTRAINT `UQ_known_person_user_name` UNIQUE (`user_id`, `display_name`),  -- 동명이인 불가
  CONSTRAINT `FK_user_TO_known_person`
    FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`)
    ON DELETE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- 4. 채팅방 하위 테이블
-- =====================================================================
CREATE TABLE IF NOT EXISTS `chatroom_people` (
  `chatroom_people_id`    VARCHAR(255) NOT NULL,
  `chatroom_id`           CHAR(40)     NOT NULL,
  `index_date`            DATETIME     NOT NULL,
  `user_id`               CHAR(36)     NOT NULL,
  `chatroom_people_name`  VARCHAR(255) NULL,
  `message_count`         INT          NULL,
  `description`           TEXT         NULL,
  `short_bio`             TEXT         NULL,
  `person_id`             CHAR(36)     NULL,   -- known_person 연결 (미연결이면 NULL)
  CONSTRAINT `PK_CHATROOM_PEOPLE`
    PRIMARY KEY (`chatroom_people_id`, `chatroom_id`, `index_date`, `user_id`),
  CONSTRAINT `FK_chatroom_TO_chatroom_people`
    FOREIGN KEY (`chatroom_id`, `index_date`, `user_id`)
    REFERENCES `chatroom` (`chatroom_id`, `index_date`, `user_id`)
    ON DELETE CASCADE,
  CONSTRAINT `FK_known_person_TO_chatroom_people`
    FOREIGN KEY (`person_id`) REFERENCES `known_person` (`person_id`)
    ON DELETE SET NULL
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `chatroom_relationship` (
  `person_a`        VARCHAR(255) NOT NULL,
  `chatroom_id`     CHAR(40)     NOT NULL,
  `index_date`      DATETIME     NOT NULL,
  `user_id`         CHAR(36)     NOT NULL,
  `person_b`        VARCHAR(255) NOT NULL,
  `relation_label`  VARCHAR(100) NULL,
  `description`     TEXT         NULL,
  CONSTRAINT `PK_CHATROOM_RELATIONSHIP`
    PRIMARY KEY (`person_a`, `chatroom_id`, `index_date`, `user_id`, `person_b`),
  CONSTRAINT `FK_chatroom_people_TO_chatroom_relationship_a`
    FOREIGN KEY (`person_a`, `chatroom_id`, `index_date`, `user_id`)
    REFERENCES `chatroom_people` (`chatroom_people_id`, `chatroom_id`, `index_date`, `user_id`)
    ON DELETE CASCADE,
  CONSTRAINT `FK_chatroom_people_TO_chatroom_relationship_b`
    FOREIGN KEY (`person_b`, `chatroom_id`, `index_date`, `user_id`)
    REFERENCES `chatroom_people` (`chatroom_people_id`, `chatroom_id`, `index_date`, `user_id`)
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `message_block` (
  `block_id`           VARCHAR(255) NOT NULL,
  `chatroom_id`        CHAR(40)     NOT NULL,
  `index_date`         DATETIME     NOT NULL,
  `user_id`            CHAR(36)     NOT NULL,
  `block_date`         DATE         NULL,
  `message_count`      INT          NULL,
  `participant_count`  INT          NULL,
  `kg_tone`            VARCHAR(20)  NULL,
  `llm_tone`           VARCHAR(20)  NULL,
  `participant`        JSON         NULL,
  CONSTRAINT `PK_MESSAGE_BLOCK`
    PRIMARY KEY (`block_id`, `chatroom_id`, `index_date`, `user_id`),
  INDEX `IDX_message_block_date` (`chatroom_id`, `index_date`, `user_id`, `block_date`),
  CONSTRAINT `FK_chatroom_TO_message_block`
    FOREIGN KEY (`chatroom_id`, `index_date`, `user_id`)
    REFERENCES `chatroom` (`chatroom_id`, `index_date`, `user_id`)
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `participant` (
  `participant_name`  VARCHAR(255) NOT NULL,
  `block_id`          VARCHAR(255) NOT NULL,
  `chatroom_id`       CHAR(40)     NOT NULL,
  `index_date`        DATETIME     NOT NULL,
  `user_id`           CHAR(36)     NOT NULL,
  `sent_message`      INT          NULL,
  CONSTRAINT `PK_PARTICIPANT`
    PRIMARY KEY (`participant_name`, `block_id`, `chatroom_id`, `index_date`, `user_id`),
  CONSTRAINT `FK_message_block_TO_participant`
    FOREIGN KEY (`block_id`, `chatroom_id`, `index_date`, `user_id`)
    REFERENCES `message_block` (`block_id`, `chatroom_id`, `index_date`, `user_id`)
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `message_keyword` (
  `keyword_name`      VARCHAR(100) NOT NULL,
  `participant_name`  VARCHAR(255) NOT NULL,
  `block_id`          VARCHAR(255) NOT NULL,
  `chatroom_id`       CHAR(40)     NOT NULL,
  `index_date`        DATETIME     NOT NULL,
  `user_id`           CHAR(36)     NOT NULL,
  `mention_count`     INT          NULL,
  CONSTRAINT `PK_MESSAGE_KEYWORD`
    PRIMARY KEY (`keyword_name`, `participant_name`, `block_id`, `chatroom_id`, `index_date`, `user_id`),
  CONSTRAINT `FK_participant_TO_message_keyword`
    FOREIGN KEY (`participant_name`, `block_id`, `chatroom_id`, `index_date`, `user_id`)
    REFERENCES `participant` (`participant_name`, `block_id`, `chatroom_id`, `index_date`, `user_id`)
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `message_summarize` (
  `summarize_unit`      VARCHAR(20) NOT NULL,
  `summary_period`      VARCHAR(20) NOT NULL,
  `chatroom_id`         CHAR(40)    NOT NULL,
  `index_date`          DATETIME    NOT NULL,
  `user_id`             CHAR(36)    NOT NULL,
  `summarized_context`  TEXT        NULL,
  `contacts`            JSON        NULL,
  CONSTRAINT `PK_MESSAGE_SUMMARIZE`
    PRIMARY KEY (`summarize_unit`, `summary_period`, `chatroom_id`, `index_date`, `user_id`),
  CONSTRAINT `FK_chatroom_TO_message_summarize`
    FOREIGN KEY (`chatroom_id`, `index_date`, `user_id`)
    REFERENCES `chatroom` (`chatroom_id`, `index_date`, `user_id`)
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `message_mood` (
  `summary_period`    VARCHAR(20)   NOT NULL,
  `summary_unit`      VARCHAR(20)   NOT NULL,
  `chatroom_id`       CHAR(40)      NOT NULL,
  `index_date`        DATETIME      NOT NULL,
  `user_id`           CHAR(36)      NOT NULL,
  `mood_description`  TEXT          NULL,
  `mood_score`        DECIMAL(5, 2) NULL,
  CONSTRAINT `PK_MESSAGE_MOOD`
    PRIMARY KEY (`summary_period`, `summary_unit`, `chatroom_id`, `index_date`, `user_id`),
  CONSTRAINT `FK_chatroom_TO_message_mood`
    FOREIGN KEY (`chatroom_id`, `index_date`, `user_id`)
    REFERENCES `chatroom` (`chatroom_id`, `index_date`, `user_id`)
    ON DELETE CASCADE
) ENGINE=InnoDB;

-- =====================================================================
-- 5. 사진 / 얼굴
-- =====================================================================
CREATE TABLE IF NOT EXISTS `photo` (
  `photo_id`     CHAR(36)    NOT NULL,
  `user_id`      CHAR(36)    NOT NULL,
  `mime_type`    VARCHAR(50) NOT NULL,           -- image/jpeg, image/png ...
  `file_size`    INT         NOT NULL,           -- 원본 바이트 크기
  `file_hash`    CHAR(64)    NOT NULL,           -- SHA-256 (중복 업로드 방지)
  `taken_at`     DATETIME    NULL,               -- EXIF 촬영일
  `uploaded_at`  DATETIME    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `status`       ENUM('pending', 'processed', 'failed') NOT NULL DEFAULT 'pending',
  CONSTRAINT `PK_PHOTO` PRIMARY KEY (`photo_id`),
  CONSTRAINT `UQ_photo_user_hash` UNIQUE (`user_id`, `file_hash`),
  INDEX `IDX_photo_user_taken` (`user_id`, `taken_at`),
  CONSTRAINT `FK_user_TO_photo`
    FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`)
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `photo_data` (
  `photo_id`   CHAR(36)   NOT NULL,
  `original`   LONGBLOB   NOT NULL,              -- 원본 이미지
  `thumbnail`  MEDIUMBLOB NULL,                  -- 목록용 썸네일
  CONSTRAINT `PK_PHOTO_DATA` PRIMARY KEY (`photo_id`),
  CONSTRAINT `FK_photo_TO_photo_data`
    FOREIGN KEY (`photo_id`) REFERENCES `photo` (`photo_id`)
    ON DELETE CASCADE
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS `photo_face` (
  `face_id`       CHAR(36)        NOT NULL,
  `photo_id`      CHAR(36)        NOT NULL,
  `bbox_x`        INT             NULL,
  `bbox_y`        INT             NULL,
  `bbox_w`        INT             NULL,
  `bbox_h`        INT             NULL,
  `embedding`     VARBINARY(2048) NOT NULL,      -- 예: 512차원 float32
  `embed_model`   VARCHAR(100)    NOT NULL,
  `person_id`     CHAR(36)        NULL,          -- 미확인이면 NULL
  `match_status`  ENUM('unknown', 'auto', 'confirmed', 'rejected') NOT NULL DEFAULT 'unknown',
  `similarity`    DECIMAL(5, 4)   NULL,
  CONSTRAINT `PK_PHOTO_FACE` PRIMARY KEY (`face_id`),
  INDEX `IDX_photo_face_photo` (`photo_id`),
  INDEX `IDX_photo_face_person` (`person_id`, `match_status`),
  CONSTRAINT `FK_photo_TO_photo_face`
    FOREIGN KEY (`photo_id`) REFERENCES `photo` (`photo_id`)
    ON DELETE CASCADE,
  CONSTRAINT `FK_known_person_TO_photo_face`
    FOREIGN KEY (`person_id`) REFERENCES `known_person` (`person_id`)
    ON DELETE SET NULL
) ENGINE=InnoDB;