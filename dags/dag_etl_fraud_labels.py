"""
dag_etl_frauds.py
=====================
ETL pipeline: frauds.csv → stg_frauds → dim_frauds

Task flow:
    create_tables  (SQLExecuteQueryOperator) : DDL stg_frauds & dim_frauds
    extract_load   (@task Python)            : baca CSV → stg_frauds
    transform      (SQLExecuteQueryOperator) : stg_frauds → dim_frauds

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
    os.path.dirname(__file__), "..", "include", "dataset", "fraud_labels.csv"
)

DDL_STATEMENTS = """
-- =========================================================================
-- 1. STAGING TABLE (Menampung data mentah, boolean & timestamp menggunakan VARCHAR)
-- =========================================================================
CREATE TABLE IF NOT EXISTS stg_frauds (
    transaction_id   INTEGER,
    transaction_code VARCHAR(50),
    is_fraud         VARCHAR(10),  -- Menerima teks mentah 'True'/'False'
    fraud_type       VARCHAR(100),
    fraud_score      VARCHAR(20),  -- Menerima teks desimal mentah
    flagged_at       VARCHAR(30)   -- Menerima teks timestamp mentah
);

-- =========================================================================
-- 2. DIMENSION / FACT TABLE (Data bersih, tipe data sesuai + kolom transformasi)
-- =========================================================================
CREATE TABLE IF NOT EXISTS dim_frauds (
    transaction_id   INTEGER       PRIMARY KEY,
    transaction_code VARCHAR(50),
    is_fraud         BOOLEAN,      -- Ditransformasikan menjadi BOOLEAN asli
    fraud_type       VARCHAR(100),
    fraud_score      NUMERIC(5,4), -- Menggunakan desimal presisi tinggi untuk score (misal: 0.9825)
    flagged_at       TIMESTAMP,    -- Ditransformasikan menjadi TIMESTAMP asli
    -- Kolom Transformasi Tambahan (Mengikuti pola struktur referensimu)
    fraud_risk_level VARCHAR(20),  -- Contoh tambahan: Segmentasi tingkat risiko berdasarkan score
    etl_loaded_at    TIMESTAMP     DEFAULT NOW()
);
"""


# ─── DAG ──────────────────────────────────────────────────────────────────────
@dag(
    dag_id              = "dag_etl_frauds",
    description         = "ETL frauds.csv → stg_frauds → dim_frauds",
    default_args        = {
        "owner"           : "airflow",
        "retries"         : 1,
        "retry_delay"     : timedelta(minutes=5),
        "email_on_failure": False,
    },
    start_date          = datetime(2025, 1, 1),
    schedule            = None,
    catchup             = False,
    tags                = ["etl", "frauds", "dim", "postgresql"],
    template_searchpath = ["/opt/airflow/include/sql/fraud_labels"],
)
def dag_etl_frauds():

    # ── Task 1: DDL ───────────────────────────────────────────────────────────
    create_tables = SQLExecuteQueryOperator(
        task_id = "create_tables",
        conn_id = CONN_ID,
        sql     = DDL_STATEMENTS,
    )

    # ── Task 2: Extract CSV → stg_frauds ──────────────────────────────────
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
            c.execute(text("TRUNCATE TABLE stg_frauds"))
            c.commit()

        df.to_sql(
            name      = "stg_frauds",
            con       = engine,
            if_exists = "append",
            index     = False,
            method    = "multi",
            chunksize = 1000,
        )
        engine.dispose()
        return len(df)

    # ── Task 3: Transform stg_frauds → dim_frauds ──────────────────────
    transform = SQLExecuteQueryOperator(
        task_id = "transform",
        conn_id = CONN_ID,
        sql     = "01_transform.sql",
    )

    # ── Dependencies ──────────────────────────────────────────────────────────
    create_tables >> extract_load() >> transform


dag_etl_frauds()
