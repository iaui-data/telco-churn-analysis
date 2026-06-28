-- ============================================
-- Telco SaaS 业务客户流失预警分析 
-- ============================================

-- ============================================
-- 分析 1：合约类型流失率对比
-- 业务目的：识别最高流失风险的合约类型
-- ============================================
SELECT
    Contract AS '合约类型',
    COUNT(customerID) AS '总客户数',
    SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) AS '流失客户数',
    CONCAT(ROUND(SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(customerID) * 100, 2), '%') AS '流失率'
FROM telco_churn
GROUP BY Contract
ORDER BY 流失率 DESC;

-- ============================================
-- 分析 2：技术支持干预效果（仅针对高危月付用户）
-- 业务目的：量化增值服务对留存率的实际影响
-- ============================================
SELECT
    TechSupport AS '技术支持状态',
    COUNT(customerID) AS '总客户数',
    CONCAT(ROUND(SUM(CASE WHEN Churn = 'Yes' THEN 1 ELSE 0 END) / COUNT(customerID) * 100, 2), '%') AS '流失率'
FROM telco_churn
WHERE Contract = 'Month-to-month'
GROUP BY TechSupport
ORDER BY 流失率 DESC;

-- ============================================
-- 分析 3：高价值高风险客户圈选 (Top 20 狙击名单)
-- 业务目的：精准定位需立即打电话挽留的头部客户
-- ============================================
WITH HighRiskUsers AS (
    SELECT 
        customerID,
        tenure AS tenure_months,
        MonthlyCharges AS monthly_charges,
        InternetService AS internet_service
    FROM telco_churn
    WHERE Contract = 'Month-to-month'
      AND TechSupport = 'No'
      AND Churn = 'No'
      AND MonthlyCharges > (SELECT AVG(MonthlyCharges) FROM telco_churn)  
)
SELECT * FROM HighRiskUsers
ORDER BY monthly_charges DESC
LIMIT 20;

-- ============================================
-- 分析 4：特征工程 - 构建流失风险分 (Risk Score) 与 价值分层 (Value Tier)
-- 业务目的：为业务侧和 BI 看板提供动态的监控度量体系
-- ============================================
SELECT
    customerID, gender, SeniorCitizen, Partner, Dependents, tenure,
    PhoneService, MultipleLines, InternetService, OnlineSecurity,
    OnlineBackup, DeviceProtection, TechSupport, StreamingTV,
    StreamingMovies, Contract, PaperlessBilling, PaymentMethod,
    MonthlyCharges, TotalCharges, Churn,
    -- 基于业务规则的风险打分模型
    (CASE WHEN Contract = 'Month-to-month' THEN 3 WHEN Contract = 'One year' THEN 1 ELSE 0 END)
    + (CASE WHEN TechSupport = 'No' THEN 2 ELSE 0 END)
    + (CASE WHEN OnlineSecurity = 'No' THEN 1 ELSE 0 END)
    + (CASE WHEN tenure < 12 THEN 2 ELSE 0 END) AS Risk_Score,
    -- 使用 NTILE 窗口函数进行高净值客户切分
    NTILE(4) OVER (ORDER BY MonthlyCharges DESC) AS Value_Tier
FROM telco_churn;