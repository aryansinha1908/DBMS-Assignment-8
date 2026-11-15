-- =====================================================================
--  Package Delivery Database
-- =====================================================================

DROP DATABASE IF EXISTS package_delivery_db;
CREATE DATABASE package_delivery_db;
USE package_delivery_db;

CREATE TABLE customer (
    customer_id    INT           PRIMARY KEY,
    name           VARCHAR(80)   NOT NULL,
    customer_type  ENUM('Contract', 'Occasional') NOT NULL,
    account_no     CHAR(6)       UNIQUE,
    email          VARCHAR(100)  UNIQUE,
    phone          VARCHAR(15),
    house_no       VARCHAR(20)   NOT NULL,
    street         VARCHAR(60)   NOT NULL,
    city           VARCHAR(40)   NOT NULL,
    state          VARCHAR(40)   NOT NULL,
    pincode        CHAR(6)       NOT NULL,
    CHECK ( (customer_type = 'Contract'   AND account_no IS NOT NULL)
         OR (customer_type = 'Occasional' AND account_no IS NULL) ),
    CHECK (pincode REGEXP '^[1-9][0-9]{5}$')
);

CREATE TABLE service_type (
    service_id     INT           PRIMARY KEY,
    service_name   VARCHAR(40)   NOT NULL UNIQUE,
    package_type   ENUM('Envelope', 'Small Box', 'Large Box') NOT NULL,
    delivery_speed ENUM('Overnight', 'Second Day', 'Ground', 'International') NOT NULL,
    delivery_days  INT           NOT NULL,
    max_weight_kg  DECIMAL(6,2)  NOT NULL,
    base_rate      DECIMAL(8,2)  NOT NULL,
    rate_per_kg    DECIMAL(8,2)  NOT NULL,
    CHECK (delivery_days > 0),
    CHECK (max_weight_kg > 0),
    CHECK (base_rate >= 0 AND rate_per_kg >= 0)
);

CREATE TABLE location (
    location_id    INT           PRIMARY KEY,
    location_type  ENUM('Warehouse', 'Truck', 'Plane') NOT NULL,
    location_name  VARCHAR(60)   NOT NULL UNIQUE,
    city           VARCHAR(40)
);

CREATE TABLE package (
    tracking_no       CHAR(8)       PRIMARY KEY,
    shipper_id        INT           NOT NULL,
    payer_id          INT           NOT NULL,
    service_id        INT           NOT NULL,
    weight_kg         DECIMAL(6,2)  NOT NULL,
    hazard_class      VARCHAR(40),
    ship_time         DATETIME      NOT NULL,
    promised_by       DATETIME      NOT NULL,
    payment_type      ENUM('Account', 'Credit Card', 'Prepaid') NOT NULL,
    card_last4        CHAR(4),
    charge            DECIMAL(10,2) NOT NULL,
    recipient_name    VARCHAR(80)   NOT NULL,
    recipient_phone   VARCHAR(15),
    dest_address      VARCHAR(100)  NOT NULL,
    dest_city         VARCHAR(40)   NOT NULL,
    dest_postal_code  VARCHAR(10)   NOT NULL,
    dest_country      VARCHAR(40)   NOT NULL DEFAULT 'India',
    FOREIGN KEY (shipper_id) REFERENCES customer (customer_id),
    FOREIGN KEY (payer_id)   REFERENCES customer (customer_id),
    FOREIGN KEY (service_id) REFERENCES service_type (service_id),
    CHECK (weight_kg > 0),
    CHECK (charge >= 0),
    CHECK (promised_by > ship_time),
    CHECK ( (payment_type = 'Credit Card' AND card_last4 IS NOT NULL AND payer_id = shipper_id)
         OR (payment_type = 'Account'     AND card_last4 IS NULL     AND payer_id = shipper_id)
         OR (payment_type = 'Prepaid'     AND card_last4 IS NULL     AND payer_id <> shipper_id) )
);

CREATE TABLE customs_declaration (
    tracking_no     CHAR(8)        PRIMARY KEY,
    contents        VARCHAR(100)   NOT NULL,
    declared_value  DECIMAL(10,2)  NOT NULL,
    FOREIGN KEY (tracking_no) REFERENCES package (tracking_no) ON DELETE CASCADE,
    CHECK (declared_value > 0)
);

CREATE TABLE tracking_event (
    tracking_no   CHAR(8)   NOT NULL,
    event_time    DATETIME  NOT NULL,
    event_type    ENUM('Dropped Off', 'Picked Up', 'Arrived', 'Loaded',
                       'Out for Delivery', 'Delivered') NOT NULL,
    location_id   INT       NOT NULL,
    signed_by     VARCHAR(80),
    PRIMARY KEY (tracking_no, event_time),
    FOREIGN KEY (tracking_no) REFERENCES package (tracking_no) ON DELETE CASCADE,
    FOREIGN KEY (location_id) REFERENCES location (location_id),
    CHECK ( (event_type = 'Delivered' AND signed_by IS NOT NULL)
         OR (event_type <> 'Delivered' AND signed_by IS NULL) )
);

CREATE INDEX idx_event_location_time ON tracking_event (location_id, event_time);
CREATE INDEX idx_event_type          ON tracking_event (event_type, event_time);
CREATE INDEX idx_package_payer_time  ON package (payer_id, ship_time);
CREATE INDEX idx_package_ship_time   ON package (shipper_id, ship_time);
CREATE INDEX idx_customer_street     ON customer (street, city);
