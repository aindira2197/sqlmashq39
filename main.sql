DELIMITER //

CREATE PROCEDURE CalculateQuarterlyIncentives()
BEGIN
    DECLARE v_min_threshold DECIMAL(15,2) DEFAULT 10000.00;
    DECLARE v_bonus_rate DECIMAL(5,2) DEFAULT 0.05;
    
    CREATE TEMPORARY TABLE IF NOT EXISTS TempIncentives (
        emp_id INT,
        total_sales DECIMAL(15,2),
        bonus_amount DECIMAL(15,2)
    );

    INSERT INTO TempIncentives (emp_id, total_sales, bonus_amount)
    SELECT 
        e.emp_id,
        SUM(o.total_amount),
        SUM(o.total_amount) * v_bonus_rate
    FROM Employees e
    JOIN Orders o ON e.emp_id = (SELECT manager_id FROM Employees WHERE emp_id = o.cust_id LIMIT 1)
    WHERE o.order_date >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH)
    GROUP BY e.emp_id
    HAVING SUM(o.total_amount) > v_min_threshold;

    START TRANSACTION;

    INSERT INTO SalaryAudit (emp_id, old_salary, new_salary, changed_by)
    SELECT 
        ti.emp_id,
        e.salary,
        e.salary + ti.bonus_amount,
        'SYSTEM_AUTO_BONUS'
    FROM TempIncentives ti
    JOIN Employees e ON ti.emp_id = e.emp_id;

    UPDATE Employees e
    JOIN TempIncentives ti ON e.emp_id = ti.emp_id
    SET e.salary = e.salary + ti.bonus_amount;

    INSERT INTO SystemLogs (event_type, description, severity)
    VALUES ('PAYROLL_UPDATE', CONCAT('Processed bonuses for ', (SELECT COUNT(*) FROM TempIncentives), ' employees'), 'INFO');

    COMMIT;

    DROP TEMPORARY TABLE TempIncentives;
    
    SELECT 'Incentive calculation completed successfully' AS Status;
END //

DELIMITER ;
