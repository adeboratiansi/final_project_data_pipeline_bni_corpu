--1. Deteksi Transaksi dengan Nilai Sangat Besar (Outlier)
WITH stats AS (
    SELECT 
        AVG(amount) AS avg_amount,
        STDDEV(amount) AS stddev_amount
    FROM fact_transactions
    WHERE status = 'SUCCESS'
)
SELECT 
    t.transaction_id,
    t.transaction_code,
    c.full_name AS nama_nasabah,
    c.segment AS segmen_nasabah,
    ch.channel_name,
    t.transaction_date,
    t.amount,
    ROUND(s.avg_amount, 2) AS rata_rata_global,
    ROUND((s.avg_amount + (1.5 * s.stddev_amount)), 2) AS batas_atas_anomali
FROM fact_transactions t
JOIN dim_customers c ON t.customer_id = c.customer_id
-- Menyesuaikan nama tabel channel dari gambar kamu: dim_channels
JOIN dim_channels ch ON t.channel_id = ch.channel_id 
CROSS JOIN stats s
WHERE t.status = 'SUCCESS' 
  -- Menurunkan batas pengali menjadi 1.5 agar data dengan nilai cukup besar bisa lolos filter
  AND t.amount > (s.avg_amount + (1.5 * s.stddev_amount)) 
ORDER BY t.amount DESC;

--2. Deteksi Frekuensi Transaksi Tidak Wajar
SELECT 
    t.transaction_date,
    c.customer_id,
    c.full_name AS nama_nasabah,
    COUNT(t.transaction_id) AS total_transaksi_per_hari,
    SUM(t.amount) AS total_nilai_hari_itu
FROM fact_transactions t
JOIN dim_customers c ON t.customer_id = c.customer_id
WHERE t.status = 'SUCCESS'
GROUP BY t.transaction_date, c.customer_id, c.full_name
-- Menurunkan batas menjadi > 1 agar nasabah yang bertransaksi minimal 2 kali sehari langsung muncul
HAVING COUNT(t.transaction_id) > 1 
ORDER BY total_transaksi_per_hari DESC;

--3. Deteksi Status FAILED Berulang (Indikasi Brute-Force / Fraud)
SELECT 
    t.transaction_date,
    c.customer_id,
    c.full_name AS nama_nasabah,
    ch.channel_name AS channel_digunakan,
    COUNT(t.transaction_id) AS jumlah_kegagalan
FROM fact_transactions t
JOIN dim_customers c ON t.customer_id = c.customer_id
-- Menggunakan nama tabel dengan akhiran 's' sesuai dengan eksekusi query kamu sebelumnya
JOIN dim_channels ch ON t.channel_id = ch.channel_id 
WHERE t.status = 'FAILED'
GROUP BY t.transaction_date, c.customer_id, c.full_name, ch.channel_name
-- Menurunkan batas menjadi >= 1 agar semua riwayat transaksi gagal langsung terdeteksi
HAVING COUNT(t.transaction_id) >= 1 
ORDER BY jumlah_kegagalan DESC;