--1. Channel yang Paling Banyak Digunakan Nasabah
SELECT 
    c.channel_name,
    c.channel_category,
    COUNT(t.transaction_id) AS total_volume_transaksi,
    SUM(t.amount) AS total_nilai_transaksi,
    -- Menghitung persentase volume share dari tiap channel
    ROUND(
        (COUNT(t.transaction_id) / SUM(COUNT(t.transaction_id)) OVER()) * 100, 2
    ) AS volume_share_persen
FROM fact_transactions t
JOIN dim_channels c ON t.channel_id = c.channel_id
WHERE t.status = 'SUCCESS'
GROUP BY c.channel_id, c.channel_name, c.channel_category
ORDER BY total_volume_transaksi DESC;


--2. Tren Migrasi ke Digital (Month-over-Month)
WITH monthly_digital_share AS (
    SELECT 
        d.year,
        d.month AS bulan_angka,
        d.month_name AS nama_bulan,
        -- Menghitung volume transaksi digital (t)
        COUNT(CASE WHEN c.is_digital = 't' THEN t.transaction_id END) AS volume_digital,
        -- Menghitung volume transaksi non-digital/physical (f)
        COUNT(CASE WHEN c.is_digital = 'f' THEN t.transaction_id END) AS volume_physical,
        -- Total volume keseluruhan pada bulan tersebut
        COUNT(t.transaction_id) AS total_volume_bulanan
    FROM fact_transactions t
    JOIN dim_dates d ON t.transaction_date = d.full_date
    JOIN dim_channels c ON t.channel_id = c.channel_id
    WHERE t.status = 'SUCCESS'
    GROUP BY d.year, d.month, d.month_name
)
SELECT 
    year,
    nama_bulan,
    volume_digital,
    volume_physical,
    -- Menghitung persentase adopsi digital pada bulan tersebut
    ROUND((volume_digital::NUMERIC / total_volume_bulanan) * 100, 2) AS digital_adoption_rate_persen,
    -- Menghitung persentase porsi physical
    ROUND((volume_physical::NUMERIC / total_volume_bulanan) * 100, 2) AS physical_rate_persen
FROM monthly_digital_share
ORDER BY year, bulan_angka;