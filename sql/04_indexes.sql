-- Индексы под прецеденты этапа 1
SET search_path TO autoservice, public;

-- C001: вход по email
CREATE INDEX IF NOT EXISTS idx_users_email_lower ON users (lower(email));

-- C002/C006: автомобили клиента и история по автомобилю
CREATE INDEX IF NOT EXISTS idx_vehicles_owner_id ON vehicles (owner_id);
CREATE INDEX IF NOT EXISTS idx_service_requests_vehicle_id ON service_requests (vehicle_id);

-- C004: список заявок клиента
CREATE INDEX IF NOT EXISTS idx_service_requests_client_id ON service_requests (client_id);

-- M000: фильтры менеджера по статусу, дате, механику
CREATE INDEX IF NOT EXISTS idx_service_requests_status_id ON service_requests (status_id);
CREATE INDEX IF NOT EXISTS idx_service_requests_desired_date ON service_requests (desired_date);
CREATE INDEX IF NOT EXISTS idx_service_requests_mechanic_id ON service_requests (mechanic_id);
CREATE INDEX IF NOT EXISTS idx_service_requests_location_id ON service_requests (location_id);

-- K000: заявки механика
CREATE INDEX IF NOT EXISTS idx_service_requests_mechanic_status
    ON service_requests (mechanic_id, status_id);

-- C008/C009/N014: поиск совместимых запчастей
CREATE INDEX IF NOT EXISTS idx_part_compat_make_model
    ON part_compatibilities (lower(make), lower(model));
CREATE INDEX IF NOT EXISTS idx_part_compat_part_id ON part_compatibilities (part_id);

-- M007: каталог и связь с услугами модификации
CREATE INDEX IF NOT EXISTS idx_parts_active_orderable
    ON parts (is_active, is_orderable)
    WHERE is_active AND is_orderable;
CREATE INDEX IF NOT EXISTS idx_service_type_parts_part_id ON service_type_parts (part_id);

-- M002/N015: проверка закрепления механика за точкой
CREATE INDEX IF NOT EXISTS idx_mechanic_locations_location
    ON mechanic_locations (location_id)
    WHERE is_active;

-- M008/C011: открытые запросы на покупку
CREATE INDEX IF NOT EXISTS idx_ppr_request_status
    ON part_purchase_requests (request_id, status);
CREATE INDEX IF NOT EXISTS idx_ppr_status_pending
    ON part_purchase_requests (status)
    WHERE status IN ('PENDING', 'APPROVED', 'AUTO_APPROVED', 'PURCHASED');

-- Аудит и детализация заявки
CREATE INDEX IF NOT EXISTS idx_request_status_history_request_id
    ON request_status_history (request_id, changed_at DESC);
CREATE INDEX IF NOT EXISTS idx_request_parts_request_id ON request_parts (request_id);
