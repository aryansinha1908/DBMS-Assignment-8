-- =====================================================================
--  Package Delivery Database
-- =====================================================================
USE package_delivery_db;

-- Truck 1721 crashed at this time according to the assignment
SET @crash_truck = 1721;
SET @crash_time  = '2026-11-12 14:30:00';

-- ---------------------------------------------------------------------------------------------------------------------
-- 1a. Truck 1721 is destroyed in a crash.  
--     Find all customers who had a package on that truck at the time of the crash.
-- ---------------------------------------------------------------------------------------------------------------------
SELECT DISTINCT c.customer_id, c.name, c.phone, c.email, p.tracking_no
FROM package p
JOIN customer c ON c.customer_id = p.shipper_id
JOIN tracking_event e ON e.tracking_no = p.tracking_no
WHERE e.event_time = (
        SELECT MAX(e2.event_time) FROM tracking_event e2
        WHERE e2.tracking_no = p.tracking_no AND e2.event_time <= @crash_time
    )
    AND e.location_id = @crash_truck
    AND e.event_type <> 'Delivered'
ORDER BY c.name;

-- ---------------------------------------------------------------------------------
-- 1b. Find all recipients who had a package on that truck at the time of the crash.
-- ---------------------------------------------------------------------------------
SELECT p.recipient_name, p.recipient_phone, p.dest_address, p.dest_city, p.tracking_no
FROM package p
JOIN tracking_event e ON e.tracking_no = p.tracking_no
WHERE e.event_time = (
        SELECT MAX(e2.event_time) FROM tracking_event e2
        WHERE e2.tracking_no = p.tracking_no AND e2.event_time <= @crash_time
    )
    AND e.location_id = @crash_truck
    AND e.event_type <> 'Delivered'
ORDER BY p.recipient_name;

-- ----------------------------------------------------------------------
-- 1c. Find the last successful delivery by that truck prior to the crash.
-- ----------------------------------------------------------------------
SELECT e.tracking_no, e.event_time AS delivered_at, e.signed_by,
       p.recipient_name, p.dest_address, p.dest_city
FROM tracking_event e
JOIN package p ON p.tracking_no = e.tracking_no
WHERE e.location_id = @crash_truck
    AND e.event_type = 'Delivered'
    AND e.event_time < @crash_time
ORDER BY e.event_time DESC
LIMIT 1;

-- ------------------------------------------------------------------------
-- 2. Find the customer who has shipped the most packages in the past year.
-- ------------------------------------------------------------------------
SELECT c.customer_id, c.name, COUNT(*) AS packages_shipped
FROM package p
JOIN customer c ON c.customer_id = p.shipper_id
WHERE p.ship_time >= NOW() - INTERVAL 1 YEAR
GROUP BY c.customer_id, c.name
HAVING COUNT(*) = (
    SELECT MAX(cnt) FROM (
        SELECT COUNT(*) AS cnt FROM package
        WHERE ship_time >= NOW() - INTERVAL 1 YEAR
        GROUP BY shipper_id
    ) AS t
);

-- -------------------------------------------------------------------------------
-- 3. Find the customer who has spent the most money on shipping in the past year.
-- -------------------------------------------------------------------------------
SELECT c.customer_id, c.name, SUM(p.charge) AS total_spent
FROM package p
JOIN customer c ON c.customer_id = p.payer_id
WHERE p.ship_time >= NOW() - INTERVAL 1 YEAR
GROUP BY c.customer_id, c.name
HAVING SUM(p.charge) = (
    SELECT MAX(total) FROM (
        SELECT SUM(charge) AS total FROM package
        WHERE ship_time >= NOW() - INTERVAL 1 YEAR
        GROUP BY payer_id
    ) AS t
);

-- ----------------------------------------------------------------------------------------
-- 4. Find the street with the most customers.
-- ----------------------------------------------------------------------------------------
SELECT street, city, COUNT(*) AS customers
FROM customer
GROUP BY street, city
HAVING COUNT(*) = (
    SELECT MAX(cnt) FROM (
        SELECT COUNT(*) AS cnt FROM customer
        GROUP BY street, city
    ) AS t
);

-- ---------------------------------------------------------------------------------------------------------------------------------------------
-- 5. Find those packages that were not delivered within the promised time.
-- ---------------------------------------------------------------------------------------------------------------------------------------------
SELECT p.tracking_no, s.service_name, p.ship_time, p.promised_by,
       d.event_time AS delivered_at,
       CASE WHEN d.event_time IS NULL THEN 'Not delivered yet' ELSE 'Delivered late' END AS status
FROM package p
JOIN service_type s ON s.service_id = p.service_id
LEFT JOIN tracking_event d ON d.tracking_no = p.tracking_no AND d.event_type = 'Delivered'
WHERE d.event_time > p.promised_by
   OR (d.event_time IS NULL AND p.promised_by < NOW())
ORDER BY p.promised_by;

-- ---------------------------------------------------------------------
-- 6. Generate the bill for each customer for the past month.
--    Contract customers are billed monthly for everything charged to their
--    account: their own 'Account' shipments plus 'Prepaid' shipments (such as
--    returns) that they paid for.  Credit-card shipments are paid at once.
--    The billing period is last calendar month; change these to bill another month.
-- ---------------------------------------------------------------------
SET @bill_start = DATE_FORMAT(NOW() - INTERVAL 1 MONTH, '%Y-%m-01');
SET @bill_end   = DATE_FORMAT(NOW(), '%Y-%m-01');

-- 6a. Simple bill: customer, address and amount owed
SELECT c.account_no, c.name AS customer,
       CONCAT(c.house_no, ', ', c.street, ', ', c.city, ', ', c.state, ' - ', c.pincode) AS address,
       DATE_FORMAT(@bill_start, '%M %Y') AS billing_month,
       COUNT(*)      AS shipments,
       SUM(p.charge) AS amount_owed
FROM package p
JOIN customer c ON c.customer_id = p.payer_id
WHERE p.payment_type IN ('Account', 'Prepaid')
  AND p.ship_time >= @bill_start AND p.ship_time < @bill_end
GROUP BY c.customer_id, c.account_no, c.name, c.house_no, c.street, c.city, c.state, c.pincode
ORDER BY c.name;

-- 6b. Bill listing charges by type of service (with a total for each customer)
SELECT IF(GROUPING(s.service_name) = 1, '', c.name)  AS customer,
       IF(GROUPING(s.service_name) = 1, 'TOTAL', s.service_name) AS service,
       COUNT(*)      AS shipments,
       SUM(p.charge) AS charges
FROM package p
JOIN customer c     ON c.customer_id = p.payer_id
JOIN service_type s ON s.service_id = p.service_id
WHERE p.payment_type IN ('Account', 'Prepaid')
  AND p.ship_time >= @bill_start AND p.ship_time < @bill_end
GROUP BY c.name, s.service_name WITH ROLLUP
HAVING GROUPING(c.name) = 0;

-- 6c. Itemized bill: each shipment and its charge (with a total for each customer)
SELECT IF(GROUPING(p.tracking_no) = 1, '', c.name)       AS customer,
       IF(GROUPING(p.tracking_no) = 1, 'TOTAL', p.tracking_no) AS tracking_no,
       IF(GROUPING(p.tracking_no) = 1, '', DATE_FORMAT(MAX(p.ship_time), '%d-%b-%Y')) AS shipped_on,
       IF(GROUPING(p.tracking_no) = 1, '', MAX(s.service_name))  AS service,
       IF(GROUPING(p.tracking_no) = 1, '', MAX(p.weight_kg))     AS weight_kg,
       IF(GROUPING(p.tracking_no) = 1, '', MAX(CONCAT(p.recipient_name, ', ', p.dest_city))) AS sent_to,
       IF(GROUPING(p.tracking_no) = 1, '', MAX(p.payment_type))  AS paid_by,
       SUM(p.charge) AS charge
FROM package p
JOIN customer c     ON c.customer_id = p.payer_id
JOIN service_type s ON s.service_id = p.service_id
WHERE p.payment_type IN ('Account', 'Prepaid')
  AND p.ship_time >= @bill_start AND p.ship_time < @bill_end
GROUP BY c.name, p.tracking_no WITH ROLLUP
HAVING GROUPING(c.name) = 0;

-- ------------------------------------
-- 7. Tracking history of one package
-- ------------------------------------
SELECT e.event_time, e.event_type, l.location_name, l.city, e.signed_by
FROM tracking_event e
JOIN location l ON l.location_id = e.location_id
WHERE e.tracking_no = 'PD100111'
ORDER BY e.event_time;

-- -------------------------------------------------
-- 8. Where is every undelivered package right now?
-- -------------------------------------------------
SELECT p.tracking_no, l.location_type, l.location_name, e.event_type AS last_event,
       e.event_time AS since, p.promised_by
FROM package p
JOIN tracking_event e ON e.tracking_no = p.tracking_no
JOIN location l       ON l.location_id = e.location_id
WHERE e.event_time = (
    SELECT MAX(e2.event_time) FROM tracking_event e2
    WHERE e2.tracking_no = p.tracking_no
)
AND e.event_type <> 'Delivered'
ORDER BY p.tracking_no;
