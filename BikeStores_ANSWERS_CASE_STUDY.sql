-- Jenson USA MileStone

-- 1. Find the total number of products sold by each store along with the store name.

SELECT 
    s.store_name 'Store name', sum(oi.quantity) 'Number of products'
FROM
    orders o
        INNER JOIN
    order_items oi ON o.order_id = oi.order_id
        INNER JOIN
    stores s ON s.store_id = o.store_id
GROUP BY s.store_name;

-- 2. Calculate the cumulative sum of quantities sold for each product over time.
select p.product_name 'Product_name',o.order_date,oi.quantity,
sum(oi.quantity) 
over(
partition by p.product_name
order by o.order_date 
rows between unbounded preceding and current row
) as 'Cummulative total'
from orders o inner join order_items oi
on o.order_id = oi.order_id
inner join products p
on p.product_id = oi.product_id;


SELECT 
    p.product_name AS 'Product_name',
    o.order_date,
    oi.quantity,
    SUM(oi.quantity) OVER (
        PARTITION BY p.product_name
        ORDER BY o.order_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS 'Cumulative_total'
FROM 
    orders o
INNER JOIN 
    order_items oi ON o.order_id = oi.order_id
INNER JOIN 
    products p ON p.product_id = oi.product_id;


-- 3. Find the product with the highest total sales (quantity * price) for each category.

with totalSalesCategoryWise as (
SELECT 
    c.category_name,
    p.product_name 'product_name',
    SUM(oi.quantity) 'total_quantity',
    oi.list_price 'price',
    ROUND((SUM(oi.quantity) * oi.list_price), 2) 'total_sales'
FROM
    categories c
        INNER JOIN
    products p ON c.category_id = p.category_id
        INNER JOIN
    order_items oi ON oi.product_id = p.product_id
GROUP BY c.category_name , p.product_name , oi.list_price
),

ranking_total_sales as (
select category_name
,product_name , total_sales
,dense_rank() over(partition by category_name order by total_sales desc) 'rankTotalSales'
from totalSalesCategoryWise
)

SELECT 
    category_name 'Category Name',
    product_name 'Product Name',
    total_sales 'Total Sales'
FROM
    ranking_total_sales
WHERE
    rankTotalSales = 1;

-- 4. Find the customer who spent the most money on orders.

with customerHighest as(
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    ROUND(SUM(oi.quantity * oi.list_price - (1 - (oi.discount / 100))),2) 'amount_spend'
FROM
    customers c
        INNER JOIN
    orders o ON o.customer_id = c.customer_id
        INNER JOIN
    order_items oi ON oi.order_id = o.order_id
GROUP BY c.customer_id , c.first_name , c.last_name
ORDER BY amount_spend DESC
),

rankingHighest as (
select * 
, dense_rank() over(order by amount_spend desc) as "ranking" 
from customerHighest
)

SELECT 
    CONCAT(first_name, ' ', last_name) "Customer Name", amount_spend
FROM
    rankingHighest
WHERE
    ranking = 1;

-- 5. Find the highest-priced product for each category name.

with category_products as (
	SELECT 
    c.category_name, p.product_name, p.list_price
FROM
    categories c
        INNER JOIN
    products p ON c.category_id = p.category_id
GROUP BY c.category_name , p.product_name , p.list_price
),

ranking as (
select * , dense_rank() over(partition by category_name order by list_price desc) 'rankPrice'
from category_products
)

SELECT 
    category_name, product_name, list_price
FROM
    ranking
WHERE
    rankPrice = 1;

-- 6. Find the total number of orders placed by each customer per store.

SELECT 
    c.customer_id,
    CONCAT(first_name, ' ', last_name) "Customer Name",
    s.store_name,
    COUNT(*) 'number_of_orders'
FROM
    customers c
        INNER JOIN
    orders o ON c.customer_id = o.customer_id
        INNER JOIN
    stores s ON s.store_id = o.store_id
GROUP BY c.customer_id , c.first_name , c.last_name , s.store_name;

-- 7. Find the names of staff members who have not made any sales.

SELECT 
    s.staff_id, s.first_name, s.last_name, o.order_id
FROM
    staffs s
        LEFT JOIN
    orders o ON s.staff_id = o.staff_id
WHERE
    o.order_id IS NULL;

-- 8. Find the top 3 most sold products in terms of quantity.

with rankingDense as (
SELECT 
    p.product_name AS 'Product_name'
    ,SUM(oi.quantity) AS 'Quantity'
    ,dense_rank() over(order by SUM(oi.quantity) desc) 'rownumber'
FROM
    products p
        INNER JOIN
    order_items oi ON p.product_id = oi.product_id
GROUP BY p.product_name
ORDER BY Quantity DESC
)

SELECT 
    Product_name, Quantity
FROM
    rankingDense
WHERE
    rownumber IN (1 , 2, 3);

-- 9. Find the median value of the price list. 

with rowNumber as (
select product_name,list_price
,row_number() over(order by list_price) position
,count(*) over() n
from products
)

select
case 
	when n % 2 = 0 then (
		select avg(list_price) from rowNumber where position in (n/2,(n/2)+1)
    )else(
		select avg(list_price) from rowNumber where position = ((n+1)/2)
    )
    end median
from rowNumber limit 1;

-- 10. List all products that have never been ordered.(use Exists)

SELECT 
    p.product_name
FROM
    products p
        LEFT JOIN
    order_items oi ON oi.product_id = p.product_id
WHERE
    oi.order_id IS NULL;

-- 11. List the names of staff members who have made more sales than the average number of sales by all staff members.

with staff_sales as (
	SELECT 
    s.staff_id,
    s.first_name,
    s.last_name,
    COALESCE(SUM(order_items.list_price * order_items.quantity),
            0) AS 'total_sales'
FROM
    staffs s
        LEFT JOIN
    orders o ON o.staff_id = s.staff_id
        LEFT JOIN
    order_items oi ON oi.order_id = o.order_id
GROUP BY s.staff_id , s.first_name , s.last_name
),
average_sales as (
	SELECT 
    ROUND(AVG(total_sales), 2) AS avg_sales
FROM
    staff_sales
)

SELECT 
    ss.staff_id,
    CONCAT(ss.first_name, ' ', ss.last_name) "Staff Name"
    , ss.total_sales
FROM
    staff_sales ss
        JOIN
    average_sales avg ON ss.total_sales > avg.avg_sales;

-- 12. Identify the customers who have ordered all types of products (i.e., from every category).

with total_categories as (
SELECT 
    COUNT(*) AS category_count
FROM
    categories
),

customer_category_counts as(
SELECT 
    c.customer_id,
    c.first_name,
    c.last_name,
    COUNT(DISTINCT p.category_id) AS categories_ordered
FROM
    customers c
        JOIN
    orders o ON o.customer_id = c.customer_id
        JOIN
    order_items oi ON oi.order_id = o.order_id
        JOIN
    products p ON p.product_id = oi.product_id
GROUP BY c.customer_id , c.first_name , c.last_name
)

SELECT 
    ccc.customer_id,
    ccc.first_name,
    ccc.last_name,
    ccc.categories_ordered
FROM
    customer_category_counts ccc,
    total_categories tc
WHERE
    ccc.categories_ordered = tc.category_count;
