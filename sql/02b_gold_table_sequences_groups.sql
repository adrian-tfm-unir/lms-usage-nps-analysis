-- =============================================================================
-- TFM: Relación entre el uso docente y la valoración del profesorado de una plataforma de aprendizaje en línea
-- Tabla gold: secuencias de GRUPOS FUNCIONALES por sesión + NPS del docente
--
-- Escenario B — secuencias a nivel de grupo funcional (12 grupos).
-- Diferencia respecto a 02a: ARRAY_AGG usa feature_group en lugar de feature_name.
-- Produce secuencias más legibles y directamente conectables con la narrativa
-- del TFM, a costa de menor granularidad.
--
-- Ejemplo de secuencia resultante:
--   ["Navegación", "Evaluación y calificación", "Evaluación y calificación", "Módulos y contenido"]
--
-- Prerequisito: ejecutar 00_base_teacher_events.sql primero.
-- =============================================================================

USE WAREHOUSE <YOUR_WAREHOUSE>;
USE DATABASE <YOUR_DATABASE>;

CREATE OR REPLACE TABLE <YOUR_DATABASE>.<YOUR_SCHEMA>.gold_nps_sequences_groups AS

WITH feature_events AS (
    SELECT
        USERHASHEDUUID,
        nps_score,
        nps_category,
        feature_group,
        BROWSERTIMESTAMP
    FROM <YOUR_DATABASE>.<YOUR_SCHEMA>.base_teacher_feature_events_90d
),

-- Identificar inicio de sesión: primer evento o gap > 30 min desde evento anterior
events_with_gap AS (
    SELECT
        USERHASHEDUUID,
        nps_score,
        nps_category,
        feature_group,
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
        feature_group,
        BROWSERTIMESTAMP,
        SUM(is_session_start) OVER (
            PARTITION BY USERHASHEDUUID ORDER BY BROWSERTIMESTAMP
            ROWS UNBOUNDED PRECEDING
        ) AS session_num
    FROM events_with_gap
),

-- Construir la secuencia de grupos por sesión (array ordenado cronológicamente)
session_sequences AS (
    SELECT
        USERHASHEDUUID,
        nps_score,
        nps_category,
        session_num,
        MIN(BROWSERTIMESTAMP)                                             AS session_start,
        MAX(BROWSERTIMESTAMP)                                             AS session_end,
        COUNT(*)                                                           AS session_length,
        ARRAY_AGG(feature_group) WITHIN GROUP (ORDER BY BROWSERTIMESTAMP) AS group_sequence
    FROM events_with_session
    GROUP BY 1, 2, 3, 4
    HAVING session_length >= 2
)

SELECT
    USERHASHEDUUID,
    nps_score,
    nps_category,
    session_num,
    session_start,
    session_end,
    session_length,
    group_sequence,
    ARRAY_SIZE(group_sequence) AS seq_length
FROM session_sequences;

-- -------------------------------------------------------------------------
-- Vista auxiliar: bigramas de grupos funcionales
-- -------------------------------------------------------------------------
CREATE OR REPLACE VIEW <YOUR_DATABASE>.<YOUR_SCHEMA>.v_bigrams_groups AS
WITH seq AS (
    SELECT
        USERHASHEDUUID,
        nps_category,
        group_sequence,
        seq_length
    FROM <YOUR_DATABASE>.<YOUR_SCHEMA>.gold_nps_sequences_groups
    WHERE seq_length >= 2
),
unnested AS (
    SELECT
        USERHASHEDUUID,
        nps_category,
        f.VALUE::TEXT   AS group_a,
        LEAD(f.VALUE::TEXT) OVER (
            PARTITION BY USERHASHEDUUID ORDER BY f.INDEX
        )               AS group_b,
        f.INDEX         AS pos
    FROM seq,
    LATERAL FLATTEN(input => group_sequence) f
)
SELECT
    nps_category,
    group_a,
    group_b,
    COUNT(*) AS bigram_count
FROM unnested
WHERE group_b IS NOT NULL
GROUP BY 1, 2, 3;

-- Verificación
SELECT nps_category, COUNT(*) AS n_sessions, ROUND(AVG(session_length), 1) AS avg_len
FROM <YOUR_DATABASE>.<YOUR_SCHEMA>.gold_nps_sequences_groups
GROUP BY 1;
