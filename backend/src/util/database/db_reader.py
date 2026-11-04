# 인덱싱된 계정의 연락처 description 등을 DB에서 조회해 반환한다.

# Utility functions that read person descriptions for an indexed account from the database.

from config.db import get_db_connection
from util.database.db_writer import get_latest_mail_account


    


# 최신 인덱싱 기준 이 계정 연락처의 이메일·이름·description·relation_label을 반환한다 (description 있는 것만)
def get_person_descriptions(user_id: str) -> list:
    latest_account = get_latest_mail_account(user_id)
    if not latest_account:
        return []

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        # person_account_id로 alias: 프론트/avatar_generator가 기대하는 기존 API 응답 키 유지
        cursor.execute("""
            SELECT person_mail_account_id AS person_account_id, person_name, description, relation_label, short_bio
            FROM person
            WHERE user_mail_account_id = %s AND index_date = %s
              AND description IS NOT NULL AND description != ''
        """, (latest_account["user_mail_account_id"], latest_account["index_date"]))
        return cursor.fetchall()
    finally:
        cursor.close()
        conn.close()


# 최신 인덱싱 기준 이 계정 연락처 전체(이메일+이름)를 반환한다 (아바타 일괄 생성용 경량 조회)
def get_all_persons(user_id: str) -> list:
    latest_account = get_latest_mail_account(user_id)
    if not latest_account:
        return []

    conn = get_db_connection()
    cursor = conn.cursor(dictionary=True)
    try:
        cursor.execute("""
            SELECT person_mail_account_id, person_name
            FROM person
            WHERE user_mail_account_id = %s AND index_date = %s
        """, (latest_account["user_mail_account_id"], latest_account["index_date"]))
        return cursor.fetchall()
    finally:
        cursor.close()
        conn.close()


