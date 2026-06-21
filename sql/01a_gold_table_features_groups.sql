-- =============================================================================
-- TFM: Relación entre el uso docente y la valoración del profesorado de una plataforma de aprendizaje en línea
-- Tabla gold A: perfil de uso por GRUPOS FUNCIONALES por docente + NPS
--
-- Escenario A — variables agregadas en 11 grupos funcionales + Otros (cobertura 98,7%).
-- Produce variables interpretables con menor multicolinealidad para la regresión.
-- Tabla resultante: gold_nps_features_groups_groups
--
-- Prerequisito: ejecutar 00_base_teacher_events.sql primero.
-- =============================================================================

USE WAREHOUSE <YOUR_WAREHOUSE>;
USE DATABASE <YOUR_DATABASE>;

-- -------------------------------------------------------------------------
-- (Opcional) Top features más activas entre los docentes NPS
-- -------------------------------------------------------------------------
CREATE OR REPLACE TEMP TABLE tmp_top_features AS
SELECT
    feature_name,
    COUNT(*)                        AS total_events,
    COUNT(DISTINCT USERHASHEDUUID)  AS unique_users
FROM <YOUR_DATABASE>.<YOUR_SCHEMA>.base_teacher_feature_events_90d
GROUP BY 1
ORDER BY 2 DESC
LIMIT 50;

SELECT * FROM tmp_top_features;

-- -------------------------------------------------------------------------
-- Tabla gold: 1 fila por docente con su NPS y su perfil de uso agregado
-- -------------------------------------------------------------------------
CREATE OR REPLACE TABLE <YOUR_DATABASE>.<YOUR_SCHEMA>.gold_nps_features_groups AS

WITH aggregated AS (
    SELECT
        USERHASHEDUUID,
        nps_score,
        nps_category,
        COUNT(*)                            AS total_feature_clicks,
        COUNT(DISTINCT feature_name)        AS n_distinct_features,
        COUNT(DISTINCT ANALYTICSSESSIONID)  AS n_sessions,

        -- Clics por grupo funcional (clasificación validada 2026-05-15, cobertura 98,7%)
        COUNT_IF(feature_group = 'Evaluación y calificación') AS clicks_grading,
        COUNT_IF(feature_group = 'Módulos y contenido')       AS clicks_modules,
        COUNT_IF(feature_group = 'Debates y comunicación')    AS clicks_discussions,
        COUNT_IF(feature_group = 'Tareas y entregas')         AS clicks_assignments,
        COUNT_IF(feature_group = 'Evaluaciones y tests')      AS clicks_quizzes,
        COUNT_IF(feature_group = 'Navegación')                AS clicks_navigation,
        COUNT_IF(feature_group = 'Anuncios')                  AS clicks_announcements,
        COUNT_IF(feature_group = 'Gestión de estudiantes')    AS clicks_people,
        COUNT_IF(feature_group = 'Analítica e informes')      AS clicks_analytics,
        COUNT_IF(feature_group = 'Administración')            AS clicks_admin,
        COUNT_IF(feature_group = 'Otros')                     AS clicks_otros,

        -- Sesiones únicas con al menos 1 clic en cada grupo funcional
        COUNT(DISTINCT CASE WHEN feature_group = 'Evaluación y calificación' THEN ANALYTICSSESSIONID END) AS sessions_grading,
        COUNT(DISTINCT CASE WHEN feature_group = 'Módulos y contenido'       THEN ANALYTICSSESSIONID END) AS sessions_modules,
        COUNT(DISTINCT CASE WHEN feature_group = 'Debates y comunicación'    THEN ANALYTICSSESSIONID END) AS sessions_discussions,
        COUNT(DISTINCT CASE WHEN feature_group = 'Tareas y entregas'         THEN ANALYTICSSESSIONID END) AS sessions_assignments,
        COUNT(DISTINCT CASE WHEN feature_group = 'Evaluaciones y tests'      THEN ANALYTICSSESSIONID END) AS sessions_quizzes,
        COUNT(DISTINCT CASE WHEN feature_group = 'Navegación'                THEN ANALYTICSSESSIONID END) AS sessions_navigation,
        COUNT(DISTINCT CASE WHEN feature_group = 'Anuncios'                  THEN ANALYTICSSESSIONID END) AS sessions_announcements,
        COUNT(DISTINCT CASE WHEN feature_group = 'Gestión de estudiantes'    THEN ANALYTICSSESSIONID END) AS sessions_people,
        COUNT(DISTINCT CASE WHEN feature_group = 'Analítica e informes'      THEN ANALYTICSSESSIONID END) AS sessions_analytics,
        COUNT(DISTINCT CASE WHEN feature_group = 'Administración'            THEN ANALYTICSSESSIONID END) AS sessions_admin,
        COUNT(DISTINCT CASE WHEN feature_group = 'Otros'                     THEN ANALYTICSSESSIONID END) AS sessions_otros

    FROM <YOUR_DATABASE>.<YOUR_SCHEMA>.base_teacher_feature_events_90d
    GROUP BY 1, 2, 3
)

SELECT
    *,
    -- Tasa simple: clics totales / sesiones totales
    ROUND(total_feature_clicks::FLOAT / NULLIF(n_sessions, 0), 2) AS clicks_per_session,

    -- Tasa simple por grupo (clics del grupo / sesiones totales del docente)
    ROUND(clicks_grading::FLOAT       / NULLIF(n_sessions, 0), 4) AS rate_grading,
    ROUND(clicks_modules::FLOAT       / NULLIF(n_sessions, 0), 4) AS rate_modules,
    ROUND(clicks_discussions::FLOAT   / NULLIF(n_sessions, 0), 4) AS rate_discussions,
    ROUND(clicks_assignments::FLOAT   / NULLIF(n_sessions, 0), 4) AS rate_assignments,
    ROUND(clicks_quizzes::FLOAT       / NULLIF(n_sessions, 0), 4) AS rate_quizzes,
    ROUND(clicks_navigation::FLOAT    / NULLIF(n_sessions, 0), 4) AS rate_navigation,
    ROUND(clicks_announcements::FLOAT / NULLIF(n_sessions, 0), 4) AS rate_announcements,
    ROUND(clicks_people::FLOAT        / NULLIF(n_sessions, 0), 4) AS rate_people,
    ROUND(clicks_analytics::FLOAT     / NULLIF(n_sessions, 0), 4) AS rate_analytics,
    ROUND(clicks_admin::FLOAT         / NULLIF(n_sessions, 0), 4) AS rate_admin,
    ROUND(clicks_otros::FLOAT         / NULLIF(n_sessions, 0), 4) AS rate_otros,

    -- Media ponderada: clics del grupo / sesiones únicas con ese grupo (intensidad de uso)
    ROUND(clicks_grading::FLOAT       / NULLIF(sessions_grading, 0),       4) AS intensity_grading,
    ROUND(clicks_modules::FLOAT       / NULLIF(sessions_modules, 0),       4) AS intensity_modules,
    ROUND(clicks_discussions::FLOAT   / NULLIF(sessions_discussions, 0),   4) AS intensity_discussions,
    ROUND(clicks_assignments::FLOAT   / NULLIF(sessions_assignments, 0),   4) AS intensity_assignments,
    ROUND(clicks_quizzes::FLOAT       / NULLIF(sessions_quizzes, 0),       4) AS intensity_quizzes,
    ROUND(clicks_navigation::FLOAT    / NULLIF(sessions_navigation, 0),    4) AS intensity_navigation,
    ROUND(clicks_announcements::FLOAT / NULLIF(sessions_announcements, 0), 4) AS intensity_announcements,
    ROUND(clicks_people::FLOAT        / NULLIF(sessions_people, 0),        4) AS intensity_people,
    ROUND(clicks_analytics::FLOAT     / NULLIF(sessions_analytics, 0),     4) AS intensity_analytics,
    ROUND(clicks_admin::FLOAT         / NULLIF(sessions_admin, 0),         4) AS intensity_admin,
    ROUND(clicks_otros::FLOAT         / NULLIF(sessions_otros, 0),         4) AS intensity_otros

FROM aggregated;

-- Verificación
SELECT
    nps_category,
    COUNT(*)                            AS n_teachers,
    ROUND(AVG(total_feature_clicks), 1) AS avg_clicks,
    ROUND(AVG(n_distinct_features), 1)  AS avg_distinct_features,
    ROUND(AVG(n_sessions), 1)           AS avg_sessions
FROM <YOUR_DATABASE>.<YOUR_SCHEMA>.gold_nps_features_groups
GROUP BY 1
ORDER BY 1;
