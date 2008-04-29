CREATE TABLE products_categories
(
  sku varchar(32) NOT NULL,
  category int8 NOT NULL,
  CONSTRAINT products_categories_pkey PRIMARY KEY (sku, category)
) 
WITHOUT OIDS;
