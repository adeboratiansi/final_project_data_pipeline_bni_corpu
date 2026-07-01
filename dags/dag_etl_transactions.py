"""
dag_etl_transactions.py
=====================
ETL pipeline: transactions.csv → stg_transactions → dim_transactions

Task flow:
    create_tables  (SQLExecuteQueryOperator) : DDL stg_transactions & dim_transactions
    extract_load   (@task Python)            : baca CSV → stg_transactions
    transform      (SQLExecuteQueryOperator) : stg_transactions → dim_transactions

Airflow Connection:
    conn_id = "postgres_etl"  (tipe: Postgres)
    Host: postgres-etl | Port: 5432 | DB: etl_db
"""

import os
from datetime import datetime, timedelta

import pandas as pd
from sqlalchemy import create_engine, text

from airflow.decorators import dag, task
from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator

# ─── Konstanta ────────────────────────────────────────────────────────────────
CONN_ID     = "postgres_etl_tiansi" # <-- ganti dengan koneksi database yang sudah dibuat di airflow
SOURCE_FILE = os.path.join(
    os.path.dirname(__file__), "..", "include", "dataset", "transactions.csv"
)

DDL_STATEMENTS = """
-- =========================================================================
-- 1. STAGING TABLE (Menampung data mentah, tanggal/waktu menggunakan VARCHAR)
-- =========================================================================
CREATE TABLE IF NOT EXISTS stg_transactions (
    transaction_id   INTEGER,
    transaction_code VARCHAR(50),
    account_id       INTEGER,
    customer_id      INTEGER,
    branch_id        INTEGER,
    channel_id       INTEGER,
    transaction_date VARCHAR(20),  -- Menerima teks mentah 'YYYY-MM-DD'
    transaction_at   VARCHAR(30),  -- Menerima teks mentah 'YYYY-MM-DD HH:MI:SS'
    transaction_type VARCHAR(50),
    amount           NUMERIC(18,2),
    balance_before   NUMERIC(18,2),
    balance_after    NUMERIC(18,2),
    status           VARCHAR(20),
    reference_no     VARCHAR(100)
);

-- =========================================================================
-- 2. FACT TABLE (Data bersih, tipe data sesuai, + kolom transformasi)
-- =========================================================================
CREATE TABLE IF NOT EXISTS fact_transactions (
    transaction_id   INTEGER       PRIMARY KEY,
    transaction_code VARCHAR(50),
    account_id       INTEGER,
    customer_id      INTEGER,
    branch_id        INTEGER,
    channel_id       INTEGER,
    transaction_date DATE,         -- Ditransformasikan menjadi DATE asli
    transaction_at   TIMESTAMP,    -- Ditransformasikan menjadi TIMESTAMP asli
    transaction_type VARCHAR(50),
    amount           NUMERIC(18,2),
    balance_before   NUMERIC(18,2),
    balance_after    NUMERIC(18,2),
    status           VARCHAR(20),
    reference_no     VARCHAR(100),
    -- Kolom Transformasi Tambahan (Mengikuti pola struktur referensimu)
    transaction_value_segment VARCHAR(20), -- Contoh segmentasi nilai transaksi (Large/Medium/Small)
    etl_loaded_at    TIMESTAMP     DEFAULT NOW()
);
"""


# ─── DAG ──────────────────────────────────────────────────────────────────────
@dag(
    dag_id              = "dag_etl_transactions",
    description         = "ETL transactions.csv → stg_transactions → dim_transactions",
    default_args        = {
        "owner"           : "airflow",
        "retries"         : 1,
        "retry_delay"     : timedelta(minutes=5),
        "email_on_failure": False,
    },
    start_date          = datetime(2025, 1, 1),
    schedule            = None,
    catchup             = False,
    tags                = ["etl", "transactions", "dim", "postgresql"],
    template_searchpath = ["/opt/airflow/include/sql/transactions"],
)
def dag_etl_transactions():

    # ── Task 1: DDL ───────────────────────────────────────────────────────────
    create_tables = SQLExecuteQueryOperator(
        task_id = "create_tables",
        conn_id = CONN_ID,
        sql     = DDL_STATEMENTS,
    )

    # ── Task 2: Extract CSV → stg_transactions ──────────────────────────────────
    @task()
    def extract_load():
        from airflow.hooks.base import BaseHook

        conn     = BaseHook.get_connection(CONN_ID)
        conn_str = (
            f"postgresql+psycopg2://{conn.login}:{conn.password}"
            f"@{conn.host}:{conn.port}/{conn.schema}"
        )
        engine = create_engine(conn_str)

        df = pd.read_csv(SOURCE_FILE)

        with engine.connect() as c:
            c.execute(text("TRUNCATE TABLE stg_transactions"))
            c.commit()

        df.to_sql(
            name      = "stg_transactions",
            con       = engine,
            if_exists = "append",
            index     = False,
            method    = "multi",
            chunksize = 1000,
        )
        engine.dispose()
        return len(df)

    # ── Task 3: Transform stg_transactions → dim_transactions ──────────────────────
    transform = SQLExecuteQueryOperator(
        task_id = "transform",
        conn_id = CONN_ID,
        sql     = "01_transform.sql",
    )

    # ── Dependencies ──────────────────────────────────────────────────────────
    create_tables >> extract_load() >> transform


dag_etl_transactions()
