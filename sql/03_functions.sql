-- PL/pgSQL функции и процедуры для критических операций прецедентов
SET search_path TO autoservice, public;

-- ---------------------------------------------------------------------------
-- C000: регистрация клиента
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION register_client(
    p_email VARCHAR,
    p_password_hash VARCHAR,
    p_full_name VARCHAR,
    p_phone VARCHAR DEFAULT NULL
) RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_role_id SMALLINT;
    v_id BIGINT;
BEGIN
    SELECT id INTO v_role_id FROM roles WHERE code = 'CLIENT';
    INSERT INTO users(email, password_hash, full_name, phone, role_id)
    VALUES (lower(trim(p_email)), p_password_hash, p_full_name, p_phone, v_role_id)
    RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- C002: добавить автомобиль клиенту
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION add_vehicle(
    p_owner_id BIGINT,
    p_make VARCHAR,
    p_model VARCHAR,
    p_year INTEGER,
    p_plate_number VARCHAR,
    p_vin VARCHAR DEFAULT NULL
) RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO vehicles(owner_id, make, model, year, plate_number, vin)
    VALUES (p_owner_id, p_make, p_model, p_year, upper(trim(p_plate_number)), NULLIF(upper(trim(p_vin)), ''))
    RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- C003: создать заявку
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION create_service_request(
    p_client_id BIGINT,
    p_vehicle_id BIGINT,
    p_service_type_id BIGINT,
    p_location_id BIGINT,
    p_description TEXT,
    p_desired_date DATE,
    p_purchase_approval_mode VARCHAR,
    p_part_id BIGINT DEFAULT NULL
) RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_status_id SMALLINT;
    v_is_mod BOOLEAN;
    v_compat BOOLEAN;
    v_vehicle RECORD;
    v_id BIGINT;
    v_price NUMERIC(12,2);
BEGIN
    SELECT id INTO v_status_id FROM request_statuses WHERE code = 'NEW';

    SELECT * INTO v_vehicle FROM vehicles WHERE id = p_vehicle_id;
    IF v_vehicle.owner_id <> p_client_id THEN
        RAISE EXCEPTION 'Автомобиль не принадлежит клиенту';
    END IF;

    SELECT is_modification INTO v_is_mod FROM service_types WHERE id = p_service_type_id AND is_active;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Тип услуги недоступен';
    END IF;

    IF v_is_mod THEN
        IF p_part_id IS NULL THEN
            RAISE EXCEPTION 'Для модификации необходимо выбрать запчасть';
        END IF;

        SELECT EXISTS (
            SELECT 1
            FROM service_type_parts stp
            JOIN part_compatibilities pc ON pc.part_id = stp.part_id
            JOIN parts p ON p.id = stp.part_id
            WHERE stp.service_type_id = p_service_type_id
              AND stp.part_id = p_part_id
              AND p.is_active AND p.is_orderable
              AND lower(pc.make) = lower(v_vehicle.make)
              AND lower(pc.model) = lower(v_vehicle.model)
              AND (pc.year_from IS NULL OR pc.year_from <= v_vehicle.year)
              AND (pc.year_to IS NULL OR pc.year_to >= v_vehicle.year)
        ) INTO v_compat;

        IF NOT v_compat THEN
            RAISE EXCEPTION 'Запчасть несовместима с автомобилем или услугой';
        END IF;
    END IF;

    INSERT INTO service_requests(
        client_id, vehicle_id, service_type_id, location_id, status_id,
        description, desired_date, purchase_approval_mode
    ) VALUES (
        p_client_id, p_vehicle_id, p_service_type_id, p_location_id, v_status_id,
        p_description, p_desired_date, p_purchase_approval_mode
    ) RETURNING id INTO v_id;

    IF p_part_id IS NOT NULL THEN
        SELECT approx_price INTO v_price FROM parts WHERE id = p_part_id;
        INSERT INTO request_parts(request_id, part_id, quantity, unit_price, source)
        VALUES (v_id, p_part_id, 1, v_price, 'CLIENT_SELECTED');
    END IF;

    RETURN v_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- M001/M002: подтвердить заявку и назначить механика
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE confirm_and_assign_request(
    p_request_id BIGINT,
    p_mechanic_id BIGINT,
    p_agreed_date DATE
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status_confirmed SMALLINT;
    v_status_assigned SMALLINT;
    v_current VARCHAR(40);
BEGIN
    SELECT rs.code INTO v_current
    FROM service_requests sr
    JOIN request_statuses rs ON rs.id = sr.status_id
    WHERE sr.id = p_request_id
    FOR UPDATE OF sr;

    IF v_current <> 'NEW' THEN
        RAISE EXCEPTION 'Подтверждать можно только заявку в статусе NEW';
    END IF;

    SELECT id INTO v_status_confirmed FROM request_statuses WHERE code = 'CONFIRMED';
    SELECT id INTO v_status_assigned FROM request_statuses WHERE code = 'ASSIGNED';

    UPDATE service_requests
    SET status_id = v_status_confirmed,
        agreed_date = p_agreed_date
    WHERE id = p_request_id;

    UPDATE service_requests
    SET mechanic_id = p_mechanic_id,
        status_id = v_status_assigned
    WHERE id = p_request_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- K002: начать работу
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE start_work(p_request_id BIGINT, p_mechanic_id BIGINT)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status_in_progress SMALLINT;
    v_mechanic_id BIGINT;
    v_code VARCHAR(40);
BEGIN
    SELECT sr.mechanic_id, rs.code
    INTO v_mechanic_id, v_code
    FROM service_requests sr
    JOIN request_statuses rs ON rs.id = sr.status_id
    WHERE sr.id = p_request_id
    FOR UPDATE OF sr;

    IF v_code <> 'ASSIGNED' THEN
        RAISE EXCEPTION 'Начать работу можно только из статуса ASSIGNED';
    END IF;

    IF v_mechanic_id IS DISTINCT FROM p_mechanic_id THEN
        RAISE EXCEPTION 'Заявка назначена другому механику';
    END IF;

    SELECT id INTO v_status_in_progress FROM request_statuses WHERE code = 'IN_PROGRESS';
    UPDATE service_requests SET status_id = v_status_in_progress WHERE id = p_request_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- K005: создать запрос на покупку запчасти
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION create_part_purchase_request(
    p_request_id BIGINT,
    p_mechanic_id BIGINT,
    p_part_id BIGINT,
    p_quantity INTEGER,
    p_reason TEXT,
    p_estimated_cost NUMERIC
) RETURNS BIGINT
LANGUAGE plpgsql
AS $$
DECLARE
    v_id BIGINT;
BEGIN
    INSERT INTO part_purchase_requests(
        request_id, part_id, created_by, quantity, reason, estimated_cost
    ) VALUES (
        p_request_id, p_part_id, p_mechanic_id, p_quantity, p_reason, p_estimated_cost
    ) RETURNING id INTO v_id;
    RETURN v_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- C011: решение клиента по покупке
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE decide_purchase(
    p_purchase_request_id BIGINT,
    p_client_id BIGINT,
    p_decision VARCHAR,
    p_comment TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_decision NOT IN ('APPROVED', 'REJECTED') THEN
        RAISE EXCEPTION 'Допустимы только APPROVED или REJECTED';
    END IF;

    INSERT INTO purchase_approvals(purchase_request_id, decided_by, decision, comment)
    VALUES (p_purchase_request_id, p_client_id, p_decision, p_comment);
END;
$$;

-- ---------------------------------------------------------------------------
-- K006/K007: отметить покупку и получение детали, вернуть заявку в работу
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE mark_part_purchased_and_received(
    p_purchase_request_id BIGINT,
    p_mechanic_id BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_ppr part_purchase_requests%ROWTYPE;
    v_status_in_progress SMALLINT;
    v_price NUMERIC(12,2);
BEGIN
    SELECT * INTO v_ppr
    FROM part_purchase_requests
    WHERE id = p_purchase_request_id
    FOR UPDATE;

    IF v_ppr.status NOT IN ('APPROVED', 'AUTO_APPROVED', 'PURCHASED') THEN
        RAISE EXCEPTION 'Деталь ещё не согласована к покупке';
    END IF;

    IF v_ppr.created_by IS DISTINCT FROM p_mechanic_id THEN
        RAISE EXCEPTION 'Операцию выполняет механик, создавший запрос';
    END IF;

    UPDATE part_purchase_requests
    SET status = 'RECEIVED',
        purchased_at = COALESCE(purchased_at, NOW()),
        received_at = NOW()
    WHERE id = p_purchase_request_id;

    SELECT approx_price INTO v_price FROM parts WHERE id = v_ppr.part_id;

    INSERT INTO request_parts(request_id, part_id, quantity, unit_price, source, is_installed)
    VALUES (v_ppr.request_id, v_ppr.part_id, v_ppr.quantity, COALESCE(v_ppr.estimated_cost, v_price), 'INSTALLED', TRUE);

    SELECT id INTO v_status_in_progress FROM request_statuses WHERE code = 'IN_PROGRESS';
    UPDATE service_requests
    SET status_id = v_status_in_progress
    WHERE id = v_ppr.request_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- K003/K004: завершить заявку с отчётом
-- ---------------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE complete_request(
    p_request_id BIGINT,
    p_mechanic_id BIGINT,
    p_diagnosis TEXT,
    p_work_description TEXT,
    p_result_summary TEXT,
    p_labor_cost NUMERIC DEFAULT 0
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_status_completed SMALLINT;
    v_code VARCHAR(40);
BEGIN
    SELECT rs.code INTO v_code
    FROM service_requests sr
    JOIN request_statuses rs ON rs.id = sr.status_id
    WHERE sr.id = p_request_id
    FOR UPDATE OF sr;

    IF v_code <> 'IN_PROGRESS' THEN
        RAISE EXCEPTION 'Завершать можно только заявку в статусе IN_PROGRESS';
    END IF;

    INSERT INTO work_reports(request_id, mechanic_id, diagnosis, work_description, result_summary, labor_cost)
    VALUES (p_request_id, p_mechanic_id, p_diagnosis, p_work_description, p_result_summary, p_labor_cost);

    SELECT id INTO v_status_completed FROM request_statuses WHERE code = 'COMPLETED';
    UPDATE service_requests
    SET status_id = v_status_completed,
        completed_at = NOW()
    WHERE id = p_request_id;
END;
$$;

-- ---------------------------------------------------------------------------
-- C004/C006/C012: история обслуживания автомобиля
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_vehicle_service_history(p_vehicle_id BIGINT, p_client_id BIGINT)
RETURNS TABLE (
    request_id BIGINT,
    service_name VARCHAR,
    location_name VARCHAR,
    status_code VARCHAR,
    completed_at TIMESTAMPTZ,
    result_summary TEXT,
    parts_installed TEXT
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        sr.id,
        st.name,
        sl.name,
        rs.code,
        sr.completed_at,
        wr.result_summary,
        string_agg(DISTINCT p.name || ' x' || rp.quantity, ', ' ORDER BY p.name || ' x' || rp.quantity)
    FROM service_requests sr
    JOIN service_types st ON st.id = sr.service_type_id
    JOIN service_locations sl ON sl.id = sr.location_id
    JOIN request_statuses rs ON rs.id = sr.status_id
    LEFT JOIN work_reports wr ON wr.request_id = sr.id
    LEFT JOIN request_parts rp ON rp.request_id = sr.id AND rp.is_installed
    LEFT JOIN parts p ON p.id = rp.part_id
    WHERE sr.vehicle_id = p_vehicle_id
      AND sr.client_id = p_client_id
      AND rs.code = 'COMPLETED'
    GROUP BY sr.id, st.name, sl.name, rs.code, sr.completed_at, wr.result_summary
    ORDER BY sr.completed_at DESC NULLS LAST;
$$;

-- ---------------------------------------------------------------------------
-- C008: совместимые запчасти для автомобиля и услуги
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION find_compatible_parts(
    p_vehicle_id BIGINT,
    p_service_type_id BIGINT DEFAULT NULL
)
RETURNS TABLE (
    part_id BIGINT,
    sku VARCHAR,
    name VARCHAR,
    approx_price NUMERIC,
    make VARCHAR,
    model VARCHAR
)
LANGUAGE sql
STABLE
AS $$
    SELECT DISTINCT
        p.id, p.sku, p.name, p.approx_price, pc.make, pc.model
    FROM vehicles v
    JOIN part_compatibilities pc
      ON lower(pc.make) = lower(v.make)
     AND lower(pc.model) = lower(v.model)
     AND (pc.year_from IS NULL OR pc.year_from <= v.year)
     AND (pc.year_to IS NULL OR pc.year_to >= v.year)
    JOIN parts p ON p.id = pc.part_id AND p.is_active AND p.is_orderable
    LEFT JOIN service_type_parts stp ON stp.part_id = p.id
    WHERE v.id = p_vehicle_id
      AND (p_service_type_id IS NULL OR stp.service_type_id = p_service_type_id)
    ORDER BY p.name;
$$;

-- ---------------------------------------------------------------------------
-- M000: список заявок с фильтрами
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION list_requests_filtered(
    p_status_code VARCHAR DEFAULT NULL,
    p_client_id BIGINT DEFAULT NULL,
    p_mechanic_id BIGINT DEFAULT NULL,
    p_date_from DATE DEFAULT NULL,
    p_date_to DATE DEFAULT NULL
)
RETURNS TABLE (
    request_id BIGINT,
    client_name VARCHAR,
    vehicle_plate VARCHAR,
    service_name VARCHAR,
    location_name VARCHAR,
    status_code VARCHAR,
    desired_date DATE,
    mechanic_name VARCHAR
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        sr.id,
        c.full_name,
        v.plate_number,
        st.name,
        sl.name,
        rs.code,
        sr.desired_date,
        m.full_name
    FROM service_requests sr
    JOIN users c ON c.id = sr.client_id
    JOIN vehicles v ON v.id = sr.vehicle_id
    JOIN service_types st ON st.id = sr.service_type_id
    JOIN service_locations sl ON sl.id = sr.location_id
    JOIN request_statuses rs ON rs.id = sr.status_id
    LEFT JOIN users m ON m.id = sr.mechanic_id
    WHERE (p_status_code IS NULL OR rs.code = p_status_code)
      AND (p_client_id IS NULL OR sr.client_id = p_client_id)
      AND (p_mechanic_id IS NULL OR sr.mechanic_id = p_mechanic_id)
      AND (p_date_from IS NULL OR sr.desired_date >= p_date_from)
      AND (p_date_to IS NULL OR sr.desired_date <= p_date_to)
    ORDER BY sr.created_at DESC;
$$;
