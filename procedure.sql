--DROP TRIGGER TRG_GIA_THANHTOAN;

-----------------------------------------------------------------------------------------
-- Trigger giảm 10% vào ngày lễ và tăng 15% vào ngày lễ (14/2, 8/3, 20/10, 1/1)
CREATE OR REPLACE TRIGGER TRG_GIA_THANHTOAN
BEFORE INSERT OR UPDATE ON CHITIETDONHANG
FOR EACH ROW
DECLARE
    v_ngaydat DATE;
    v_ngaysinh DATE;
    v_dongiahoa NUMBER(10,2);
    v_tongdongia NUMBER(12,2);
BEGIN
    -- Lấy ngày đặt và ngày sinh
    SELECT dh.NgayDat, kh.NgaySinh
    INTO v_ngaydat, v_ngaysinh
    FROM DONHANG dh
    JOIN KHACHHANG kh ON dh.MaKH = kh.MaKH
    WHERE dh.MaDH = :NEW.MaDH;

    -- Lấy đơn giá hoa
    SELECT DonGiaHoa INTO v_dongiahoa
    FROM HOA
    WHERE MaHoa = :NEW.MaHoa;

    -- Tính tổng đơn giá gốc
    v_tongdongia := :NEW.SoLuongBan * v_dongiahoa;
    :NEW.TongDonGia := v_tongdongia;

    -- BƯỚC 1: Tăng 15% nếu là ngày lễ
    IF TO_CHAR(v_ngaydat, 'MM-DD') IN ('02-14', '03-08', '10-20', '01-01') THEN
        v_tongdongia := ROUND(v_tongdongia * 1.15, 2);
    END IF;

    -- BƯỚC 2: Giảm 10% nếu là sinh nhật
    IF v_ngaysinh IS NOT NULL
       AND TO_CHAR(v_ngaydat, 'MM-DD') = TO_CHAR(v_ngaysinh, 'MM-DD') THEN
        v_tongdongia := ROUND(v_tongdongia * 0.9, 2);
    END IF;

    -- Gán giá thành toán
    :NEW.GIATHANHTOAN := v_tongdongia;

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        :NEW.TongDonGia := 0;
        :NEW.GIATHANHTOAN := 0;
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20002, 'Lỗi tính giá thành: ' || SQLERRM);
END;
/
-----------------------------------------------------------------------------------------------------------



--DELETE FROM CHITIETDONHANG WHERE MaDH = 'DH05';
--DELETE FROM DONHANG WHERE MaDH = 'DH05';



-----------------------------------------------------------------------------------------------------------
--Trường hợp 1: Đặt hàng vào đúng ngày sinh nhật → Được giảm 10%
-- Tạo đơn hàng vào đúng ngày sinh nhật KH01 (15/01)
INSERT INTO DONHANG VALUES ('DH03', TO_DATE('2025-01-15','YYYY-MM-DD'), NULL, N'DA XAC NHAN', 'KH01', 'CN01');

-- Thêm chi tiết đơn hàng
INSERT INTO CHITIETDONHANG (MaDH, MaHoa, SoLuongBan, TongDonGia) 
VALUES ('DH03', 'H01', 5, 15000);  -- Giá gốc 15000

-- Kiểm tra kết quả
SELECT MaDH, MaHoa, SoLuongBan, TongDonGia, giathanhtoan
FROM CHITIETDONHANG 
WHERE MaDH = 'DH03';
-----------------------------------------------------------------------------------------------------------
--Trường hợp 2: Đặt hàng KHÔNG vào ngày sinh nhật → Không giảm giá
-- Tạo đơn hàng vào ngày thường (ví dụ 08/11/2025) cho KH01
INSERT INTO DONHANG VALUES ('DH04', TO_DATE('2025-11-08','YYYY-MM-DD'), NULL, N'DA XAC NHAN', 'KH01', 'CN01');

-- Thêm chi tiết đơn hàng
INSERT INTO CHITIETDONHANG (MaDH, MaHoa, SoLuongBan, TongDonGia) 
VALUES ('DH04', 'H01', 3, 15000);

-- Kiểm tra kết quả
SELECT MaDH, MaHoa, SoLuongBan, TongDonGia, giathanhtoan
FROM CHITIETDONHANG 
WHERE MaDH = 'DH04';

-----------------------------------------------------------------------------------------------------------
--Trường hợp 3: Đặt hàng vào ngày 14/02 → Tăng 15%
-- Tạo đơn hàng vào 14/02/2025
INSERT INTO DONHANG VALUES ('DH05', TO_DATE('2025-02-14','YYYY-MM-DD'), NULL, N'DA XAC NHAN', 'KH01', 'CN01');

-- Thêm chi tiết đơn hàng (giá gốc 15000)
INSERT INTO CHITIETDONHANG (MaDH, MaHoa, SoLuongBan, TongDonGia) 
VALUES ('DH05', 'H01', 5, 15000);

-- Kiểm tra kết quả
SELECT MaDH, MaHoa, SoLuongBan, TongDonGia, giathanhtoan
FROM CHITIETDONHANG 
WHERE MaDH = 'DH05';

-----------------------------------------------------------------------------------------------------------
-- Trường hợp 4. Khách hàng có sinh nhật trùng vào ngày lễ (14/2) ta có GiaThanhToan = TongDonGia + 15% - 10%
INSERT INTO KHACHHANG (MaKH, HoTen, DiaChi, SDT_KH, NgaySinh)
VALUES ('KH07', 'Nguyễn Văn Tèo', '123 Hai Bà Trưng', '0909111222', TO_DATE('1990-02-14', 'YYYY-MM-DD'));

INSERT INTO DONHANG VALUES ('DH07', TO_DATE('2025-02-14','YYYY-MM-DD'), NULL, N'DA XAC NHAN', 'KH07', 'CN01');
INSERT INTO CHITIETDONHANG (MaDH, MaHoa, SoLuongBan, TongDonGia)
VALUES ('DH07', 'H01', 2, 15000);

SELECT MaDH, MaHoa, SoLuongBan, TongDonGia, giathanhtoan
FROM CHITIETDONHANG 
WHERE MaDH = 'DH07';

-----------------------------------------------------------------------------------------------------------
-- Tổng kết kiểm tra
-- Xem tất cả chi tiết đơn hàng để so sánh
SELECT 
    dh.MaDH,
    TO_CHAR(dh.NgayDat, 'YYYY-MM-DD') AS NgayDat,
    kh.HoTen,
    TO_CHAR(kh.NgaySinh, 'MM-DD') AS NgaySinh,
    ct.MaHoa,
    h.TenHoa,
    h.DonGiaHoa,
    ct.SoLuongBan,
    ct.TongDonGia,
    ct.GIATHANHTOAN,
    CASE 
        WHEN TO_CHAR(dh.NgayDat, 'MM-DD') IN ('02-14','03-08','10-20','01-01') THEN 'Tăng 15%'
        WHEN TO_CHAR(dh.NgayDat, 'MM-DD') = TO_CHAR(kh.NgaySinh, 'MM-DD') THEN 'Giảm 10%'
        ELSE 'Bình thường'
    END AS KhuyenMai
FROM DONHANG dh
JOIN KHACHHANG kh ON dh.MaKH = kh.MaKH
JOIN CHITIETDONHANG ct ON dh.MaDH = ct.MaDH
JOIN HOA h ON ct.MaHoa = h.MaHoa
WHERE dh.MaDH IN ('DH03', 'DH04', 'DH05', 'DH07')
ORDER BY dh.MaDH;









-----------------------------------------------------------------------------------------------------------

drop procedure PROC_THONGKE_DOANHTHU_CHINHANH;
-- Procedure
-- Xem thống kê doanh thu đơn hàng theo chi nhánh và theo thời gian
CREATE OR REPLACE PROCEDURE PROC_THONGKE_DOANHTHU_CHINHANH (
    p_tu_ngay   IN DATE,
    p_den_ngay  IN DATE
)
IS
    -- Biến để lưu tổng hợp
    v_tong_dh       NUMBER;
    v_tong_doanhthu NUMBER(15,2);
BEGIN
    -- Kiểm tra đầu vào
    IF p_tu_ngay IS NULL OR p_den_ngay IS NULL THEN
        RAISE_APPLICATION_ERROR(-20001, 'Cả hai tham số ngày đều phải được cung cấp.');
    END IF;

    IF p_den_ngay < p_tu_ngay THEN
        RAISE_APPLICATION_ERROR(-20002, 'Ngày kết thúc phải lớn hơn hoặc bằng ngày bắt đầu.');
    END IF;

    -- In tiêu đề
    DBMS_OUTPUT.PUT_LINE('====================================================================');
    DBMS_OUTPUT.PUT_LINE('THỐNG KÊ DOANH THU THEO CHI NHÁNH');
    DBMS_OUTPUT.PUT_LINE('Từ ngày: ' || TO_CHAR(p_tu_ngay, 'DD/MM/YYYY') || 
                         ' đến ngày: ' || TO_CHAR(p_den_ngay, 'DD/MM/YYYY'));
    DBMS_OUTPUT.PUT_LINE('====================================================================');
    DBMS_OUTPUT.PUT_LINE(RPAD('Mã CN', 10) || 
                         RPAD('Tên Chi Nhánh', 30) || 
                         RPAD('Số ĐH', 10) || 
                         RPAD('Doanh Thu', 15));
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------------------------');

    -- Duyệt từng chi nhánh và tính doanh thu
    FOR rec IN (
        SELECT 
            cn.MaChiNhanh,
            cn.TenChiNhanh,
            COUNT(dh.MaDH) AS SoDonHang,
            NVL(SUM(ct.GIATHANHTOAN), 0) AS DoanhThu
        FROM CHINHANH cn
        LEFT JOIN DONHANG dh ON cn.MaChiNhanh = dh.MaChiNhanh
                            AND dh.NgayDat BETWEEN p_tu_ngay AND p_den_ngay
                            AND dh.TrangThai = 'HOAN THANH'  -- Chỉ tính đơn hoàn thành
        LEFT JOIN CHITIETDONHANG ct ON dh.MaDH = ct.MaDH
        GROUP BY cn.MaChiNhanh, cn.TenChiNhanh
        ORDER BY DoanhThu DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE(
            RPAD(NVL(rec.MaChiNhanh, ''), 10) ||
            RPAD(NVL(rec.TenChiNhanh, ''), 30) ||
            RPAD(rec.SoDonHang, 10) ||
            TO_CHAR(rec.DoanhThu, 'FM999,999,990.00')
        );

        -- Cộng dồn tổng
        v_tong_dh := v_tong_dh + rec.SoDonHang;
        v_tong_doanhthu := v_tong_doanhthu + rec.DoanhThu;
    END LOOP;

    -- In dòng tổng kết
    DBMS_OUTPUT.PUT_LINE('--------------------------------------------------------------------');
    DBMS_OUTPUT.PUT_LINE(
        RPAD('TỔNG CỘNG', 40) ||
        RPAD(v_tong_dh, 10) ||
        TO_CHAR(v_tong_doanhthu, 'FM999,999,990.00')
    );
    DBMS_OUTPUT.PUT_LINE('====================================================================');

EXCEPTION
    WHEN OTHERS THEN
        RAISE_APPLICATION_ERROR(-20003, 'Lỗi trong PROC_THONGKE_DOANHTHU_CHINHANH: ' || SQLERRM);
END;
/
-----------------------------------------------------------------------------------------------------------
-- Bật output để xem kết quả
SET SERVEROUTPUT ON;

-- Ví dụ 1: Doanh thu tháng 11/2025 (từ 01/11 đến 08/11)
EXEC PROC_THONGKE_DOANHTHU_CHINHANH(TO_DATE('2025-11-01','YYYY-MM-DD'), TO_DATE('2025-11-08','YYYY-MM-DD'));

-- Ví dụ 2: Doanh thu toàn bộ tháng 2/2025 (có ngày lễ 14/2)
EXEC PROC_THONGKE_DOANHTHU_CHINHANH(TO_DATE('2025-02-01','YYYY-MM-DD'), TO_DATE('2025-02-28','YYYY-MM-DD'));

-- Ví dụ 3: Doanh thu năm 2025
EXEC PROC_THONGKE_DOANHTHU_CHINHANH(TO_DATE('2025-01-01','YYYY-MM-DD'), TO_DATE('2025-12-31','YYYY-MM-DD'));

select * from Donhang;
-----------------------------------------------------------------------------------------------------------


-- Create Table dể ghi Log
CREATE TABLE LOG_KHACHHANG (
    LogID         NUMBER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    MaKH          CHAR(10),
    HanhDong      VARCHAR2(50),
    ThoiGian      DATE        DEFAULT SYSDATE,
    NguoiThucHien VARCHAR2(30) DEFAULT USER
);

-----------------------------------------------------------------------------------------------------------
-- drop procedure ThemKhachHang;
-- Procedure Thêm một khách hàng mới vào hệ thống cửa hàng hoa một cách an toàn, có kiểm tra, có ghi log, và tự động lưu dữ liệu.
CREATE OR REPLACE PROCEDURE ThemKhachHang (
    p_MaKH     IN CHAR,
    p_HoTen    IN NVARCHAR2,
    p_DiaChi   IN NVARCHAR2,
    p_SDT      IN VARCHAR2,
    p_NgaySinh IN DATE
) AS
    v_count NUMBER;
BEGIN
    -- 1. Kiểm tra mã KH trùng
    SELECT COUNT(*) INTO v_count FROM KHACHHANG WHERE MaKH = p_MaKH;
    IF v_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Mã khách hàng đã tồn tại!');
    END IF;

    -- 2. Kiểm tra SDT hợp lệ
    IF NOT REGEXP_LIKE(p_SDT, '^0[0-9]{9}$') THEN
        RAISE_APPLICATION_ERROR(-20002,
            'Số điện thoại phải có 10 số, bắt đầu bằng 0!');
    END IF;

    -- 3. Thêm dữ liệu
    INSERT INTO KHACHHANG (MaKH, HoTen, DiaChi, SDT_KH, NgaySinh)
    VALUES (p_MaKH, p_HoTen, p_DiaChi, p_SDT, p_NgaySinh);

    -- 4. Ghi log
    INSERT INTO LOG_KHACHHANG (MaKH, HanhDong)
    VALUES (p_MaKH, 'THÊM MỚI');

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Thêm khách hàng thành công: ' || p_MaKH);
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20003, 'Lỗi: ' || SQLERRM);
END;
/
-----------------------------------------------------------------------------------------------------------
-- Thêm Khách Hàng
SET SERVEROUTPUT ON;

BEGIN
    ThemKhachHang(
        p_MaKH     => 'KH09',
        p_HoTen    => N'Đỗ Tài',
        p_DiaChi   => N'12 Nguyễn Văn Cừ, Quận 5, TP.HCM',
        p_SDT      => '0909456123',
        p_NgaySinh => TO_DATE('1997-02-18', 'YYYY-MM-DD')
    );
END;
/
select * from LOG_KHACHHANG;
select * from Khachhang;
-----------------------------------------------------------------------------------------------------------
-- Xóa khách hàng chỉ khi chưa có đơn hàng
CREATE OR REPLACE PROCEDURE XoaKhachHang (
    p_MaKH IN CHAR
) AS
    v_count_dh NUMBER;
BEGIN
    -- Kiểm tra khách hàng có đơn hàng chưa
    SELECT COUNT(*) INTO v_count_dh
    FROM DONHANG
    WHERE MaKH = p_MaKH;

    IF v_count_dh > 0 THEN
        RAISE_APPLICATION_ERROR(-20004, 'Không thể xóa! Khách hàng có đơn hàng.');
    END IF;

    -- Xóa khách hàng
    DELETE FROM KHACHHANG WHERE MaKH = p_MaKH;

    IF SQL%ROWCOUNT = 0 THEN
        RAISE_APPLICATION_ERROR(-20005, 'Không tìm thấy khách hàng: ' || p_MaKH);
    END IF;

    -- Ghi log xóa
    INSERT INTO LOG_KHACHHANG (MaKH, HanhDong)
    VALUES (p_MaKH, 'XÓA');

    COMMIT;

    DBMS_OUTPUT.PUT_LINE('Xóa khách hàng thành công: ' || p_MaKH);
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE_APPLICATION_ERROR(-20006, 'Lỗi xóa: ' || SQLERRM);
END;
/
-----------------------------------------------------------------------------------------------------------\
-- Xóa Khách hàng chưa có đơn hàng
SET SERVEROUTPUT ON;

BEGIN
    XoaKhachHang(p_MaKH => 'KH08');
END;
/
-----------------------------------------------------------------------------------------------------------
-- Xóa khách hàng đã có đơn hàng
SET SERVEROUTPUT ON;

BEGIN
    XoaKhachHang(p_MaKH => 'KH01');
END;
/