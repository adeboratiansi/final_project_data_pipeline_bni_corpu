-- Transform: stg_branches → dim_branches
-- Cast tipe data, tambah derived columns, deduplikasi

-- 1. Kosongkan tabel fakta transaksi sebelum melakukan load ulang
TRUNCATE TABLE fact_transactions;

-- 2. Masukkan data hasil transformasi dari staging ke tabel fakta transaksi
INSERT INTO fact_transactions (
    transaction_id,
    transaction_code,
    account_id,
    customer_id,
    branch_id,
    channel_id,
    transaction_date,
    transaction_at,
    transaction_type,
    amount,
    balance_before,
    balance_after,
    status,
    reference_no,
    transaction_value_segment
)
SELECT DISTINCT ON (transaction_id)
    transaction_id,
    transaction_code,
    account_id,
    customer_id,
    branch_id,
    channel_id,
    -- Mengubah tipe data VARCHAR dari staging menjadi DATE asli
    TO_DATE(transaction_date, 'YYYY-MM-DD') AS transaction_date,
    -- Mengubah tipe data VARCHAR dari staging menjadi TIMESTAMP asli
    TO_TIMESTAMP(transaction_at, 'YYYY-MM-DD HH24:MI:SS') AS transaction_at,
    transaction_type,
    amount,
    balance_before,
    balance_after,
    status,
    reference_no,
    -- Transformasi Tambahan: Segmentasi nominal transaksi secara otomatis
    CASE 
        WHEN amount >= 10000000 THEN 'LARGE'      -- Di atas atau sama dengan 10 Juta
        WHEN amount >= 1000000  THEN 'MEDIUM'     -- Antara 1 Juta sampai 10 Juta
        ELSE 'SMALL'                              -- Di bawah 1 Juta
    END AS transaction_value_segment
FROM stg_transactions
WHERE transaction_id IS NOT NULL
ORDER BY transaction_id;