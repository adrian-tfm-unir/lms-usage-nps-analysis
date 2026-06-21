# Relación entre el uso docente y la valoración del profesorado de una plataforma de aprendizaje en línea
## Análisis de patrones de uso docente en un LMS y su relación con el NPS

Código analítico del Trabajo de Fin de Máster (TFM) del Máster en Visual Analytics and Big Data (UNIR).

**Autores**: Adrián Tábara Cenador · Susanne Tábara Cenador
**Título**: *Relación entre el uso docente y la valoración del profesorado de una plataforma de aprendizaje en línea*

---

## Descripción

Este repositorio contiene los scripts SQL y notebooks Python utilizados para analizar la relación entre los patrones de interacción de ~37.000 docentes con Canvas LMS y su nivel de satisfacción (NPS), a partir de datos reales de producción anonimizados.

El análisis se estructura en tres capas:
1. **EDA** — Análisis exploratorio de los patrones de uso por grupos funcionales y categoría NPS
2. **Regresión** — Regresión logística ordinal (4 especificaciones) para cuantificar la asociación uso → NPS
3. **Secuencias** — Análisis de n-gramas sobre flujos de trabajo por sesión

---

## Estructura del repositorio

```
├── sql/
│   ├── 00_base_teacher_events.sql          # Tabla base: eventos de features filtrados a docentes con NPS
│   ├── 00b_base_teacher_events_90d.sql     # Subset: solo ventana de 90 días previos al NPS
│   ├── 01a_gold_table_features_groups.sql  # Tabla analítica: perfil de uso por grupos funcionales
│   ├── 01b_gold_table_features_individual.sql  # Tabla analítica: features individuales
│   ├── 02a_gold_table_sequences_features.sql   # Secuencias de features por sesión
│   ├── 02b_gold_table_sequences_groups.sql     # Secuencias de grupos funcionales por sesión
│   └── 03_validate_join.sql                # Validación del join NPS ↔ eventos
├── notebooks/
│   ├── 01_eda.ipynb                        # EDA completo
│   ├── 02_regression.ipynb                 # Regresión logística ordinal
│   └── 03_sequence_analysis.ipynb          # Análisis de secuencias y n-gramas
├── requirements.txt
├── .env.example                            # Plantilla de variables de entorno
└── .gitignore
```

---

## Configuración

### 1. Requisitos

```bash
pip install -r requirements.txt
```

### 2. Variables de entorno

```bash
cp .env.example .env
# Editar .env con tus valores reales
```

Los notebooks leen la configuración mediante `os.getenv()`. Las variables relevantes son:

| Variable | Descripción |
|---|---|
| `SNOWFLAKE_CONNECTION` | Nombre de la conexión en tu config de Snowflake |
| `SNOWFLAKE_WAREHOUSE` | Nombre del warehouse |
| `SNOWFLAKE_DATABASE` | Base de datos donde se crean las tablas analíticas |
| `SNOWFLAKE_SCHEMA` | Schema donde se crean las tablas analíticas |
| `SF_TABLE_FEATURES` | Nombre de la tabla gold de grupos funcionales |
| `SF_TABLE_SEQUENCES` | Nombre de la tabla gold de secuencias |

### 3. Orden de ejecución de los scripts SQL

```
00_base_teacher_events.sql
  → 00b_base_teacher_events_90d.sql
      → 01a_gold_table_features_groups.sql
      → 01b_gold_table_features_individual.sql
      → 02a_gold_table_sequences_features.sql
      → 02b_gold_table_sequences_groups.sql
03_validate_join.sql  (opcional, validación)
```

### 4. Adaptación a otras fuentes de datos

Los scripts SQL asumen la siguiente estructura de tablas fuente:

| Placeholder | Descripción |
|---|---|
| `<SOURCE_DB>.nps.survey_responses` | Respuestas NPS con campos: `USERHASHEDUUID`, `NPSRESPONSE`, `DATETIMERESPONDED`, `APPNAME`, `HIGHESTROLE` |
| `<SOURCE_DB>.events.feature_events` | Eventos de uso con campos: `VISITORID`, `BROWSERTIMESTAMP`, `MATCHABLEID`, `ANALYTICSSESSIONID` |
| `<SOURCE_DB>.events.dim_features` | Dimensión de features con campos: `FEATUREID`, `NAME`, `ISCOREEVENT` |

---

## Datos

Los datos originales son propiedad de Instructure y no pueden ser redistribuidos. El acceso a los datos requiere infraestructura autorizada; los notebooks documentan el código analítico con fines de transparencia y reproducibilidad.

---

## Cita

Si utilizas este código en tu investigación, por favor cita el TFM:

> Tábara Cenador, A., & Tábara Cenador, S. (2026). *Relación entre el uso docente y la valoración del profesorado de una plataforma de aprendizaje en línea*. Trabajo de Fin de Máster, Universidad Internacional de La Rioja (UNIR).

---

## Licencia

Este repositorio se distribuye bajo la licencia [MIT](LICENSE).
