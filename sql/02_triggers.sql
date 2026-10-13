-- Триггеры целостности ИС автосервиса
SET search_path TO autoservice, public;

-- ---------------------------------------------------------------------------
-- Вспомогательная функция: обновление updated_at
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_service_locations_updated_at
BEFORE UPDATE ON service_locations
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_vehicles_updated_at
BEFORE UPDATE ON vehicles
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_service_types_updated_at
BEFORE UPDATE ON service_types
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_parts_updated_at
BEFORE UPDATE ON parts
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_service_requests_updated_at
BEFORE UPDATE ON service_requests
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_part_purchase_requests_updated_at
BEFORE UPDATE ON part_purchase_requests
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- ---------------------------------------------------------------------------
-- Механик в mechanic_locations обязан иметь роль MECHANIC
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_mechanic_role()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_role VARCHAR(32);
BEGIN
    SELECT r.code INTO v_role
    FROM users u
    JOIN roles r ON r.id = u.role_id
    WHERE u.id = NEW.mechanic_id;

    IF v_role IS DISTINCT FROM 'MECHANIC' THEN
        RAISE EXCEPTION 'Пользователь % не является механиком', NEW.mechanic_id;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_mechanic_locations_role
BEFORE INSERT OR UPDATE ON mechanic_locations
FOR EACH ROW EXECUTE FUNCTION check_mechanic_role();

-- ---------------------------------------------------------------------------
-- Владелец автомобиля — только CLIENT
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_vehicle_owner_is_client()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_role VARCHAR(32);
BEGIN
    SELECT r.code INTO v_role
    FROM users u
    JOIN roles r ON r.id = u.role_id
    WHERE u.id = NEW.owner_id;

    IF v_role IS DISTINCT FROM 'CLIENT' THEN
        RAISE EXCEPTION 'Владелец автомобиля должен иметь роль CLIENT';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_vehicles_owner_role
BEFORE INSERT OR UPDATE OF owner_id ON vehicles
FOR EACH ROW EXECUTE FUNCTION check_vehicle_owner_is_client();

-- ---------------------------------------------------------------------------
-- service_type_parts: запчасти можно связывать только с услугами модификации
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION check_service_type_is_modification()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_is_mod BOOLEAN;
BEGIN
    SELECT is_modification INTO v_is_mod
    FROM service_types
    WHERE id = NEW.service_type_id;

    IF NOT COALESCE(v_is_mod, FALSE) THEN
        RAISE EXCEPTION 'Запчасти можно связывать только с услугами модификации';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_service_type_parts_mod
BEFORE INSERT OR UPDATE ON service_type_parts
FOR EACH ROW EXECUTE FUNCTION check_service_type_is_modification();

-- ---------------------------------------------------------------------------
-- Целостность заявки: автомобиль принадлежит клиенту;
-- механик (если указан) работает в выбранной точке;
-- корректные переходы статусов
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION validate_service_request()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_owner BIGINT;
    v_loc_active BOOLEAN;
    v_mech_ok BOOLEAN;
    v_from_code VARCHAR(40);
    v_to_code VARCHAR(40);
    v_open_purchases INTEGER;
BEGIN
    SELECT owner_id INTO v_owner FROM vehicles WHERE id = NEW.vehicle_id;
    IF v_owner IS DISTINCT FROM NEW.client_id THEN
        RAISE EXCEPTION 'Автомобиль % не принадлежит клиенту %', NEW.vehicle_id, NEW.client_id;
    END IF;

    SELECT is_active INTO v_loc_active FROM service_locations WHERE id = NEW.location_id;
    IF NOT COALESCE(v_loc_active, FALSE) THEN
        RAISE EXCEPTION 'Точка обслуживания % неактивна', NEW.location_id;
    END IF;

    IF NEW.mechanic_id IS NOT NULL THEN
        SELECT EXISTS (
            SELECT 1
            FROM mechanic_locations ml
            JOIN users u ON u.id = ml.mechanic_id
            JOIN roles r ON r.id = u.role_id
            WHERE ml.mechanic_id = NEW.mechanic_id
              AND ml.location_id = NEW.location_id
              AND ml.is_active
              AND u.is_active
              AND r.code = 'MECHANIC'
        ) INTO v_mech_ok;

        IF NOT v_mech_ok THEN
            RAISE EXCEPTION 'Механик % не закреплён за точкой %', NEW.mechanic_id, NEW.location_id;
        END IF;
    END IF;

    IF TG_OP = 'UPDATE' AND NEW.status_id IS DISTINCT FROM OLD.status_id THEN
        SELECT code INTO v_from_code FROM request_statuses WHERE id = OLD.status_id;
        SELECT code INTO v_to_code FROM request_statuses WHERE id = NEW.status_id;

        IF v_from_code IN ('COMPLETED', 'CANCELLED') THEN
            RAISE EXCEPTION 'Нельзя менять статус завершённой/отменённой заявки';
        END IF;

        IF NOT (
            (v_from_code = 'NEW' AND v_to_code IN ('CONFIRMED', 'CANCELLED')) OR
            (v_from_code = 'CONFIRMED' AND v_to_code IN ('ASSIGNED', 'CANCELLED')) OR
            (v_from_code = 'ASSIGNED' AND v_to_code IN ('IN_PROGRESS', 'CANCELLED')) OR
            (v_from_code = 'IN_PROGRESS' AND v_to_code IN (
                'AWAITING_PART_APPROVAL', 'AWAITING_PART', 'COMPLETED', 'CANCELLED'
            )) OR
            (v_from_code = 'AWAITING_PART_APPROVAL' AND v_to_code IN (
                'AWAITING_PART', 'IN_PROGRESS', 'CANCELLED'
            )) OR
            (v_from_code = 'AWAITING_PART' AND v_to_code IN ('IN_PROGRESS', 'CANCELLED'))
        ) THEN
            RAISE EXCEPTION 'Недопустимый переход статуса: % -> %', v_from_code, v_to_code;
        END IF;

        IF v_to_code = 'ASSIGNED' AND NEW.mechanic_id IS NULL THEN
            RAISE EXCEPTION 'Для статуса ASSIGNED необходимо указать механика';
        END IF;

        IF v_to_code = 'COMPLETED' THEN
            SELECT COUNT(*) INTO v_open_purchases
            FROM part_purchase_requests
            WHERE request_id = NEW.id
              AND status IN ('PENDING', 'APPROVED', 'AUTO_APPROVED', 'PURCHASED');

            IF v_open_purchases > 0 THEN
                RAISE EXCEPTION
                    'Нельзя завершить заявку: есть незакрытые запросы на покупку запчастей';
            END IF;

            NEW.completed_at := COALESCE(NEW.completed_at, NOW());
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_service_requests_validate
BEFORE INSERT OR UPDATE ON service_requests
FOR EACH ROW EXECUTE FUNCTION validate_service_request();

-- ---------------------------------------------------------------------------
-- История статусов
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION log_request_status_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO request_status_history(request_id, from_status_id, to_status_id, comment)
        VALUES (NEW.id, NULL, NEW.status_id, 'Создание заявки');
    ELSIF NEW.status_id IS DISTINCT FROM OLD.status_id THEN
        INSERT INTO request_status_history(request_id, from_status_id, to_status_id, comment)
        VALUES (NEW.id, OLD.status_id, NEW.status_id, 'Смена статуса');
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_service_requests_status_hist
AFTER INSERT OR UPDATE OF status_id ON service_requests
FOR EACH ROW EXECUTE FUNCTION log_request_status_change();

-- ---------------------------------------------------------------------------
-- Запрос на покупку: только механик заявки; авто-approval по режиму
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION validate_part_purchase_request()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_req RECORD;
    v_status VARCHAR(40);
    v_client BIGINT;
BEGIN
    SELECT sr.*, rs.code AS status_code
    INTO v_req
    FROM service_requests sr
    JOIN request_statuses rs ON rs.id = sr.status_id
    WHERE sr.id = NEW.request_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Заявка % не найдена', NEW.request_id;
    END IF;

    IF v_req.status_code NOT IN ('IN_PROGRESS', 'AWAITING_PART_APPROVAL', 'AWAITING_PART') THEN
        RAISE EXCEPTION 'Запрос на покупку возможен только для активной заявки в работе';
    END IF;

    IF TG_OP = 'INSERT' THEN
        IF NEW.created_by IS DISTINCT FROM v_req.mechanic_id THEN
            RAISE EXCEPTION 'Создавать запрос на покупку может только назначенный механик';
        END IF;

        IF v_req.purchase_approval_mode = 'ALLOW_WITHOUT_CONFIRMATION' THEN
            NEW.status := 'AUTO_APPROVED';
        ELSE
            NEW.status := 'PENDING';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_part_purchase_requests_validate
BEFORE INSERT OR UPDATE ON part_purchase_requests
FOR EACH ROW EXECUTE FUNCTION validate_part_purchase_request();

-- После создания запроса на покупку — смена статуса заявки и auto purchase_approval
CREATE OR REPLACE FUNCTION after_part_purchase_request()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_mode VARCHAR(40);
    v_status_await_approval SMALLINT;
    v_status_await_part SMALLINT;
BEGIN
    SELECT purchase_approval_mode INTO v_mode
    FROM service_requests WHERE id = NEW.request_id;

    SELECT id INTO v_status_await_approval FROM request_statuses WHERE code = 'AWAITING_PART_APPROVAL';
    SELECT id INTO v_status_await_part FROM request_statuses WHERE code = 'AWAITING_PART';

    IF NEW.status = 'AUTO_APPROVED' THEN
        INSERT INTO purchase_approvals(purchase_request_id, decided_by, decision, comment)
        VALUES (NEW.id, NEW.created_by, 'AUTO_APPROVED', 'Предварительное разрешение клиента');

        UPDATE service_requests
        SET status_id = v_status_await_part
        WHERE id = NEW.request_id;
    ELSIF NEW.status = 'PENDING' THEN
        UPDATE service_requests
        SET status_id = v_status_await_approval
        WHERE id = NEW.request_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_part_purchase_requests_after
AFTER INSERT ON part_purchase_requests
FOR EACH ROW EXECUTE FUNCTION after_part_purchase_request();

-- Решение клиента по покупке — только владелец заявки
CREATE OR REPLACE FUNCTION validate_purchase_approval()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_client BIGINT;
    v_mode VARCHAR(40);
    v_ppr_status VARCHAR(32);
    v_status_await_part SMALLINT;
    v_status_in_progress SMALLINT;
    v_request_id BIGINT;
BEGIN
    SELECT ppr.request_id, ppr.status, sr.client_id, sr.purchase_approval_mode
    INTO v_request_id, v_ppr_status, v_client, v_mode
    FROM part_purchase_requests ppr
    JOIN service_requests sr ON sr.id = ppr.request_id
    WHERE ppr.id = NEW.purchase_request_id;

    IF NEW.decision = 'AUTO_APPROVED' THEN
        RETURN NEW;
    END IF;

    IF NEW.decided_by IS DISTINCT FROM v_client THEN
        RAISE EXCEPTION 'Подтвердить/отклонить покупку может только владелец заявки';
    END IF;

    IF v_ppr_status <> 'PENDING' THEN
        RAISE EXCEPTION 'Решение возможно только для запроса в статусе PENDING';
    END IF;

    SELECT id INTO v_status_await_part FROM request_statuses WHERE code = 'AWAITING_PART';
    SELECT id INTO v_status_in_progress FROM request_statuses WHERE code = 'IN_PROGRESS';

    IF NEW.decision = 'APPROVED' THEN
        UPDATE part_purchase_requests
        SET status = 'APPROVED'
        WHERE id = NEW.purchase_request_id;

        UPDATE service_requests
        SET status_id = v_status_await_part
        WHERE id = v_request_id;
    ELSIF NEW.decision = 'REJECTED' THEN
        UPDATE part_purchase_requests
        SET status = 'REJECTED'
        WHERE id = NEW.purchase_request_id;

        UPDATE service_requests
        SET status_id = v_status_in_progress
        WHERE id = v_request_id;
    END IF;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_purchase_approvals_validate
BEFORE INSERT ON purchase_approvals
FOR EACH ROW EXECUTE FUNCTION validate_purchase_approval();

-- Work report: только механик заявки; заявка COMPLETED или готовится к завершению
CREATE OR REPLACE FUNCTION validate_work_report()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_mech BIGINT;
BEGIN
    SELECT mechanic_id INTO v_mech FROM service_requests WHERE id = NEW.request_id;
    IF NEW.mechanic_id IS DISTINCT FROM v_mech THEN
        RAISE EXCEPTION 'Отчёт может создать только назначенный механик';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_work_reports_validate
BEFORE INSERT OR UPDATE ON work_reports
FOR EACH ROW EXECUTE FUNCTION validate_work_report();
