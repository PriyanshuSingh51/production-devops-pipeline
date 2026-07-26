-- Example migration for order-service (see databases/migrations/README.md)
CREATE TABLE IF NOT EXISTS orders (
    id                    VARCHAR(36) PRIMARY KEY,
    customer_id           VARCHAR(36) NOT NULL,
    status                VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    total_amount          NUMERIC(12, 2) NOT NULL,
    payment_id            VARCHAR(36),
    cancellation_reason   TEXT,
    created_at            TIMESTAMPTZ NOT NULL DEFAULT now(),
    confirmed_at          TIMESTAMPTZ,
    cancelled_at          TIMESTAMPTZ,
    version               BIGINT NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders (customer_id);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders (status);
