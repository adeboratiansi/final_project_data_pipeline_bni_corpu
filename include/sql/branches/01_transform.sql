-- Transform: stg_branches → dim_branches
-- Cast tipe data, tambah derived columns, deduplikasi

TRUNCATE TABLE dim_branches;

INSERT INTO dim_branches (
    branch_id, -- Gunakan SERIAL jika ingin auto-increment
    branch_code,
    branch_name,
    city,
    province,
    region,
    branch_type,
    open_date,
    is_active
)
SELECT DISTINCT ON (branch_id)
    branch_id, -- Gunakan SERIAL jika ingin auto-increment
    branch_code,
    branch_name,
    city,
    province,
    region,
    branch_type,
    open_date,
    is_active
FROM stg_branches
WHERE branch_id IS NOT NULL
ORDER BY branch_id;
