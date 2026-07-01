--product performance
SELECT 
    a.product_name AS nama_produk,
    a.account_type AS jenis_rekening, -- Tabungan / Giro / Deposito
    COUNT(t.transaction_id) AS total_volume_transaksi,
    SUM(t.amount) AS total_nilai_transaksi,
    -- Menghitung rata-rata saldo nasabah setelah bertransaksi menggunakan produk tersebut
    ROUND(AVG(t.balance_after), 2) AS saldo_rata_rata
FROM fact_transactions t
JOIN dim_accounts a ON t.account_id = a.account_id
WHERE t.status = 'SUCCESS' -- Hanya menghitung dari transaksi yang berhasil
GROUP BY a.product_name, a.account_type
ORDER BY total_volume_transaksi DESC, saldo_rata_rata DESC;