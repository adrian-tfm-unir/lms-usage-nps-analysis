-- =============================================================================
-- TFM: Relación entre el uso docente y la valoración del profesorado de una plataforma de aprendizaje en línea
-- Tabla gold B: clics por feature individual, formato largo, por docente + NPS
--
-- Escenario B — formato largo (1 fila por docente × feature).
-- El pivot a formato ancho se realiza en el notebook 02_regression.ipynb,
-- donde se aplica un umbral mínimo de uso (ej. features usadas por ≥1%
-- de docentes) antes de construir la matriz de predictores.
-- Tabla resultante: gold_nps_features_individual
--
-- Prerequisito: ejecutar 00_base_teacher_events.sql primero.
-- =============================================================================

USE WAREHOUSE <YOUR_WAREHOUSE>;
USE DATABASE <YOUR_DATABASE>;

CREATE OR REPLACE TABLE <YOUR_DATABASE>.<YOUR_SCHEMA>.gold_nps_features_individual AS

SELECT
    USERHASHEDUUID,
    nps_score,
    nps_category,
    feature_name,
    feature_group,
    COUNT(*)                            AS clicks,
    COUNT(DISTINCT ANALYTICSSESSIONID)  AS sessions_with_feature
FROM <YOUR_DATABASE>.<YOUR_SCHEMA>.base_teacher_feature_events_90d
GROUP BY 1, 2, 3, 4, 5;

-- Verificación: cuántas features distintas hay y cuántos docentes las usan
SELECT
    feature_name,
    feature_group,
    COUNT(DISTINCT USERHASHEDUUID)                              AS n_teachers,
    ROUND(COUNT(DISTINCT USERHASHEDUUID) * 100.0 / 34429, 2)  AS pct_teachers,
    SUM(clicks)                                                 AS total_clicks
FROM <YOUR_DATABASE>.<YOUR_SCHEMA>.gold_nps_features_individual
GROUP BY 1, 2
ORDER BY n_teachers DESC
LIMIT 30;
