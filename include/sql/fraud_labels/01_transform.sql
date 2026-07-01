-- Transform: stg_branches → dim_branches
-- Cast tipe data, tambah derived columns, deduplikasi

-- 1. Kosongkan tabel dimensi frauds sebelum melakukan load ulang
TRUNCATE TABLE dim_frauds;

-- 2. Masukkan data hasil transformasi dari staging ke tabel dimensi frauds
INSERT INTO dim_frauds (
    transaction_id,
    transaction_code,
    is_fraud,
    fraud_type,
    fraud_score,
    flagged_at,
    fraud_risk_level
)
SELECT DISTINCT ON (transaction_id)
    transaction_id,
    transaction_code,
    -- Mengubah teks mentah ('True'/'False') menjadi BOOLEAN asli
    CASE 
        WHEN LOWER(is_fraud) = 'true' THEN TRUE
        ELSE FALSE
    END AS is_fraud,
    fraud_type,
    -- Mengubah tipe data VARCHAR menjadi NUMERIC
    fraud_score::NUMERIC(5,4) AS fraud_score,
    -- Mengubah tipe data VARCHAR dari staging menjadi TIMESTAMP asli
    TO_TIMESTAMP(flagged_at, 'YYYY-MM-DD HH24:MI:SS') AS flagged_at,
    -- Transformasi Tambahan: Segmentasi tingkat risiko berdasarkan fraud_score
    CASE 
        WHEN fraud_score::NUMERIC(5,4) >= 0.90 THEN 'CRITICAL'
        WHEN fraud_score::NUMERIC(5,4) >= 0.80 THEN 'HIGH'
        ELSE 'MEDIUM'
    END AS fraud_risk_level
FROM stg_frauds
WHERE transaction_id IS NOT NULL
ORDER BY transaction_id;