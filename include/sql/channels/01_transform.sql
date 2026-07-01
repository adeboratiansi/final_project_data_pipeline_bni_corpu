-- Transform: stg_branches → dim_branches
-- Cast tipe data, tambah derived columns, deduplikasi

-- 1. Kosongkan tabel dimensi channels sebelum melakukan load ulang
TRUNCATE TABLE dim_channels;

-- 2. Masukkan data hasil transformasi dari staging ke tabel dimensi channels
INSERT INTO dim_channels (
    channel_id,
    channel_code,
    channel_name,
    channel_category,
    is_digital,
    description
)
SELECT DISTINCT ON (channel_id)
    channel_id,
    channel_code,
    channel_name,
    channel_category,
    -- Mengubah tipe data VARCHAR mentah ('True'/'False') menjadi BOOLEAN asli
    CASE 
        WHEN LOWER(is_digital) = 'true' THEN TRUE
        ELSE FALSE
    END AS is_digital,
    description
FROM stg_channels
WHERE channel_id IS NOT NULL
ORDER BY channel_id;