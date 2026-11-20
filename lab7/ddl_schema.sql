-- Очистка схемы перед созданием (DDL: DROP / CREATE SCHEMA)
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;

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
    network_id INTEGER NOT NULL,
    store_name VARCHAR(150) NOT NULL,
    branch_name VARCHAR(150),
    address VARCHAR(255) NOT NULL,
    star_rating NUMERIC(2, 1) CHECK (star_rating >= 0 AND star_rating <= 5),
    description TEXT,
    logo_or_photo_url VARCHAR(500),
    has_food_court BOOLEAN DEFAULT FALSE,
    min_check NUMERIC(10, 2) DEFAULT 0.00 CHECK (min_check >= 0),
    CONSTRAINT fk_stores_network FOREIGN KEY (network_id) 
        REFERENCES retail_networks(network_id) ON DELETE CASCADE
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
    program_id INTEGER NOT NULL,
    network_id INTEGER NOT NULL,
    PRIMARY KEY (program_id, network_id),
    CONSTRAINT fk_pn_program FOREIGN KEY (program_id) 
        REFERENCES loyalty_programs(program_id) ON DELETE CASCADE,
    CONSTRAINT fk_pn_network FOREIGN KEY (network_id) 
        REFERENCES retail_networks(network_id) ON DELETE CASCADE
);

-- 5. Клиенты
CREATE TABLE clients (
    client_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parent_client_id INTEGER,
    client_type VARCHAR(30) NOT NULL CHECK (client_type IN ('физлицо', 'корпоративный')),
    full_name VARCHAR(200) NOT NULL,
    birth_date DATE,
    phone VARCHAR(20),
    email VARCHAR(100),
    is_regular BOOLEAN DEFAULT FALSE,
    CONSTRAINT fk_clients_parent FOREIGN KEY (parent_client_id) 
        REFERENCES clients(client_id) ON DELETE SET NULL
);

-- 6. Справочник дополнительных скидок и льгот
CREATE TABLE discounts_benefits (
    discount_id VARCHAR(30) PRIMARY KEY,
    discount_type VARCHAR(50) NOT NULL,
    description TEXT,
    discount_percent NUMERIC(5, 2) NOT NULL CHECK (discount_percent > 0 AND discount_percent <= 100)
);

-- 7. Выпущенные карты
CREATE TABLE issued_cards (
    card_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id INTEGER,
    program_id INTEGER NOT NULL,
    discount_id VARCHAR(30),
    order_status VARCHAR(30) NOT NULL CHECK (order_status IN ('оформлена', 'оплачена', 'активна', 'истекла')),
    issue_date DATE NOT NULL DEFAULT CURRENT_DATE,
    activation_date DATE,
    expiration_date DATE,
    special_notes TEXT,
    CONSTRAINT fk_cards_client FOREIGN KEY (client_id) 
        REFERENCES clients(client_id) ON DELETE SET NULL,
    CONSTRAINT fk_cards_program FOREIGN KEY (program_id) 
        REFERENCES loyalty_programs(program_id) ON DELETE RESTRICT,
    CONSTRAINT fk_cards_discount FOREIGN KEY (discount_id) 
        REFERENCES discounts_benefits(discount_id) ON DELETE SET NULL,
    CONSTRAINT chk_dates CHECK (expiration_date IS NULL OR expiration_date >= issue_date)
);

-- 8. Транзакции
CREATE TABLE transactions (
    transaction_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    card_id INTEGER NOT NULL,
    store_id INTEGER NOT NULL,
    transaction_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    terminal_number VARCHAR(50),
    payment_system VARCHAR(30) CHECK (payment_system IN ('Visa', 'Mastercard', 'МИР', 'СБП', 'Белкарт')),
    bank_commission NUMERIC(10, 2) DEFAULT 0.00 CHECK (bank_commission >= 0),
    original_amount NUMERIC(10, 2) NOT NULL CHECK (original_amount >= 0),
    saved_amount NUMERIC(10, 2) NOT NULL DEFAULT 0.00 CHECK (saved_amount >= 0),
    CONSTRAINT fk_trans_card FOREIGN KEY (card_id) 
        REFERENCES issued_cards(card_id) ON DELETE RESTRICT,
    CONSTRAINT fk_trans_store FOREIGN KEY (store_id) 
        REFERENCES stores(store_id) ON DELETE RESTRICT
);

-- 9. Отзывы покупателей
CREATE TABLE reviews (
    review_id INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    client_id INTEGER NOT NULL,
    store_id INTEGER,
    program_id INTEGER,
    review_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment_text TEXT,
    CONSTRAINT fk_reviews_client FOREIGN KEY (client_id) 
        REFERENCES clients(client_id) ON DELETE CASCADE,
    CONSTRAINT fk_reviews_store FOREIGN KEY (store_id) 
        REFERENCES stores(store_id) ON DELETE CASCADE,
    CONSTRAINT fk_reviews_program FOREIGN KEY (program_id) 
        REFERENCES loyalty_programs(program_id) ON DELETE CASCADE,
    CONSTRAINT chk_review_target CHECK (store_id IS NOT NULL OR program_id IS NOT NULL)
);

-- Примеры команд ALTER TABLE (модификация структуры БД)
ALTER TABLE clients ADD CONSTRAINT uq_clients_email UNIQUE (email);
ALTER TABLE transactions ADD CONSTRAINT chk_saved_not_exceed_original CHECK (saved_amount <= original_amount);

-- Создание индексов (DDL: CREATE INDEX)
CREATE INDEX idx_stores_network ON stores(network_id);
CREATE INDEX idx_issued_cards_client ON issued_cards(client_id);
CREATE INDEX idx_transactions_card ON transactions(card_id);
CREATE INDEX idx_transactions_store ON transactions(store_id);
CREATE INDEX idx_transactions_date ON transactions(transaction_date);

-- Создание представления для отчетов руководства (DDL: CREATE VIEW)
CREATE VIEW v_network_turnover AS
SELECT 
    rn.name AS network_name,
    COUNT(t.transaction_id) AS total_transactions,
    COALESCE(SUM(t.original_amount), 0) AS total_turnover,
    COALESCE(SUM(t.saved_amount), 0) AS total_saved
FROM retail_networks rn
LEFT JOIN stores s ON rn.network_id = s.network_id
LEFT JOIN transactions t ON s.store_id = t.store_id
GROUP BY rn.network_id, rn.name;
