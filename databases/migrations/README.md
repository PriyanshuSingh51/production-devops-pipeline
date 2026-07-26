# Database Migrations

Each service manages its own schema migrations independently (database-per-service).
We use **Flyway** conventions: `V<version>__<description>.sql`, applied automatically
on service startup via `spring.flyway.enabled=true`.

## Example: Order Service

```
order-service/src/main/resources/db/migration/
├── V1__create_orders_table.sql
├── V2__create_order_items_table.sql
└── V3__add_optimistic_locking_version_column.sql
```

## Running migrations manually

```bash
cd order-service
mvn flyway:migrate -Dflyway.url=jdbc:postgresql://<host>:5432/orderdb \
                    -Dflyway.user=$DB_USER -Dflyway.password=$DB_PASSWORD
```

## Rules

- Never edit a migration that has already shipped to any environment — add a new one.
- Every migration must be backward-compatible with the currently-deployed service
  version to support zero-downtime rolling deploys (expand/contract pattern).
- Destructive changes (dropping a column/table) ship in a separate migration at least
  one release after the code stops using it.
