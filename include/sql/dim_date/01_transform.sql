-- Transform: stg_branches → dim_branches
-- Cast tipe data, tambah derived columns, deduplikasi

-- 1. Kosongkan tabel dimensi dates sebelum melakukan load ulang
TRUNCATE TABLE dim_dates;

-- 2. Masukkan data hasil transformasi dari staging ke tabel dimensi dates
INSERT INTO dim_dates (
    date_id,
    full_date,
    year,
    quarter,
    month,
    month_name,
    week_of_year,
    day_of_month,
    day_of_week,
    day_name,
    is_weekend,
    is_holiday
)
SELECT DISTINCT ON (date_id)
    date_id,
    -- Mengubah tipe data VARCHAR dari staging menjadi DATE asli
    TO_DATE(full_date, 'YYYY-MM-DD') AS full_date,
    year,
    quarter,
    month,
    month_name,
    week_of_year,
    day_of_month,
    day_of_week,
    day_name,
    -- Mengubah teks mentah ('True'/'False') menjadi BOOLEAN asli untuk is_weekend
    CASE 
        WHEN LOWER(is_weekend) = 'true' THEN TRUE
        ELSE FALSE
    END AS is_weekend,
    -- Mengubah teks mentah ('True'/'False') menjadi BOOLEAN asli untuk is_holiday
    CASE 
        WHEN LOWER(is_holiday) = 'true' THEN TRUE
        ELSE FALSE
    END AS is_holiday
FROM stg_dates
WHERE date_id IS NOT NULL
ORDER BY date_id;