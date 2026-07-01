"""
dag_etl_dim_date.py
=====================
ETL pipeline: dim_date.csv → stg_dim_date → dim_dim_date

Task flow:
    create_tables  (SQLExecuteQueryOperator) : DDL stg_dim_date & dim_dim_date
    extract_load   (@task Python)            : baca CSV → stg_dim_date
    transform      (SQLExecuteQueryOperator) : stg_dim_date → dim_dim_date

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
    os.path.dirname(__file__), "..", "include", "dataset", "dim_date.csv"
)

DDL_STATEMENTS = """
-- =========================================================================
-- 1. STAGING TABLE (Menampung data mentah, tanggal & boolean menggunakan VARCHAR)
-- =========================================================================
CREATE TABLE IF NOT EXISTS stg_dates (
    date_id       INTEGER,
    full_date     VARCHAR(20),
    year          INTEGER,
    quarter       SMALLINT,
    month         SMALLINT,
    month_name    VARCHAR(20),
    week_of_year  SMALLINT,
    day_of_month  SMALLINT,
    day_of_week   SMALLINT,
    day_name      VARCHAR(20),
    is_weekend    VARCHAR(10), -- Menerima teks mentah 'True'/'False'
    is_holiday    VARCHAR(10)  -- Menerima teks mentah 'True'/'False'
);

-- =========================================================================
-- 2. DIMENSION TABLE (Data bersih, tipe data sesuai, + kolom transformasi)
-- =========================================================================
CREATE TABLE IF NOT EXISTS dim_dates (
    date_id       INTEGER      PRIMARY KEY, -- Contoh: 20230101
    full_date     DATE,                     -- Diubah menjadi tipe DATE asli
    year          INTEGER,
    quarter       SMALLINT,
    month         SMALLINT,
    month_name    VARCHAR(20),
    week_of_year  SMALLINT,
    day_of_month  SMALLINT,
    day_of_week   SMALLINT,
    day_name      VARCHAR(20),
    is_weekend    BOOLEAN,                  -- Ditransformasikan menjadi BOOLEAN asli
    is_holiday    BOOLEAN,                  -- Ditransformasikan menjadi BOOLEAN asli
    -- Kolom Transformasi Tambahan (Mengikuti pola struktur referensimu)
    etl_loaded_at TIMESTAMP    DEFAULT NOW()
);
"""


# ─── DAG ──────────────────────────────────────────────────────────────────────
@dag(
    dag_id              = "dag_etl_dim_date",
    description         = "ETL dim_date.csv → stg_dates → dim_dates",
    default_args        = {
        "owner"           : "airflow",
        "retries"         : 1,
        "retry_delay"     : timedelta(minutes=5),
        "email_on_failure": False,
    },
    start_date          = datetime(2025, 1, 1),
    schedule            = None,
    catchup             = False,
    tags                = ["etl", "dim_date", "dim", "postgresql"],
    template_searchpath = ["/opt/airflow/include/sql/dim_date"],
)
def dag_etl_dim_date():

    # ── Task 1: DDL ───────────────────────────────────────────────────────────
    create_tables = SQLExecuteQueryOperator(
        task_id = "create_tables",
        conn_id = CONN_ID,
        sql     = DDL_STATEMENTS,
    )

    # ── Task 2: Extract CSV → stg_dim_date ──────────────────────────────────
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
            c.execute(text("TRUNCATE TABLE stg_dates"))
            c.commit()

        df.to_sql(
            name      = "stg_dates",
            con       = engine,
            if_exists = "append",
            index     = False,
            method    = "multi",
            chunksize = 1000,
        )
        engine.dispose()
        return len(df)

    # ── Task 3: Transform stg_dates → dimdates ──────────────────────
    transform = SQLExecuteQueryOperator(
        task_id = "transform",
        conn_id = CONN_ID,
        sql     = "01_transform.sql",
    )

    # ── Dependencies ──────────────────────────────────────────────────────────
    create_tables >> extract_load() >> transform


dag_etl_dim_date()
