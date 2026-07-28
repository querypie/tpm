WITH user_activity_logs AS (
    SELECT
        al.action_at AS event_time,
        CASE al.action_type
            WHEN 'USER_CREATED' THEN '사용자 생성'
            WHEN 'USER_DELETED' THEN '사용자 삭제'
            ELSE al.action_type
        END AS event_name,
        al.action_type AS raw_event_type,

        target_user.login_id AS target_login_id,
        COALESCE(target_user.name, al.target_name) AS target_user_name,
        target_user.email AS target_user_email,
        target_user.status AS current_user_status,
        target_user.created_at AS target_user_created_at,
        target_user.last_login_at AS target_user_last_login_at,
        target_user.unlocked_at AS target_user_unlocked_at,

        actor.login_id AS actor_login_id,
        actor.name AS actor_name,

        NULL AS reason,
        al.client_ip,
        al.deltas AS detail
    FROM querypie_log.l_activity_logs al
    LEFT JOIN querypie.users target_user
      ON target_user.uuid = al.target_uuid
    LEFT JOIN querypie.users actor
      ON actor.id = al.action_by
    WHERE al.target_type = 'USER'
      AND al.action_type IN (
          'USER_CREATED',
          'USER_DELETED'
      )
),
user_auth_logs AS (
    SELECT
        ual.acted_at AS event_time,
        CASE ual.action_type
            WHEN 'LOCKED' THEN '계정 잠김'
            WHEN 'LOCKED_MANUALLY' THEN '계정 수동 잠김'
            WHEN 'UNLOCK' THEN '잠김 해제'
            WHEN 'EXPIRED' THEN '만료됨'
            ELSE ual.action_type
        END AS event_name,
        ual.action_type AS raw_event_type,

        ual.user_login_id AS target_login_id,
        ual.user_name AS target_user_name,
        ual.user_email AS target_user_email,
        target_user.status AS current_user_status,
        target_user.created_at AS target_user_created_at,
        target_user.last_login_at AS target_user_last_login_at,
        target_user.unlocked_at AS target_user_unlocked_at,

        actor.login_id AS actor_login_id,
        COALESCE(actor.name, ual.actor_user_name) AS actor_name,

        CASE
            WHEN ual.action_type = 'LOCKED'
                THEN COALESCE(ual.message, '로그인 실패 횟수 초과')
            WHEN ual.action_type = 'LOCKED_MANUALLY'
                THEN COALESCE(ual.message, '관리자 수동 잠금')
            WHEN ual.action_type = 'UNLOCK'
                THEN COALESCE(ual.message, '잠김 해제')
            WHEN ual.action_type = 'EXPIRED'
                THEN COALESCE(ual.message, '계정 만료')
            ELSE ual.message
        END AS reason,
        ual.client_ip,
        NULL AS detail
    FROM querypie_log.l_user_auth_logs ual
    LEFT JOIN querypie.users target_user
      ON target_user.id = ual.user_id
    LEFT JOIN querypie.users actor
      ON actor.id = ual.actor_user_id
    WHERE ual.action_type IN (
        'LOCKED',
        'LOCKED_MANUALLY',
        'UNLOCK',
        'EXPIRED'
    )
)
SELECT
    DATE_FORMAT(CONVERT_TZ(event_time, '+00:00', '+09:00'), '%Y-%m-%d %H:%i:%s') AS `시간`,
    event_name AS `이벤트`,
    COALESCE(target_login_id, target_user_name) AS `사용자 Id or Name`,
    actor_login_id AS `행위자 Id`,
    IFNULL(reason, '') AS `사유`,
    DATE_FORMAT(CONVERT_TZ(target_user_created_at, '+00:00', '+09:00'), '%Y-%m-%d %H:%i:%s') AS '사용자생성일',
    DATE_FORMAT(CONVERT_TZ(target_user_last_login_at, '+00:00', '+09:00'), '%Y-%m-%d %H:%i:%s') AS '마지막로그인',
    DATE_FORMAT(CONVERT_TZ(target_user_unlocked_at, '+00:00', '+09:00'), '%Y-%m-%d %H:%i:%s') AS 'Unlock시간'
FROM (
    SELECT * FROM user_activity_logs
    UNION ALL
    SELECT * FROM user_auth_logs
) logs
ORDER BY event_time ASC;
