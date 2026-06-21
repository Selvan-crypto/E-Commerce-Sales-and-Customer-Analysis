-- Creating Customer dataset
create table customer(
customerid text,
customer_unique_id text,
customer_zip_code_prefix numeric,
customer_city varchar(50),
customer_state varchar(10)
);

select * from customer
limit 10;

-- Creating the geolocation dataset
create table geolocation(
geolocation_zip_code_pprefix numeric,
geolocation_lat numeric,
geolocation_lng numeric,
geolocation_city varchar(50),
geolocation_stae varchar(10)
);

select * from geolocation 
limit 10;

-- Creating a order item dataset
create table order_item(
order_id text,
order_item_id int,
product_id text,
seller_id text,
shipping_limit_date timestamptz,
price decimal(10,3),
freight_value decimal(6,2)
);

select * from order_item
limit 10;

-- Creating a order payment dataset
create table order_payments(
order_id text,
payment_sequential int,
payment_type text,
payment_installments int,
payment_value decimal(8,3)
);

select * from order_payments
limit 10;

-- Creating a order review dataset
create table order_review(
review_id text,
order_id text,
rview_score int,
review_comment_title text,
review_comment_message text,
review_creation_date timestamp,
review_answer_timestamp timestamp
);

select * from order_review
limit 10;


-- Creating a orders list of dataset
create table orders(
order_id text,
customer_id text,
order_status varchar(20),
order_purchase_timestamp timestamp,
order_approved_at timestamp,
order_delivered_carrier_date timestamp,
order_delivered_customer_date timestamp,
order_estimated_delivery_date timestamp
);

select * from orders
limit 10;


-- Creating a products dataset
create table products(
product_id text,
product_category_name text,
product_name_length int,
product_description_length int,
product_photos_qty int,
product_weight_g int,
product_length_cm int,
product_height_cm int,
product_width_cm int
);

select * from products
limit 10;

-- Creating a seller dataset
create table sellers(
seller_id text,
seller_zip_code_prefix numeric,
seller_city text,
seller_state text
);

select * from sellers
limit 10;

-- Creating a product category name dataset
create table product_category_name(
product_category_name text,
product_category_name_english text
);

select * from product_category_name
limit 10;

---Complex Aggregations--
--Calculate monthly revenue with Month-over-Month (MoM) growth percentage - handle first month edge case

with year_month_sale as
(
	select 
		o.order_approved_at,p.payment_value,date_part('year',o.order_approved_at) as year_,
		date_part('month',o.order_approved_at) as month_
	from 
		order_payments as p 
	join orders as o on p.order_id = o.order_id
	order by 
		year_ ,month_
), 

summing as 
(
	select 
		year_,month_,sum(payment_value) as total_1  
	from 
		year_month_sale
	where 
		month_ is not null
	group by 
		year_,month_
), 

laging as
(
	select
		*,lag(total_1,1) over(order by year_,month_) as total_2  
	from 
		summing
)

select *,round(((total_1 - total_2)/total_2) * 100,2)  from laging;

---Find top 10 products by revenue in each category using RANK() or DENSE_RANK()
--Method - 1 using RANK():

with information as 
(
	select 
		pc.product_category_name_english,sum(ot.price) as total 
	from 
		product_category_name as pc 
	join 
		products as p on p.product_category_name = pc.product_category_name
	join 
		order_item as ot on p.product_id = ot.product_id
	group by product_category_name_english
),
ranking as 
(
	select 
		*,rank() over(order by total desc) as  ranking_total
	from 
		information
)

select * 
from 
	ranking
where 
	ranking_total <= 10;

--Method - 2 using DENSE_RANK():

with information as 
(
	select 
		pc.product_category_name_english,sum(ot.price) as total 
	from 
		product_category_name as pc 
	join 
		products as p on p.product_category_name = pc.product_category_name
	join 
		order_item as ot on p.product_id = ot.product_id
	group by product_category_name_english
),
dense_ranking as 
(
	select 
		*,dense_rank() over(order by total desc) as  dense_ranking_total
	from 
		information
)

select * 
from 
	dense_ranking
where 
	dense_ranking_total <= 10;

--Calculate Customer Lifetime Value (CLV) = SUM(payment_value) per customer, categorize as Bronze/Silver/Gold

with information as 
(
	select 
		o.customer_id,sum(op.payment_value) as total
	from 
		order_payments op join orders as o on o.order_id = op.order_id 
	group by 
		o.customer_id
)
	
select 
	*,case
		when total <= 300.00 then 'Bronze'
		when total between 301.00 and 1100.00 then 'Silver'
		else 'Gold'
	  end as category
from information;

--Create a sales report with daily, weekly, monthly subtotals using ROLLUP or CUBE
--Method -1 using ROLLUP:
select 
	date_part('month',o.order_purchase_timestamp) as monthly,
	date_part('week',o.order_purchase_timestamp) as weekly,
	date_part('day',o.order_purchase_timestamp) as daily,
	sum(op.payment_value) as total
from 
	orders as o 
left join 
	order_payments as op on o.order_id = op.order_id
group by rollup(monthly,weekly,daily);


--Method - 2 using CUBE():
select 
	date_part('month',o.order_purchase_timestamp) as monthly,
	date_part('week',o.order_purchase_timestamp) as weekly,
	date_part('day',o.order_purchase_timestamp) as daily,
	sum(op.payment_value) as total
from 
	orders as o 
left join 
	order_payments as op on o.order_id = op.order_id
group by 
	cube(monthly,weekly,daily);


--Identify seasonal patterns: which product categories sell best in which months?

select 
	date_part('month',o.order_purchase_timestamp) as monthly,
	pc.product_category_name_english as category,
	count(pc.product_category_name_english) total_count
from 
	product_category_name  as pc 
join 
	products as p on pc.product_category_name = p.product_category_name
join 
	order_item as oi on p.product_id = oi.product_id
join 
	orders as o on oi.order_id = o.order_id
group by 
	monthly,category;


--Mastering Joins
--Create a complete customer 360-degree view joining 5+ tables (customers, orders,order_items, products, reviews)

select * 
from 
	customer as c 
right join orders as o on c.customerid = o.customer_id
left join order_item as oi on o.order_id = oi.order_id
inner join products as p on p.product_id = oi.product_id
left join order_review as ore on ore.order_id = oi.order_id;


--Find customers who bought products from category 'electronics'

select * from product_category_name
where product_category_name_english like '%nics';

select 
	c.customerid ,pcn.product_category_name_english
from 
	customer as c 
right join 
	orders as o on c.customerid =o.customer_id
inner join 
	order_item as oi on o.order_id = oi.order_id
inner join 
	products as p on oi.product_id = p.product_id
inner join 
	product_category_name as pcn on p.product_category_name = pcn.product_category_name
where 
	pcn.product_category_name_english = 'electronics'


--List sellers and their best-selling product in each category they sell

select 
	oi.seller_id,
	pcn.product_category_name ,
	count(*) as total
from 
	order_item as  oi 
join products as p on oi.product_id = p.product_id
join product_category_name as pcn on p.product_category_name = pcn.product_category_name
group by 
	oi.seller_id,pcn.product_category_name
order by 
	total desc;


--Identify products frequently bought together (market basket analysis using self-join)

with table1 as 
(
	select o.customer_id,pcn.product_category_name,o.order_purchase_timestamp 
	from 
		order_payments as op 
	inner join 
		order_item as oi on op.order_id = oi.order_id
	inner join 
		products as p on oi.product_id = p.product_id
	inner join 
		product_category_name as pcn on p.product_category_name = pcn.product_category_name
	inner join 
		orders as o on o.order_id = oi.order_id
)

select 
	t1.customer_id, 
	t1.product_category_name,
	t2.product_category_name,
	count(t1.customer_id) over(partition by t1.customer_id)
from 
	table1 as t1 
join table1 as t2
on 
	t1.order_purchase_timestamp = t2.order_purchase_timestamp 
where 
	t1.product_category_name <> t2.product_category_name;


--Find orders with shipping delays: expected_delivery_date < actual_delivery_date, show customer and seller info


with table1 as 
(
	select 
		o.customer_id,
		s.seller_id,
		o.order_estimated_delivery_date,
		o.order_delivered_customer_date
	from 
		orders as o
	inner join 
		order_item as oi on o.order_id = o.order_id
	inner join 
		sellers as s on s.seller_id = oi.seller_id
)
select * 
from 
	table1
where 
	o.order_estimated_delivery_date < o.order_delivered_customer_date;



--Find customers who spent more than the average customer spent in their state (correlated subquery).

with table1 as
(
select 
	c.customer_unique_id,
	c.customer_state,
	sum(oi.price) as total
from 
	customer as c
inner join orders as o 
on c.customerid = o.customer_id
inner join order_item as oi 
on o.order_id = oi.order_id
group by 
	c.customerid,c.customer_state
)

select * 
from 
	table1 as t1
where 
	t1.total < (select 
					avg(total) 
				from table1 as t2
				where 
					t1.customer_state = t2.customer_state);

--Get the 2nd highest revenue-generating product in each category (ranking with subquery)


with table1 as 
(
	select 
		pcn.product_category_name_english,
		sum(price) as total
	from 
		order_payments as op 
	inner join 
		order_item as oi on op.order_id = oi.order_id
	inner join 
		products as p on oi.product_id = p.product_id
	inner join  
		product_category_name as pcn on p.product_category_name = pcn.product_category_name
	group by 
		pcn.product_category_name_english
)

select * 
from 
	(select *,
		rank() over(order by total desc) as ranking
	from 
		table1)
where 
	ranking = 2;


--Using recursive CTE, create a product category hierarchy (if categories have parent-child relationships)

select * from products;

select * from product_category_name;

--Find customers who made purchases in 3+ consecutive months using CTE with window functions

with table1 as 
(
	select
		*
	from 
		customer as c 
	inner join 
		orders as o on c.customerid = o.customer_id
	order by 
		c.customer_unique_id,o.order_purchase_timestamp
),table2 as
(
	select *,
		count(*) 
		over(partition by customer_unique_id,customer_city,customer_state) as counting 
	from table1
	 
),table3 as
(
	select *,
		date_part('year',order_purchase_timestamp) as yearly,
		date_part('month',order_purchase_timestamp) as monthly 
	from
		table2
	where 
		counting >= 3
),table4 as
(
	select *,
		lead(yearly) over(partition by customer_unique_id order by order_purchase_timestamp) as leading_yearly,
		lead(monthly) over(partition by customer_unique_id order by order_purchase_timestamp) as leading_monthly 
	from 
		table3
	order by 
		customer_unique_id,order_purchase_timestamp
),table5 as 
(
	select 
		customer_unique_id,
		yearly,
		leading_yearly,
		monthly,leading_monthly,
		leading_yearly - yearly as sub_yearly,
		leading_monthly - monthly as sub_monthly
	from 
		table4
) 

select * from table5;
