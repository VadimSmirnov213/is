-- Полная инициализация БД этапа 2
\set ON_ERROR_STOP on
\i /sql/00_drop.sql
\i /sql/01_create_schema.sql
\i /sql/02_triggers.sql
\i /sql/03_functions.sql
\i /sql/04_indexes.sql
\i /sql/05_seed.sql
