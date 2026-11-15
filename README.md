# Package Delivery Database

**Student:** Aryan Sinha **Roll no.:** 2025UGCS070

A MySQL database for a package delivery company, like FedEx or DHL. It covers the two areas
according to the the assignment:
* **Package handling:** customers, service types, packages, customs declarations, and the
  tracking history of every package across warehouses, trucks and planes.
* **Billing:** monthly account billing, credit-card payments, and prepaid returns.

## Files

| File | Contents |
|---|---|
| `README.md` | This file |
| `ER_Diagram.png` | E-R diagram |
| `Relational_Model.md` / `Relational_Model.png` | Tables, keys, foreign keys, normalization, constraints, indexes |
| `schema.sql` | Creates the database `package_delivery_db`: 6 tables with keys, constraints and indexes |
| `data.sql` | Small sample data set |
| `queries.sql` | The client's queries (1–6) plus 2 tracking queries |

## How to run (MySQL 8.0.16 or later)

From a terminal in this folder:

```bash
mysql -u root -p < schema.sql
mysql -u root -p < data.sql
mysql -u root -p --table < queries.sql
```

**In MySQL Workbench:** open and run `schema.sql`, then `data.sql`, then `queries.sql`.

## E-R model


| Entity | Key | Notes |
|---|---|---|
| customer | customer_id | **Contract** customers have an account number and are billed monthly. **Occasional** customers pay by credit card. |
| service_type | service_id | Package type (envelope / small box / large box), speed (overnight / second day / ground / international), weight limit and rates. |
| package | tracking_no | Weight, hazardous-material class, ship time, promised delivery time, payment, charge, recipient and destination. |
| location | location_id | A warehouse, truck or plane. Trucks use their number as the id, e.g. 1721. |
| customs_declaration | (weak, owner package) | Contents and declared value of an international package. |
| tracking_event | (weak, owner package; discriminator event_time) | Every scan of a package: when, what happened, where, and who signed. |

| Relationship | Between | Cardinality |
|---|---|---|
| ships | customer – package | 1 : N. Each package has one sender. |
| pays_for | customer – package | 1 : N. Each package has one payer, usually the sender. For a prepaid return, the shop pays. |
| uses | service_type – package | 1 : N |
| declared_in | package – customs_declaration | 1 : 0..1 (identifying) |
| has_event | package – tracking_event | 1 : N (identifying) |
| scanned_at | location – tracking_event | 1 : N |

**How tracking works:** after each event, the package is at that event's location (a
warehouse, truck or plane) until its next event. A 'Delivered' event ends its journey. To find
where a package was at any past time, look up its latest event at or before that time. The
same lookup gives what was on a truck, or in a warehouse, at a given time.

**Assumptions:**
1. Charge = base rate + rate per kg × weight, plus ₹500 for hazardous material. It is stored
   when the package is shipped.
2. A package is late if it was delivered after `promised_by`, or if it is still undelivered
   after that time.
3. The recipient does not have to be a customer, so the recipient's details are stored with
   the package.
4. Bills cover Contract customers: everything charged to their account last month, including
   prepaid returns they paid for. Credit-card shipments are paid at the time of shipping, so
   they don't appear on a bill.
5. Truck routing and staff are left out, as the assignment says.

## Queries and results

The sample data reflects the company on **15th Nov 2026**. Truck `1721` crashed on 12th Nov 2026
at 14:30.

| # | Question | Result on the sample data |
|---|---|---|
| 1a | Customers with a package on truck 1721 at the crash | ElectroWorld Online, Kumar Exports, StyleKart Fashion, Vikram Joshi |
| 1b | Recipients with a package on truck 1721 at the crash | Delhi Crafts Bazaar, Kavita Desai, Meera Iyer, Rohan Gupta |
| 1c | Last successful delivery by truck 1721 before the crash | PD100120, delivered 12:40 to Sanjay Verma |
| 2 | Customer who shipped the most packages in the past year | Sharma Legal Associates (5 packages) |
| 3 | Customer who spent the most on shipping in the past year | Kumar Exports (₹12,502) |
| 4 | Street with the most customers | Linking Road, Mumbai (3 customers) |
| 5 | Packages not delivered within the promised time | 8: four delivered late, four lost on truck 1721 |
| 6a | Simple bill: customer, address, amount owed | 6 bills for October 2026 |
| 6b | Bill by type of service | the same 6 bills, with a TOTAL line per customer |
| 6c | Itemized bill, one line per shipment | the same 6 bills, with a TOTAL line per customer |
| 7 | Tracking history of package PD100120 | 5 events |
| 8 | Where every undelivered package is now | 7 packages |


## Sample data

| Table | Rows |
|---|---:|
| customer | 14 (6 contract, 8 occasional) |
| service_type | 6 |
| location | 14 (4 warehouses, 4 planes, 6 trucks) |
| package | 32 (3 international, 2 hazardous, 2 prepaid returns) |
| customs_declaration | 3 |
| tracking_event | 166 |

The company, customers and addresses are fictional. E-mail addresses use reserved example
domains.
