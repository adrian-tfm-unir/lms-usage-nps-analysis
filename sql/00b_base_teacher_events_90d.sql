-- =============================================================================
-- TFM: Relación entre el uso docente y la valoración del profesorado de una plataforma de aprendizaje en línea
-- Tabla base filtrada: solo eventos dentro de la ventana de 90 días
--
-- Genera un subset de base_teacher_feature_events con únicamente los eventos
-- dentro de los 90 días previos al NPS de cada docente.
-- Elimina la columna in_90d_window (siempre TRUE aquí).
--
-- base_teacher_feature_events      → tabla completa (backup, ~2B filas, todos los eventos)
-- base_teacher_feature_events_90d  → tabla operacional (solo ventana 90d)
--
-- Todos los scripts gold (01a, 01b, 02a, 02b) leen de esta tabla.
-- Prerequisito: ejecutar 00_base_teacher_events.sql primero.
-- =============================================================================

USE WAREHOUSE <YOUR_WAREHOUSE>;
USE DATABASE <YOUR_DATABASE>;

CREATE OR REPLACE TABLE <YOUR_DATABASE>.<YOUR_SCHEMA>.base_teacher_feature_events_90d AS
SELECT * EXCLUDE (in_90d_window)
FROM <YOUR_DATABASE>.<YOUR_SCHEMA>.base_teacher_feature_events
WHERE in_90d_window = TRUE;

-- Verificación
SELECT
    nps_category,
    COUNT(*)                        AS total_events,
    COUNT(DISTINCT USERHASHEDUUID)  AS n_teachers,
    COUNT(DISTINCT feature_name)    AS n_distinct_features
FROM <YOUR_DATABASE>.<YOUR_SCHEMA>.base_teacher_feature_events_90d
GROUP BY 1
ORDER BY 1;
