-- =============================================================================
-- TFM: Relación entre el uso docente y la valoración del profesorado de una plataforma de aprendizaje en línea
-- Tabla base: eventos de features filtrados a los ~34k docentes con NPS
--
-- Propósito:
--   Materializar un subset manejable de canvas_matchedevents_feature limitado
--   exclusivamente a los docentes que tienen respuesta NPS en Canvas LMS.
--   Todas las queries de análisis posteriores usan esta tabla en lugar de
--   escanear la tabla completa de eventos (>300B filas).
--
-- Ejecutar ANTES de los scripts 01 y 02.
-- =============================================================================

USE WAREHOUSE <YOUR_WAREHOUSE>;
USE DATABASE <YOUR_DATABASE>;

CREATE SCHEMA IF NOT EXISTS <YOUR_SCHEMA>;

CREATE OR REPLACE TABLE <YOUR_DATABASE>.<YOUR_SCHEMA>.base_teacher_feature_events AS

WITH nps_teachers AS (
    SELECT
        USERHASHEDUUID,
        TRY_CAST(NPSRESPONSE AS INT)    AS nps_score,
        CASE
            WHEN TRY_CAST(NPSRESPONSE AS INT) <= 6 THEN 'detractor'
            WHEN TRY_CAST(NPSRESPONSE AS INT) <= 8 THEN 'passive'
            ELSE 'promoter'
        END                             AS nps_category,
        DATETIMERESPONDED
    FROM <SOURCE_DB>.nps.survey_responses
    WHERE LOWER(appname) = 'canvas lms'
      AND LOWER(highestrole) = 'teacher'
      AND NPSRESPONSE IS NOT NULL
)

SELECT
    t.USERHASHEDUUID,
    t.nps_score,
    t.nps_category,
    t.DATETIMERESPONDED,
    e.BROWSERTIMESTAMP,
    e.ANALYTICSSESSIONID,
    f.FEATUREID,
    f.NAME          AS feature_name,
    f.ISCOREEVENT,
    -- Grupo funcional (clasificación por palabras clave en el nombre de la feature)
    -- 11 grupos validados 2026-05-15. Cobertura: 98,7% de eventos clasificados.
    CASE
        WHEN f.NAME ILIKE '%speedgrader%' OR f.NAME ILIKE '%gradebook%'
             OR f.NAME ILIKE '%grade%'    OR f.NAME ILIKE 'Grades%'
             OR f.NAME ILIKE '%rubric%'   OR f.NAME ILIKE 'LMGB%'
            THEN 'Evaluación y calificación'
        WHEN f.NAME ILIKE '%module%'      OR f.NAME ILIKE '%syllabus%'
             OR f.NAME ILIKE '%rich content%' OR f.NAME ILIKE 'RCE%'
             OR f.NAME ILIKE '%edit page%'    OR f.NAME ILIKE '%keep editing%'
             OR f.NAME ILIKE '%unpublish%'    OR f.NAME ILIKE '%drag and drop%'
             OR f.NAME ILIKE '%files%'        OR f.NAME ILIKE '%pages%'
             OR f.NAME ILIKE '%import content%' OR f.NAME ILIKE '%import existing%'
             OR f.NAME ILIKE '%upload%'       OR f.NAME ILIKE '%cover image%'
             OR f.NAME ILIKE '%add section%'  OR f.NAME ILIKE '%alt text%'
             OR f.NAME ILIKE '%block editor%' OR f.NAME ILIKE 'Page>%'
             OR f.NAME ILIKE '%publish%'
            THEN 'Módulos y contenido'
        WHEN f.NAME ILIKE '%discussion%'  OR f.NAME ILIKE '%conversation%'
             OR f.NAME ILIKE '%compose%'
            THEN 'Debates y comunicación'
        WHEN f.NAME ILIKE '%assignment%'  OR f.NAME ILIKE '%submission%'
             OR f.NAME ILIKE '%date and time%' OR f.NAME ILIKE '%assign to%'
             OR f.NAME ILIKE '%due date%'  OR f.NAME ILIKE '%available from%'
            THEN 'Tareas y entregas'
        WHEN f.NAME ILIKE 'NQ |%' OR f.NAME ILIKE 'CQ |%' OR f.NAME ILIKE 'AMS%'
             OR f.NAME ILIKE '%quiz%'     OR f.NAME ILIKE '%question%'
             OR f.NAME ILIKE '%moderation%'
            THEN 'Evaluaciones y tests'
        WHEN f.NAME ILIKE '%navigation%'  OR f.NAME ILIKE '%dashboard%'
             OR f.NAME ILIKE '%course home page link%'
            THEN 'Navegación'
        WHEN f.NAME ILIKE '%announcement%'
            THEN 'Anuncios'
        WHEN f.NAME ILIKE '%people%'      OR f.NAME ILIKE '%roster%'
             OR f.NAME ILIKE '%student%'  OR f.NAME ILIKE '%attendance%'
             OR f.NAME ILIKE '%group%'    OR f.NAME ILIKE '%section%'
            THEN 'Gestión de estudiantes'
        WHEN f.NAME ILIKE '%analytics%'   OR f.NAME ILIKE '%insight%'
             OR f.NAME ILIKE '%report%'
            THEN 'Analítica e informes'
        WHEN f.NAME ILIKE '%settings%'    OR f.NAME ILIKE 'Admin%'
             OR f.NAME ILIKE 'Account%'   OR f.NAME ILIKE '%outcomes%'
            THEN 'Administración'
        ELSE 'Otros'
    END AS feature_group,
    -- Flag: evento dentro de la ventana de 90 días previos al NPS
    CASE
        WHEN e.BROWSERTIMESTAMP >= DATEADD(day, -90, t.DATETIMERESPONDED)
         AND e.BROWSERTIMESTAMP <= t.DATETIMERESPONDED
        THEN TRUE ELSE FALSE
    END AS in_90d_window
FROM nps_teachers t
JOIN <SOURCE_DB>.events.feature_events e
    ON t.USERHASHEDUUID = e.VISITORID
JOIN <SOURCE_DB>.events.dim_features f
    ON e.MATCHABLEID = f.FEATUREID
WHERE f.NAME IS NOT NULL;

-- Verificación
SELECT
    nps_category,
    COUNT(*)                        AS total_events,
    COUNT(DISTINCT USERHASHEDUUID)  AS n_teachers,
    COUNT(DISTINCT feature_name)    AS n_distinct_features,
    SUM(in_90d_window::INT)         AS events_in_90d_window
FROM <YOUR_DATABASE>.<YOUR_SCHEMA>.base_teacher_feature_events
GROUP BY 1
ORDER BY 1;
