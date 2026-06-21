-- =============================================================================
-- TFM: Relación entre el uso docente y la valoración del profesorado de una plataforma de aprendizaje en línea
-- Tabla gold: secuencias ordenadas de features por sesión + NPS del docente
--
-- Prerequisito: ejecutar 00_base_teacher_events.sql primero.
-- Lee de <YOUR_DATABASE>.<YOUR_SCHEMA>.base_teacher_feature_events (subset filtrado
-- a los ~34k docentes con NPS, con flag in_90d_window ya calculado).
--
-- Lógica de sesión: gap de >30 min sin actividad = nueva sesión.
-- =============================================================================

USE WAREHOUSE <YOUR_WAREHOUSE>;
USE DATABASE <YOUR_DATABASE>;

CREATE OR REPLACE TABLE <YOUR_DATABASE>.<YOUR_SCHEMA>.gold_nps_sequences_features AS

WITH feature_events AS (
    -- Partir del subset ya filtrado; solo eventos dentro de la ventana de 90 días
    SELECT
        USERHASHEDUUID,
        nps_score,
        nps_category,
        feature_name,
        BROWSERTIMESTAMP
    FROM <YOUR_DATABASE>.<YOUR_SCHEMA>.base_teacher_feature_events_90d
),

-- Identificar inicio de sesión: primer evento o gap > 30 min desde evento anterior
events_with_gap AS (
    SELECT
        USERHASHEDUUID,
        nps_score,
        nps_category,
        feature_name,
        BROWSERTIMESTAMP,
        LAG(BROWSERTIMESTAMP) OVER (
            PARTITION BY USERHASHEDUUID ORDER BY BROWSERTIMESTAMP
        ) AS prev_ts,
        CASE
            WHEN prev_ts IS NULL THEN 1
            WHEN DATEDIFF(minute, prev_ts, BROWSERTIMESTAMP) > 30 THEN 1
            ELSE 0
        END AS is_session_start
    FROM feature_events
),

-- Asignar ID de sesión (contador acumulado de inicios de sesión por docente)
events_with_session AS (
    SELECT
        USERHASHEDUUID,
        nps_score,
        nps_category,
        feature_name,
        BROWSERTIMESTAMP,
        SUM(is_session_start) OVER (
            PARTITION BY USERHASHEDUUID ORDER BY BROWSERTIMESTAMP
            ROWS UNBOUNDED PRECEDING
        ) AS session_num
    FROM events_with_gap
),

-- Construir la secuencia de features por sesión (array ordenado cronológicamente)
session_sequences AS (
    SELECT
        USERHASHEDUUID,
        nps_score,
        nps_category,
        session_num,
        MIN(BROWSERTIMESTAMP)                                            AS session_start,
        MAX(BROWSERTIMESTAMP)                                            AS session_end,
        COUNT(*)                                                          AS session_length,
        ARRAY_AGG(feature_name) WITHIN GROUP (ORDER BY BROWSERTIMESTAMP) AS feature_sequence
    FROM events_with_session
    GROUP BY 1, 2, 3, 4
    HAVING session_length >= 2  -- solo sesiones con al menos 2 eventos
)

SELECT
    USERHASHEDUUID,
    nps_score,
    nps_category,
    session_num,
    session_start,
    session_end,
    session_length,
    feature_sequence,
    ARRAY_SIZE(feature_sequence) AS seq_length
FROM session_sequences;

-- -------------------------------------------------------------------------
-- Vista auxiliar: bigramas (transiciones entre features consecutivas)
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW <YOUR_DATABASE>.<YOUR_SCHEMA>.v_bigrams_features AS
WITH seq AS (
    SELECT
        USERHASHEDUUID,
        nps_category,
        feature_sequence,
        seq_length
    FROM <YOUR_DATABASE>.<YOUR_SCHEMA>.gold_nps_sequences_features
    WHERE seq_length >= 2
),
unnested AS (
    SELECT
        USERHASHEDUUID,
        nps_category,
        f.VALUE::TEXT   AS feature_a,
        LEAD(f.VALUE::TEXT) OVER (
            PARTITION BY USERHASHEDUUID ORDER BY f.INDEX
        )               AS feature_b,
        f.INDEX         AS pos
    FROM seq,
    LATERAL FLATTEN(input => feature_sequence) f
)
SELECT
    nps_category,
    feature_a,
    feature_b,
    COUNT(*) AS bigram_count
FROM unnested
WHERE feature_b IS NOT NULL
GROUP BY 1, 2, 3;

-- Verificación
SELECT nps_category, COUNT(*) AS n_sessions, ROUND(AVG(session_length), 1) AS avg_len
FROM <YOUR_DATABASE>.<YOUR_SCHEMA>.gold_nps_sequences_features
GROUP BY 1;
