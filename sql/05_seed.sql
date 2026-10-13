-- Тестовые данные ИС автосервиса
SET search_path TO autoservice, public;

-- Роли и статусы
INSERT INTO roles(code, name_ru) VALUES
    ('CLIENT', 'Клиент'),
    ('MANAGER', 'Менеджер'),
    ('MECHANIC', 'Механик');

INSERT INTO request_statuses(code, name_ru, is_terminal) VALUES
    ('NEW', 'Новая', FALSE),
    ('CONFIRMED', 'Подтверждена', FALSE),
    ('ASSIGNED', 'Назначена механику', FALSE),
    ('IN_PROGRESS', 'В работе', FALSE),
    ('AWAITING_PART_APPROVAL', 'Ожидает согласования покупки', FALSE),
    ('AWAITING_PART', 'Ожидает деталь', FALSE),
    ('COMPLETED', 'Завершена', TRUE),
    ('CANCELLED', 'Отменена', TRUE);

-- Пользователи (password_hash — учебный bcrypt-подобный плейсхолдер)
INSERT INTO users(email, password_hash, full_name, phone, role_id) VALUES
    ('ivanov@example.com', '$2a$10$clienthashivanov00000000000000000000000000000', 'Иванов Алексей', '+79001112233', 1),
    ('petrova@example.com', '$2a$10$clienthashpetrova0000000000000000000000000000', 'Петрова Мария', '+79002223344', 1),
    ('manager@autoservice.ru', '$2a$10$managerhash000000000000000000000000000000000', 'Сидоров Игорь', '+79003334455', 2),
    ('mech.north@autoservice.ru', '$2a$10$mech1hash00000000000000000000000000000000000', 'Кузнецов Дмитрий', '+79004445566', 3),
    ('mech.south@autoservice.ru', '$2a$10$mech2hash00000000000000000000000000000000000', 'Орлов Сергей', '+79005556677', 3),
    ('mech.both@autoservice.ru', '$2a$10$mech3hash00000000000000000000000000000000000', 'Волков Андрей', '+79006667788', 3);

INSERT INTO service_locations(name, address, phone, work_schedule, is_active) VALUES
    ('АвтоСервис Север', 'Санкт-Петербург, пр. Просвещения, 10', '+78121000001', 'Пн-Сб 09:00-20:00', TRUE),
    ('АвтоСервис Юг', 'Санкт-Петербург, ул. Типанова, 21', '+78121000002', 'Пн-Вс 10:00-21:00', TRUE),
    ('АвтоСервис Центр', 'Санкт-Петербург, Невский пр., 100', '+78121000003', 'Пн-Пт 09:00-19:00', FALSE);

INSERT INTO mechanic_locations(mechanic_id, location_id) VALUES
    (4, 1),
    (5, 2),
    (6, 1),
    (6, 2);

INSERT INTO vehicles(owner_id, make, model, year, plate_number, vin) VALUES
    (1, 'Toyota', 'Camry', 2019, 'А123ВС178', 'JTNB11HK40K123456'),
    (1, 'BMW', 'X5', 2021, 'В456ОР178', 'WBAJU01070B123456'),
    (2, 'Lada', 'Vesta', 2020, 'С789КТ178', 'XTA21914001234567'),
    (2, 'Hyundai', 'Solaris', 2018, 'Е111МН178', NULL);

INSERT INTO service_types(code, name, description, category, base_price, is_modification, is_active) VALUES
    ('DIAG', 'Диагностика', 'Компьютерная и визуальная диагностика', 'Диагностика', 1500, FALSE, TRUE),
    ('OIL', 'Замена масла', 'Замена моторного масла и фильтра', 'ТО', 2500, FALSE, TRUE),
    ('BRAKE', 'Ремонт тормозной системы', 'Диагностика и ремонт тормозов', 'Ремонт', 4000, FALSE, TRUE),
    ('SUSP', 'Ремонт подвески', 'Ремонт элементов подвески', 'Ремонт', 5000, FALSE, TRUE),
    ('MOD', 'Модификация автомобиля', 'Установка тюнинг-компонентов', 'Модификация', 7000, TRUE, TRUE);

INSERT INTO parts(sku, name, description, approx_price, is_orderable, is_active) VALUES
    ('SPLR-CAMRY-01', 'Спойлер Toyota Camry', 'Задний спойлер для Camry', 12000, TRUE, TRUE),
    ('TYRE-BMW-19', 'Комплект шин BMW 19"', 'Летний комплект 19 дюймов', 48000, TRUE, TRUE),
    ('PAD-UNIVERSAL', 'Тормозные колодки', 'Комплект передних колодок', 4500, TRUE, TRUE),
    ('OIL-5W30', 'Масло 5W-30 4л', 'Синтетическое моторное масло', 3200, TRUE, TRUE),
    ('ARM-VESTA', 'Рычаг подвески Lada Vesta', 'Передний рычаг', 6100, TRUE, TRUE),
    ('FILTER-OIL', 'Масляный фильтр', 'Универсальный фильтр', 800, TRUE, TRUE);

INSERT INTO part_compatibilities(part_id, make, model, year_from, year_to) VALUES
    (1, 'Toyota', 'Camry', 2018, 2024),
    (2, 'BMW', 'X5', 2019, 2025),
    (3, 'Toyota', 'Camry', 2015, 2025),
    (3, 'BMW', 'X5', 2015, 2025),
    (3, 'Lada', 'Vesta', 2015, 2025),
    (3, 'Hyundai', 'Solaris', 2015, 2025),
    (4, 'Toyota', 'Camry', NULL, NULL),
    (4, 'Hyundai', 'Solaris', NULL, NULL),
    (5, 'Lada', 'Vesta', 2015, 2024),
    (6, 'Toyota', 'Camry', NULL, NULL),
    (6, 'BMW', 'X5', NULL, NULL),
    (6, 'Lada', 'Vesta', NULL, NULL),
    (6, 'Hyundai', 'Solaris', NULL, NULL);

INSERT INTO service_type_parts(service_type_id, part_id, is_required) VALUES
    (5, 1, FALSE),
    (5, 2, FALSE);

-- Сценарий 1: завершённая заявка ТО без доп. покупки
SELECT create_service_request(
    1, 1, 2, 1,
    'Плановое ТО, замена масла',
    CURRENT_DATE + 3,
    'ALLOW_WITHOUT_CONFIRMATION',
    NULL
);

CALL confirm_and_assign_request(1, 4, CURRENT_DATE + 3);
CALL start_work(1, 4);
CALL complete_request(
    1, 4,
    'Уровень масла ниже нормы',
    'Замена масла и фильтра',
    'ТО выполнено, замечаний нет',
    2500
);

INSERT INTO request_parts(request_id, part_id, quantity, unit_price, source, is_installed)
VALUES (1, 4, 1, 3200, 'INSTALLED', TRUE),
       (1, 6, 1, 800, 'INSTALLED', TRUE);

-- Сценарий 2: модификация с выбранной запчастью клиента
SELECT create_service_request(
    1, 1, 5, 1,
    'Установка заднего спойлера',
    CURRENT_DATE + 7,
    'REQUIRE_CONFIRMATION',
    1
);

CALL confirm_and_assign_request(2, 6, CURRENT_DATE + 7);
CALL start_work(2, 6);

-- Сценарий 3: ремонт с запросом покупки и подтверждением клиента
SELECT create_service_request(
    2, 3, 4, 2,
    'Стук в передней подвеске',
    CURRENT_DATE + 2,
    'REQUIRE_CONFIRMATION',
    NULL
);

CALL confirm_and_assign_request(3, 5, CURRENT_DATE + 2);
CALL start_work(3, 5);

SELECT create_part_purchase_request(
    3, 5, 5, 1,
    'Износ переднего рычага, требуется замена',
    6100
);

CALL decide_purchase(1, 2, 'APPROVED', 'Согласен на замену рычага');
CALL mark_part_purchased_and_received(1, 5);
CALL complete_request(
    3, 5,
    'Износ сайлентблоков рычага',
    'Замена переднего рычага подвески',
    'Стук устранён, сход-развал рекомендован',
    5000
);

-- Сценарий 4: новая заявка, ожидающая менеджера
SELECT create_service_request(
    2, 4, 1, 2,
    'Горит Check Engine',
    CURRENT_DATE + 1,
    'ALLOW_WITHOUT_CONFIRMATION',
    NULL
);
