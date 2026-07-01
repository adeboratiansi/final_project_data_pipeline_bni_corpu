--branch performance
WITH branch_metrics AS (
    SELECT 
        b.region,
        b.branch_id,
        b.branch_code,
        b.branch_name,
        COUNT(t.transaction_id) AS total_volume_transaksi,
        SUM(t.amount) AS total_nilai_transaksi,
        -- Membuat peringkat berdasarkan NILAI transaksi terbesar di setiap region
        ROW_NUMBER() OVER(
            PARTITION BY b.region 
            ORDER BY SUM(t.amount) DESC
        ) AS ranking_berdasarkan_nilai,
        -- Membuat peringkat berdasarkan VOLUME transaksi terbanyak di setiap region
        ROW_NUMBER() OVER(
            PARTITION BY b.region 
            ORDER BY COUNT(t.transaction_id) DESC
        ) AS ranking_berdasarkan_volume
    FROM fact_transactions t
    JOIN dim_branches b ON t.branch_id = b.branch_id
    WHERE t.status = 'SUCCESS'
    GROUP BY b.region, b.branch_id, b.branch_code, b.branch_name
)
SELECT 
    region,
    branch_code,
    branch_name,
    total_volume_transaksi,
    total_nilai_transaksi
FROM branch_metrics
-- Menampilkan cabang nomor 1 (performa tertinggi) di masing-masing region
WHERE ranking_berdasarkan_nilai = 1 
ORDER BY region;