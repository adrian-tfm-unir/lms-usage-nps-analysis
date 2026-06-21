-- =============================================================================
-- TFM: Validación del join NPS ↔ Feature Events
-- Ejecutar antes de los scripts 01 y 02 para confirmar la tasa de match
-- =============================================================================

USE WAREHOUSE <YOUR_WAREHOUSE>;

-- -------------------------------------------------------------------------
-- 1. ¿Cuántos docentes con NPS tienen al menos un evento de feature?
-- -------------------------------------------------------------------------
SELECT
    COUNT(DISTINCT n.USERHASHEDUUID)    AS total_nps_teachers,
    COUNT(DISTINCT e.VISITORID)         AS matched_in_events,
    ROUND(
        COUNT(DISTINCT e.VISITORID)::FLOAT /
        NULLIF(COUNT(DISTINCT n.USERHASHEDUUID), 0) * 100, 1
    )                                   AS match_rate_pct
FROM <SOURCE_DB>.nps.survey_responses n
LEFT JOIN (
    SELECT DISTINCT VISITORID
    FROM <SOURCE_DB>.events.feature_events
) e ON n.USERHASHEDUUID = e.VISITORID
WHERE LOWER(n.appname) = 'canvas lms'
  AND LOWER(n.highestrole) = 'teacher';

-- -------------------------------------------------------------------------
-- 2. Distribución del NPS para los docentes que SÍ tienen eventos
-- -------------------------------------------------------------------------
WITH matched AS (
    SELECT DISTINCT n.USERHASHEDUUID, TRY_CAST(n.NPSRESPONSE AS INT) AS nps_score
    FROM <SOURCE_DB>.nps.survey_responses n
    INNER JOIN (
        SELECT DISTINCT VISITORID
        FROM <SOURCE_DB>.events.feature_events
    ) e ON n.USERHASHEDUUID = e.VISITORID
    WHERE LOWER(n.appname) = 'canvas lms'
      AND LOWER(n.highestrole) = 'teacher'
)
SELECT
    nps_score,
    COUNT(*)    AS n,
    CASE
        WHEN nps_score <= 6 THEN 'detractor'
        WHEN nps_score <= 8 THEN 'passive'
        ELSE 'promoter'
    END         AS category
FROM matched
GROUP BY 1, 3
ORDER BY 1;

-- -------------------------------------------------------------------------
-- 3. ¿Cuántos eventos tiene de media un docente en los 90 días previos?
-- -------------------------------------------------------------------------
WITH nps AS (
    SELECT USERHASHEDUUID, DATETIMERESPONDED
    FROM <SOURCE_DB>.nps.survey_responses
    WHERE LOWER(appname) = 'canvas lms' AND LOWER(highestrole) = 'teacher'
    LIMIT 1000  -- muestra pequeña para validación rápida
),
event_counts AS (
    SELECT
        n.USERHASHEDUUID,
        COUNT(e.VISITORID) AS events_90d
    FROM nps n
    LEFT JOIN <SOURCE_DB>.events.feature_events e
        ON n.USERHASHEDUUID = e.VISITORID
        AND e.BROWSERTIMESTAMP >= DATEADD(day, -90, n.DATETIMERESPONDED)
        AND e.BROWSERTIMESTAMP <= n.DATETIMERESPONDED
    GROUP BY 1
)
SELECT
    COUNT(*)                    AS n_teachers_sampled,
    SUM(CASE WHEN events_90d > 0 THEN 1 ELSE 0 END) AS with_events,
    ROUND(AVG(events_90d), 1)  AS avg_events_90d,
    MEDIAN(events_90d)         AS median_events_90d,
    MAX(events_90d)            AS max_events_90d
FROM event_counts;
