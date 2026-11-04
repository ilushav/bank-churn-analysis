-- Анализ оттока клиентов банка: SQL-запросы
-- Запросы выполняются в DuckDB по DataFrame df (data/Customer-Churn-Records.csv
-- без столбцов RowNumber, CustomerId, Surname), см. notebooks/analysis.ipynb.

-- Гипотеза 1: клиенты с несколькими продуктами уходят реже
SELECT NumOfProducts AS products, COUNT(*) AS clients, ROUND(AVG(Exited) * 100, 2) AS churn_percent
FROM df
GROUP BY products
ORDER BY products;

-- Гипотеза 2: неактивные клиенты уходят чаще
SELECT IsActiveMember AS active, COUNT(*) AS clients, ROUND(AVG(Exited) * 100, 2) AS churn_percent
FROM df
GROUP BY active
ORDER BY active;

-- Гипотеза 3: чем выше статус карты, тем ниже отток
SELECT "Card Type" AS card_type, COUNT(*) AS clients, ROUND(AVG(Exited) * 100, 2) AS churn_percent
FROM df
GROUP BY card_type
ORDER BY CASE WHEN card_type = 'SILVER' THEN 1
              WHEN card_type = 'GOLD' THEN 2
              WHEN card_type = 'PLATINUM' THEN 3
              WHEN card_type = 'DIAMOND' THEN 4 END;

-- Гипотеза 4: отток различается у мужчин и женщин
SELECT Gender AS gender, COUNT(*) AS clients, ROUND(AVG(Exited) * 100, 2) AS churn_percent
FROM df
GROUP BY gender
ORDER BY churn_percent;

-- Гипотеза 5: клиенты младше 37 лет уходят чаще
SELECT COUNT(*) AS clients, MIN(Age) AS min_age, MAX(Age) AS max_age, ROUND(AVG(Exited) * 100, 2) AS churn_percent
FROM df
WHERE Age < 37
UNION ALL
SELECT COUNT(*) AS clients, MIN(Age) AS min_age, MAX(Age) AS max_age, ROUND(AVG(Exited) * 100, 2) AS churn_percent
FROM df
WHERE Age >= 37
ORDER BY min_age;

-- Гипотеза 5: отток по возрастным группам
SELECT CASE WHEN Age <= 27 THEN '18 - 27'
            WHEN Age <= 37 THEN '28 - 37'
            WHEN Age <= 47 THEN '38 - 47'
            WHEN Age <= 57 THEN '48 - 57'
            ELSE '58+' END AS age_group,
       COUNT(*) AS clients, ROUND(AVG(Exited) * 100, 2) AS churn_percent
FROM df
GROUP BY age_group
ORDER BY age_group;

-- Гипотеза 6: клиенты с оценкой удовлетворенности 1-2 уходят чаще
SELECT CASE WHEN "Satisfaction Score" BETWEEN 1 AND 2 THEN '1 - 2' ELSE '3 - 5' END AS satisfaction, COUNT(*) AS clients, ROUND(AVG(Exited) * 100, 2) AS churn_percent
FROM df
GROUP BY satisfaction
ORDER BY satisfaction;

-- Гипотеза 6: отток по каждой оценке удовлетворенности
SELECT "Satisfaction Score" AS satisfaction, COUNT(*) AS clients, ROUND(AVG(Exited) * 100, 2) AS churn_percent
FROM df
GROUP BY satisfaction
ORDER BY satisfaction;

-- Спящие счета: активность и отток клиентов с нулевым и ненулевым балансом
SELECT CASE WHEN Balance = 0 THEN 'zero_balance' ELSE 'non_zero_balance' END AS balance_group, COUNT(*) AS clients, ROUND(AVG(IsActiveMember) * 100, 2) AS active_percent, ROUND(AVG(Exited) * 100, 2) AS churn_percent
FROM df
GROUP BY balance_group;

-- Сегментирование: группы риска по возрасту, количеству продуктов и активности
WITH clients_with_age AS (
    SELECT CASE WHEN Age <= 47 THEN 'under_48' ELSE '48+' END AS age_group, NumOfProducts AS products, IsActiveMember AS active, COUNT(*) AS clients, CAST(SUM(Exited) AS INTEGER) AS churned, ROUND(AVG(Exited) * 100, 2) AS churn_percent
    FROM df
    GROUP BY age_group, products, active
)

SELECT CASE WHEN clients < 100 THEN 'small_groups' WHEN churn_percent >= 50 THEN 'high_risk' WHEN churn_percent >= 25 THEN 'medium_risk' ELSE 'low_risk' END AS risk_group, *
FROM clients_with_age
ORDER BY CASE WHEN risk_group = 'high_risk' THEN 1 WHEN risk_group = 'medium_risk' THEN 2 WHEN risk_group = 'low_risk' THEN 3 WHEN risk_group = 'small_groups' THEN 4 END, churn_percent DESC;

-- Сегментирование: доля клиентов и доля ушедших клиентов в каждой группе риска
WITH clients_with_age AS (
    SELECT CASE WHEN Age <= 47 THEN 'under_48' ELSE '48+' END AS age_group, NumOfProducts AS products, IsActiveMember AS active, COUNT(*) AS clients, CAST(SUM(Exited) AS INTEGER) AS churned, ROUND(AVG(Exited) * 100, 2) AS churn_percent
    FROM df
    GROUP BY age_group, products, active
),

clients_by_risk_group AS (
    SELECT CASE WHEN clients < 100 THEN 'small_groups' WHEN churn_percent >= 50 THEN 'high_risk' WHEN churn_percent >= 25 THEN 'medium_risk' ELSE 'low_risk' END AS risk_group, *
    FROM clients_with_age
)

SELECT risk_group, CAST(SUM(clients) AS INTEGER) AS clients, ROUND(SUM(clients) * 100.0 / SUM(SUM(clients)) OVER (), 2) AS clients_share_percent, CAST(SUM(churned) AS INTEGER) AS churned, ROUND(SUM(churned) * 100.0 / SUM(SUM(churned)) OVER (), 2) AS churned_share_percent, ROUND(SUM(churned) * 100.0 / SUM(clients), 2) AS churn_percent
FROM clients_by_risk_group
GROUP BY risk_group
ORDER BY CASE WHEN risk_group = 'high_risk' THEN 1 WHEN risk_group = 'medium_risk' THEN 2 WHEN risk_group = 'low_risk' THEN 3 WHEN risk_group = 'small_groups' THEN 4 END;
