--1. Nasabah Paling Aktif (Top Customers)
SELECT 
    c.customer_id,
    c.customer_code,
    c.full_name AS nama_nasabah,
    c.segment AS segmen_nasabah,
    COUNT(t.transaction_id) AS frekuensi_transaksi,
    SUM(t.amount) AS total_nilai_transaksi
FROM fact_transactions t
JOIN dim_customers c ON t.customer_id = c.customer_id
WHERE t.status = 'SUCCESS' -- Menghitung transaksi yang berhasil saja
GROUP BY c.customer_id, c.customer_code, c.full_name, c.segment
ORDER BY frekuensi_transaksi DESC, total_nilai_transaksi DESC
LIMIT 10; -- Menampilkan 10 nasabah teratas, kamu bisa mengubah angka ini

--2. Distribusi Transaksi Per Segmen (Retail / Priority / VIP)
SELECT 
    c.segment AS segmen_nasabah,
    COUNT(DISTINCT c.customer_id) AS jumlah_nasabah_unik,
    COUNT(t.transaction_id) AS total_volume_transaksi,
    SUM(t.amount) AS total_nilai_transaksi,
    -- Menghitung persentase nilai transaksi kontribusi segmen terhadap total keseluruhan
    ROUND(
        (SUM(t.amount) / SUM(SUM(t.amount)) OVER()) * 100, 2
    ) AS persentase_kontribusi_nilai_persen
FROM fact_transactions t
JOIN dim_customers c ON t.customer_id = c.customer_id
WHERE t.status = 'SUCCESS'
GROUP BY c.segment
ORDER BY total_nilai_transaksi DESC;

