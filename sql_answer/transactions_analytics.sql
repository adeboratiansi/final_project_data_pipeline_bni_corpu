--1. Analisis Harian (Daily)
--Query ini mengelompokkan transaksi berdasarkan tanggal, menghitung volume dan nilai transaksi harian, 
--serta melihat pertumbuhan nilai transaksi dibanding hari sebelumnya.
SELECT 
    d.full_date AS tanggal,
    COUNT(t.transaction_id) AS total_volume_harian,
    SUM(t.amount) AS total_nilai_harian,
    -- Menghitung pertumbuhan nilai transaksi dibanding hari sebelumnya (%)
    ROUND(
        ((SUM(t.amount) - LAG(SUM(t.amount), 1) OVER (ORDER BY d.full_date)) 
        / LAG(SUM(t.amount), 1) OVER (ORDER BY d.full_date)) * 100, 2
    ) AS pertumbuhan_nilai_harian_persen
FROM fact_transactions t
JOIN dim_dates d ON t.transaction_date = d.full_date
WHERE t.status = 'SUCCESS' -- Umumnya analitik tren hanya menghitung transaksi yang berhasil
GROUP BY d.full_date
ORDER BY d.full_date;

--include per-channel
SELECT 
    d.full_date AS tanggal,
    c.channel_name AS nama_channel,
    COUNT(t.transaction_id) AS total_volume_harian,
    SUM(t.amount) AS total_nilai_harian,
    -- Menghitung pertumbuhan nilai dibanding hari sebelumnya untuk CHANNEL YANG SAMA
    ROUND(
        ((SUM(t.amount) - LAG(SUM(t.amount), 1) OVER (PARTITION BY c.channel_id ORDER BY d.full_date)) 
        / LAG(SUM(t.amount), 1) OVER (PARTITION BY c.channel_id ORDER BY d.full_date)) * 100, 2
    ) AS pertumbuhan_nilai_harian_persen
FROM fact_transactions t
JOIN dim_dates d ON t.transaction_date = d.full_date
JOIN dim_channels c ON t.channel_id = c.channel_id -- Menghubungkan ke tabel channel
WHERE t.status = 'SUCCESS'
GROUP BY d.full_date, c.channel_id, c.channel_name
ORDER BY d.full_date, c.channel_name;


--2. Analisis Mingguan (Weekly)
--Query ini menggunakan kolom year dan week_of_year dari dim_date untuk melihat tren per minggu.
SELECT 
    d.year,
    d.week_of_year AS minggu_ke,
    COUNT(t.transaction_id) AS total_volume_mingguan,
    SUM(t.amount) AS total_nilai_mingguan,
    -- Menghitung pertumbuhan nilai transaksi dibanding minggu sebelumnya (%)
    ROUND(
        ((SUM(t.amount) - LAG(SUM(t.amount), 1) OVER (ORDER BY d.year, d.week_of_year)) 
        / LAG(SUM(t.amount), 1) OVER (ORDER BY d.year, d.week_of_year)) * 100, 2
    ) AS pertumbuhan_nilai_mingguan_persen
FROM fact_transactions t
JOIN dim_dates d ON t.transaction_date = d.full_date
WHERE t.status = 'SUCCESS'
GROUP BY d.year, d.week_of_year
ORDER BY d.year, d.week_of_year;

--include per-channel
SELECT 
    d.year,
    d.week_of_year AS minggu_ke,
    c.channel_name AS nama_channel,
    COUNT(t.transaction_id) AS total_volume_mingguan,
    SUM(t.amount) AS total_nilai_mingguan,
    -- Menghitung pertumbuhan nilai dibanding minggu sebelumnya untuk CHANNEL YANG SAMA
    ROUND(
        ((SUM(t.amount) - LAG(SUM(t.amount), 1) OVER (PARTITION BY c.channel_id ORDER BY d.year, d.week_of_year)) 
        / LAG(SUM(t.amount), 1) OVER (PARTITION BY c.channel_id ORDER BY d.year, d.week_of_year)) * 100, 2
    ) AS pertumbuhan_nilai_mingguan_persen
FROM fact_transactions t
JOIN dim_dates d ON t.transaction_date = d.full_date
JOIN dim_channels c ON t.channel_id = c.channel_id -- Menghubungkan ke tabel channel
WHERE t.status = 'SUCCESS'
GROUP BY d.year, d.week_of_year, c.channel_id, c.channel_name
ORDER BY d.year, d.week_of_year, c.channel_name;

--3. Analisis Bulanan (Monthly)
--Query ini sangat berguna untuk melihat tren makro atau pertumbuhan dari bulan ke bulan (Month-over-Month Growth).
SELECT 
    d.year,
    d.month_name AS nama_bulan,
    COUNT(t.transaction_id) AS total_volume_bulanan,
    SUM(t.amount) AS total_nilai_bulanan,
    -- Menghitung pertumbuhan nilai transaksi dibanding bulan sebelumnya (%)
    ROUND(
        ((SUM(t.amount) - LAG(SUM(t.amount), 1) OVER (ORDER BY d.year, d.month)) 
        / LAG(SUM(t.amount), 1) OVER (ORDER BY d.year, d.month)) * 100, 2
    ) AS pertumbuhan_nilai_bulanan_persen
FROM fact_transactions t
JOIN dim_dates d ON t.transaction_date = d.full_date
WHERE t.status = 'SUCCESS'
GROUP BY d.year, d.month, d.month_name
ORDER BY d.year, d.month;

--include per-channel
SELECT 
    d.year,
    d.month_name AS nama_bulan,
    c.channel_name AS nama_channel,
    COUNT(t.transaction_id) AS total_volume_bulanan,
    SUM(t.amount) AS total_nilai_bulanan,
    -- Menghitung pertumbuhan nilai dibanding bulan sebelumnya untuk CHANNEL YANG SAMA
    ROUND(
        ((SUM(t.amount) - LAG(SUM(t.amount), 1) OVER (PARTITION BY c.channel_id ORDER BY d.year, d.month)) 
        / LAG(SUM(t.amount), 1) OVER (PARTITION BY c.channel_id ORDER BY d.year, d.month)) * 100, 2
    ) AS pertumbuhan_nilai_bulanan_persen
FROM fact_transactions t
JOIN dim_dates d ON t.transaction_date = d.full_date
JOIN dim_channels c ON t.channel_id = c.channel_id -- Menghubungkan ke tabel channel
WHERE t.status = 'SUCCESS'
GROUP BY d.year, d.month, d.month_name, c.channel_id, c.channel_name
ORDER BY d.year, d.month, c.channel_name;