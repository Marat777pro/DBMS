-- 1. Торговые сети
CREATE TABLE retail_networks (
    network_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    hq_city VARCHAR(100),
    stores_count INTEGER DEFAULT 0 CHECK (stores_count >= 0),
    service_language VARCHAR(50),
    coverage_region VARCHAR(255),
    goods_category VARCHAR(100),
    currency VARCHAR(10) DEFAULT 'BYN',
    features TEXT,
    registration_rules TEXT,
    legal_restrictions TEXT,
    has_purchase_insurance BOOLEAN DEFAULT FALSE,
    other_services TEXT
);

-- 2. Торговые точки (филиалы)
CREATE TABLE stores (
    store_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    network_id INTEGER NOT NULL REFERENCES retail_networks(network_id) ON DELETE CASCADE,
    store_name VARCHAR(150) NOT NULL,
    branch_name VARCHAR(150),
    address VARCHAR(255) NOT NULL,
    star_rating NUMERIC(2, 1) CHECK (star_rating >= 0 AND star_rating <= 5),
    description TEXT,
    logo_or_photo_url VARCHAR(500),
    has_food_court BOOLEAN DEFAULT FALSE,
    min_check NUMERIC(10, 2) DEFAULT 0.00 CHECK (min_check >= 0)
);

-- 3. Программы лояльности
CREATE TABLE loyalty_programs (
    program_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    program_name VARCHAR(150) NOT NULL,
    card_type VARCHAR(50) NOT NULL CHECK (card_type IN ('накопительная', 'фиксированная скидка', 'бонусная', 'клубная привилегированная')),
    validity_months INTEGER NOT NULL CHECK (validity_months > 0),
    service_cost NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (service_cost >= 0),
    description TEXT
);

-- 4. Связь программ и торговых сетей (М:М)
CREATE TABLE program_networks (
    program_id INTEGER NOT NULL REFERENCES loyalty_programs(program_id) ON DELETE CASCADE,
    network_id INTEGER NOT NULL REFERENCES retail_networks(network_id) ON DELETE CASCADE,
    PRIMARY KEY (program_id, network_id)
);

-- 5. Клиенты
CREATE TABLE clients (
    client_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_client_id INTEGER REFERENCES clients(client_id) ON DELETE SET NULL,
    client_type VARCHAR(30) NOT NULL CHECK (client_type IN ('физлицо', 'корпоративный')),
    full_name VARCHAR(200) NOT NULL,
    birth_date DATE,
    phone VARCHAR(20),
    email VARCHAR(100),
    is_regular BOOLEAN DEFAULT FALSE
);

-- 6. Дополнительные скидки и льготы
CREATE TABLE discounts_benefits (
    discount_id VARCHAR(30) PRIMARY KEY,
    discount_type VARCHAR(50) NOT NULL,
    description TEXT,
    discount_percent NUMERIC(5, 2) NOT NULL CHECK (discount_percent > 0 AND discount_percent <= 100)
);

-- 7. Выпущенные карты
CREATE TABLE issued_cards (
    card_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id INTEGER REFERENCES clients(client_id) ON DELETE SET NULL,
    program_id INTEGER NOT NULL REFERENCES loyalty_programs(program_id) ON DELETE RESTRICT,
    discount_id VARCHAR(30) REFERENCES discounts_benefits(discount_id) ON DELETE SET NULL,
    order_status VARCHAR(30) NOT NULL CHECK (order_status IN ('оформлена', 'оплачена', 'активна', 'истекла')),
    issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
    activation_date DATE,
    expiration_date DATE,
    special_notes TEXT,
    CONSTRAINT chk_dates CHECK (expiration_date IS NULL OR expiration_date >= issue_date)
);

-- 8. Транзакции
CREATE TABLE transactions (
    transaction_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    card_id INTEGER NOT NULL REFERENCES issued_cards(card_id) ON DELETE RESTRICT,
    store_id INTEGER NOT NULL REFERENCES stores(store_id) ON DELETE RESTRICT,
    transaction_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    terminal_number VARCHAR(50),
    payment_system VARCHAR(30) CHECK (payment_system IN ('Visa', 'Mastercard', 'МИР', 'СБП', 'Белкарт')),
    bank_commission NUMERIC(10, 2) DEFAULT 0.00 CHECK (bank_commission >= 0),
    original_amount NUMERIC(10, 2) NOT NULL CHECK (original_amount >= 0),
    saved_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (saved_amount >= 0)
);

-- 9. Отзывы
CREATE TABLE reviews (
    review_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id INTEGER NOT NULL REFERENCES clients(client_id) ON DELETE CASCADE,
    store_id INTEGER REFERENCES stores(store_id) ON DELETE CASCADE,
    program_id INTEGER REFERENCES loyalty_programs(program_id) ON DELETE CASCADE,
    review_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment_text TEXT,
    CONSTRAINT chk_review_target CHECK (store_id IS NOT NULL OR program_id IS NOT NULL)
);

-- Индексы
CREATE INDEX idx_stores_network ON stores(network_id);
CREATE INDEX idx_issued_cards_client ON issued_cards(client_id);
CREATE INDEX idx_transactions_card ON transactions(card_id);
CREATE INDEX idx_transactions_store ON transactions(store_id);
CREATE INDEX idx_transactions_date ON transactions(transaction_date);

-- Тестовые данные
INSERT INTO retail_networks (name, hq_city, stores_count, service_language, coverage_region, goods_category, currency, has_purchase_insurance)
VALUES ('Евроопт', 'Минск', 1100, 'Русский', 'Вся Беларусь', 'Продукты питания', 'BYN', FALSE),
       ('5 Элемент', 'Минск', 75, 'Русский', 'Вся Беларусь', 'Электроника и бытовая техника', 'BYN', TRUE);

INSERT INTO stores (network_id, store_name, branch_name, address, star_rating, has_food_court, min_check)
VALUES (1, 'Евроопт Super', 'ТЦ Тринити', 'г. Гродно, пр-т Янки Купалы, 87', 4.8, TRUE, 5.00),
       (2, '5 Элемент', 'ТЦ OldCity', 'г. Гродно, ул. Дубко, 17', 4.9, TRUE, 10.00);

INSERT INTO loyalty_programs (program_name, card_type, validity_months, service_cost, description)
VALUES ('Еплюс Плюс', 'бонусная', 36, 2.99, 'Начисление бонусных баллов за каждую покупку в сети партнеров'),
       ('Клуб Привилегий', 'клубная привилегированная', 12, 15.00, 'Фиксированная скидка 7% и расширенная гарантия');

INSERT INTO program_networks (program_id, network_id) VALUES (1, 1), (1, 2), (2, 2);

INSERT INTO discounts_benefits (discount_id, discount_type, description, discount_percent)
VALUES ('PENSION_10', 'Возрастная льгота', 'Скидка 10% для пенсионеров и детей', 10.00),
       ('REGULAR_12', 'За лояльность', 'Скидка 12% на обслуживание после 3 покупок', 12.00);

INSERT INTO clients (client_type, full_name, birth_date, phone, email, is_regular)
VALUES ('физлицо', 'Иванов Иван Иванович', '1985-05-15', '+375291112233', 'ivanov@mail.by', TRUE);

INSERT INTO issued_cards (client_id, program_id, discount_id, order_status, issue_date, activation_date, expiration_date)
VALUES (1, 1, 'REGULAR_12', 'активна', '2026-01-10', '2026-01-10', '2029-01-10');

INSERT INTO transactions (card_id, store_id, terminal_number, payment_system, bank_commission, original_amount, saved_amount)
VALUES (1, 1, 'POS-04', 'Белкарт', 0.45, 85.50, 8.55);

INSERT INTO reviews (client_id, store_id, rating, comment_text)
VALUES (1, 1, 5, 'Отличный магазин, бонусы начислили мгновенно!');
