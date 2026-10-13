# ИС автосервиса — курсовая работа, этап 2

Проектирование и реализация БД PostgreSQL для информационной системы управления работой сети автосервиса.

## Структура

```
is-coursework/
├── compose.yaml              # PostgreSQL 16
├── sql/                      # DDL, триггеры, функции, индексы, seed
├── model/
│   ├── er_model.dbml         # ER-модель кодом (DBML)
│   └── java/                 # JPA-сущности
├── diagrams/er_diagram.mmd   # Mermaid ER
└── docs/
    ├── generate_report.py
    └── coursework_stage2_autoservice.docx
```

## Быстрый старт

```bash
cd ~/is-coursework
docker compose up -d
docker exec -i autoservice-db psql -U autoservice -d autoservice -f /sql/init_all.sql
```

Подключение: `localhost:5434`, БД/пользователь/пароль: `autoservice`.

## Пересоздание БД

```bash
docker exec -i autoservice-db psql -U autoservice -d autoservice -f /sql/init_all.sql
```

## Отчёт

```bash
python3 docs/generate_report.py
```

Файл: `docs/coursework_stage2_autoservice.docx`.
