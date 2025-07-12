DROP DATABASE IF EXISTS querypie;
DROP DATABASE IF EXISTS querypie_log;
DROP DATABASE IF EXISTS querypie_snapshot;

CREATE database querypie CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE database querypie_log CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE database querypie_snapshot CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;

GRANT ALL privileges ON querypie.* TO querypie@'%';
GRANT ALL privileges ON querypie_log.* TO querypie@'%';
GRANT ALL privileges ON querypie_snapshot.* TO querypie@'%';

FLUSH PRIVILEGES;
