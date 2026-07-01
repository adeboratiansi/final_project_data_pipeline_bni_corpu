-- Transform: stg_branches → dim_branches
-- Cast tipe data, tambah derived columns, deduplikasi

-- 1. Kosongkan tabel dimensi sebelum melakukan load ulang (jika menggunakan pendekatan Full Load)
TRUNCATE TABLE dim_accounts;

-- 2. Masukkan data hasil transformasi dari staging ke tabel dimensi
INSERT INTO dim_accounts (
    account_id,
    account_no,
    account_type,
    product_name,
    currency,
    open_date,
    close_date,
    status,
    interest_rate,
    customer_id,
    branch_id,
    is_active,
    tenure_months
)
SELECT DISTINCT ON (account_id)
    account_id,
    account_no,
    account_type,
    product_name,
    currency,
    -- Mengubah tipe data VARCHAR dari staging menjadi DATE
    TO_DATE(open_date, 'YYYY-MM-DD') AS open_date,
    NULLIF(close_date, '')::DATE AS close_date, -- Menangani string kosong jika close_date tidak ada
    status,
    interest_rate,
    customer_id,
    branch_id,
    -- Transformasi 1: Mengubah status 'ACTIVE' menjadi TRUE, selain itu FALSE
    CASE 
        WHEN status = 'ACTIVE' THEN TRUE 
        ELSE FALSE 
    END AS is_active,
    -- Transformasi 2: Menghitung umur rekening dalam satuan bulan hingga saat ini
    EXTRACT(YEAR FROM AGE(NOW(), TO_DATE(open_date, 'YYYY-MM-DD'))) * 12 +
    EXTRACT(MONTH FROM AGE(NOW(), TO_DATE(open_date, 'YYYY-MM-DD'))) AS tenure_months
FROM stg_accounts
WHERE account_id IS NOT NULL
ORDER BY account_id;