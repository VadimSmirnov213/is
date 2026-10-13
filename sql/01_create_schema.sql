-- Даталогическая модель ИС автосервиса (этап 2)
-- СУБД: PostgreSQL 16+
-- Схема: autoservice

CREATE SCHEMA IF NOT EXISTS autoservice;
SET search_path TO autoservice, public;

-- ---------------------------------------------------------------------------
-- Справочники и перечисления (через доменные CHECK / lookup-таблицы)
-- ---------------------------------------------------------------------------

CREATE TABLE roles (
    id          SMALLSERIAL PRIMARY KEY,
    code        VARCHAR(32)  NOT NULL UNIQUE,
    name_ru     VARCHAR(64)  NOT NULL,
    CONSTRAINT chk_roles_code CHECK (code IN ('CLIENT', 'MANAGER', 'MECHANIC'))
);

CREATE TABLE request_statuses (
    id          SMALLSERIAL PRIMARY KEY,
    code        VARCHAR(40)  NOT NULL UNIQUE,
    name_ru     VARCHAR(80)  NOT NULL,
    is_terminal BOOLEAN      NOT NULL DEFAULT FALSE,
    CONSTRAINT chk_request_statuses_code CHECK (
        code IN (
            'NEW',
            'CONFIRMED',
            'ASSIGNED',
            'IN_PROGRESS',
            'AWAITING_PART_APPROVAL',
            'AWAITING_PART',
            'COMPLETED',
            'CANCELLED'
        )
    )
);

CREATE TABLE users (
    id              BIGSERIAL PRIMARY KEY,
    email           VARCHAR(255) NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    full_name       VARCHAR(150) NOT NULL,
    phone           VARCHAR(32),
    role_id         SMALLINT     NOT NULL REFERENCES roles(id),
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_users_email UNIQUE (email),
    CONSTRAINT chk_users_email CHECK (position('@' IN email) > 1)
);

CREATE TABLE service_locations (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(150) NOT NULL,
    address         VARCHAR(255) NOT NULL,
    phone           VARCHAR(32),
    work_schedule   VARCHAR(255),
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- M:N — механик может работать в нескольких точках; точка имеет нескольких механиков
CREATE TABLE mechanic_locations (
    mechanic_id     BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    location_id     BIGINT NOT NULL REFERENCES service_locations(id) ON DELETE CASCADE,
    assigned_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (mechanic_id, location_id)
);

CREATE TABLE vehicles (
    id              BIGSERIAL PRIMARY KEY,
    owner_id        BIGINT       NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    make            VARCHAR(80)  NOT NULL,
    model           VARCHAR(80)  NOT NULL,
    year            INTEGER      NOT NULL,
    plate_number    VARCHAR(20)  NOT NULL,
    vin             VARCHAR(32),
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_vehicles_plate UNIQUE (plate_number),
    CONSTRAINT uq_vehicles_vin UNIQUE (vin),
    CONSTRAINT chk_vehicles_year CHECK (year BETWEEN 1950 AND EXTRACT(YEAR FROM CURRENT_DATE)::INT + 1),
    CONSTRAINT chk_vehicles_vin_len CHECK (vin IS NULL OR char_length(vin) BETWEEN 11 AND 17)
);

CREATE TABLE service_types (
    id              BIGSERIAL PRIMARY KEY,
    code            VARCHAR(64)  NOT NULL,
    name            VARCHAR(150) NOT NULL,
    description     TEXT,
    category        VARCHAR(64)  NOT NULL,
    base_price      NUMERIC(12,2) NOT NULL DEFAULT 0,
    is_modification BOOLEAN      NOT NULL DEFAULT FALSE,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_service_types_code UNIQUE (code),
    CONSTRAINT chk_service_types_price CHECK (base_price >= 0)
);

CREATE TABLE parts (
    id              BIGSERIAL PRIMARY KEY,
    sku             VARCHAR(64)  NOT NULL,
    name            VARCHAR(200) NOT NULL,
    description     TEXT,
    approx_price    NUMERIC(12,2) NOT NULL,
    is_orderable    BOOLEAN      NOT NULL DEFAULT TRUE,
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_parts_sku UNIQUE (sku),
    CONSTRAINT chk_parts_price CHECK (approx_price >= 0)
);

-- M:N — совместимость запчасти с марками/моделями автомобилей
CREATE TABLE part_compatibilities (
    id              BIGSERIAL PRIMARY KEY,
    part_id         BIGINT       NOT NULL REFERENCES parts(id) ON DELETE CASCADE,
    make            VARCHAR(80)  NOT NULL,
    model           VARCHAR(80)  NOT NULL,
    year_from       INTEGER,
    year_to         INTEGER,
    CONSTRAINT uq_part_compat UNIQUE (part_id, make, model, year_from, year_to),
    CONSTRAINT chk_part_compat_years CHECK (
        year_from IS NULL OR year_to IS NULL OR year_from <= year_to
    )
);

-- M:N — услуга модификации связана с подходящими запчастями
CREATE TABLE service_type_parts (
    service_type_id BIGINT NOT NULL REFERENCES service_types(id) ON DELETE CASCADE,
    part_id         BIGINT NOT NULL REFERENCES parts(id) ON DELETE CASCADE,
    is_required     BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (service_type_id, part_id)
);

CREATE TABLE service_requests (
    id                      BIGSERIAL PRIMARY KEY,
    client_id               BIGINT       NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    vehicle_id              BIGINT       NOT NULL REFERENCES vehicles(id) ON DELETE RESTRICT,
    service_type_id         BIGINT       NOT NULL REFERENCES service_types(id) ON DELETE RESTRICT,
    location_id             BIGINT       NOT NULL REFERENCES service_locations(id) ON DELETE RESTRICT,
    mechanic_id             BIGINT       REFERENCES users(id) ON DELETE SET NULL,
    status_id               SMALLINT     NOT NULL REFERENCES request_statuses(id),
    description             TEXT         NOT NULL,
    desired_date            DATE         NOT NULL,
    agreed_date             DATE,
    purchase_approval_mode  VARCHAR(40)  NOT NULL,
    cancel_reason           TEXT,
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    completed_at            TIMESTAMPTZ,
    CONSTRAINT chk_sr_approval_mode CHECK (
        purchase_approval_mode IN ('ALLOW_WITHOUT_CONFIRMATION', 'REQUIRE_CONFIRMATION')
    ),
    CONSTRAINT chk_sr_dates CHECK (agreed_date IS NULL OR agreed_date >= desired_date - 30)
);

CREATE TABLE request_parts (
    id                  BIGSERIAL PRIMARY KEY,
    request_id          BIGINT         NOT NULL REFERENCES service_requests(id) ON DELETE CASCADE,
    part_id             BIGINT         NOT NULL REFERENCES parts(id) ON DELETE RESTRICT,
    quantity            INTEGER        NOT NULL DEFAULT 1,
    unit_price          NUMERIC(12,2)  NOT NULL,
    source              VARCHAR(32)    NOT NULL,
    is_installed        BOOLEAN        NOT NULL DEFAULT FALSE,
    created_at          TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_request_parts_qty CHECK (quantity > 0),
    CONSTRAINT chk_request_parts_price CHECK (unit_price >= 0),
    CONSTRAINT chk_request_parts_source CHECK (
        source IN ('CLIENT_SELECTED', 'MECHANIC_PROPOSED', 'PURCHASED', 'INSTALLED')
    )
);

CREATE TABLE part_purchase_requests (
    id                  BIGSERIAL PRIMARY KEY,
    request_id          BIGINT         NOT NULL REFERENCES service_requests(id) ON DELETE CASCADE,
    part_id             BIGINT         NOT NULL REFERENCES parts(id) ON DELETE RESTRICT,
    created_by          BIGINT         NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    quantity            INTEGER        NOT NULL DEFAULT 1,
    reason              TEXT           NOT NULL,
    estimated_cost      NUMERIC(12,2)  NOT NULL,
    status              VARCHAR(32)    NOT NULL DEFAULT 'PENDING',
    purchased_at        TIMESTAMPTZ,
    received_at         TIMESTAMPTZ,
    created_at          TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ    NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_ppr_qty CHECK (quantity > 0),
    CONSTRAINT chk_ppr_cost CHECK (estimated_cost >= 0),
    CONSTRAINT chk_ppr_status CHECK (
        status IN ('PENDING', 'AUTO_APPROVED', 'APPROVED', 'REJECTED', 'PURCHASED', 'RECEIVED', 'CANCELLED')
    )
);

CREATE TABLE purchase_approvals (
    id                      BIGSERIAL PRIMARY KEY,
    purchase_request_id     BIGINT       NOT NULL UNIQUE REFERENCES part_purchase_requests(id) ON DELETE CASCADE,
    decided_by              BIGINT       REFERENCES users(id) ON DELETE SET NULL,
    decision                VARCHAR(16)  NOT NULL,
    comment                 TEXT,
    decided_at              TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_pa_decision CHECK (decision IN ('APPROVED', 'REJECTED', 'AUTO_APPROVED'))
);

CREATE TABLE work_reports (
    id                  BIGSERIAL PRIMARY KEY,
    request_id          BIGINT       NOT NULL UNIQUE REFERENCES service_requests(id) ON DELETE CASCADE,
    mechanic_id         BIGINT       NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    diagnosis           TEXT,
    work_description    TEXT         NOT NULL,
    result_summary      TEXT         NOT NULL,
    labor_cost          NUMERIC(12,2) NOT NULL DEFAULT 0,
    created_at          TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    CONSTRAINT chk_work_reports_cost CHECK (labor_cost >= 0)
);

CREATE TABLE request_status_history (
    id              BIGSERIAL PRIMARY KEY,
    request_id      BIGINT       NOT NULL REFERENCES service_requests(id) ON DELETE CASCADE,
    from_status_id  SMALLINT     REFERENCES request_statuses(id),
    to_status_id    SMALLINT     NOT NULL REFERENCES request_statuses(id),
    changed_by      BIGINT       REFERENCES users(id) ON DELETE SET NULL,
    comment         TEXT,
    changed_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

COMMENT ON SCHEMA autoservice IS 'ИС управления работой сети автосервиса';
COMMENT ON TABLE mechanic_locations IS 'M:N связь механиков и точек обслуживания';
COMMENT ON TABLE part_compatibilities IS 'M:N совместимость запчастей с марками/моделями';
COMMENT ON TABLE service_type_parts IS 'M:N связь услуг модификации и запчастей';
