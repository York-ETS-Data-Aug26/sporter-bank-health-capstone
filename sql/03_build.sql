\set ON_ERROR_STOP on
SET client_min_messages = warning;

DROP SCHEMA mart CASCADE;
CREATE SCHEMA IF NOT EXISTS mart;

-- tables for mart as to be able to store data used regularly

SET search_path TO mart;

BEGIN;

DROP TABLE IF EXISTS
	fact_industry_quarter,
	fact_bank_quarter,
	fact_complaint,
	dim_company,
	dim_response,
	dim_channel,
	dim_product,
	dmi_state,
	dim_bank,
	dim_date
CASCADE;

CREATE TABLE dim_date (
	date_key integer PRIMARY KEY,
	calendar_date date NOT NULL UNIQUE,
	calendar_year SMALLINT NOT NULL,
	calendar_quarter SMALLINT NOT NULL
		CHECK (calendar_quarter BETWEEN 1 AND 4),
	month_number SMALLINT NOT NULL
		CHECK (month_number BETWEEN 1 AND 12),
	month_name text NOT NULL,
	quarter_label text NOT NULL,
	quarter_end date NOT NULL,
	is_month_end boolean NOT NULL,
	is_quarter_end boolean NOT NULL );

WITH bounds AS (
	SELECT
		date '1934-01-01' AS start_date,
		GREATEST(
			COALESCE (
				(SELECT max(repdte)
				FROM warehouse.financial_observation fo ),
				date '2026-06-30'
			),
			COALESCE (
				(SELECT max(fe.failure_date )
				FROM warehouse.failure_event fe ),
				date '2006-06-30'
			),
			COALESCE (
				(SELECT max(c.date_received )
				FROM warehouse.complaint c ),
				date '2006-06-30'
			)
		)AS end_date
),
calendar AS (
	SELECT g::date AS d
	FROM bounds b
	CROSS JOIN LATERAL generate_series (
		b.start_date ,
		b.end_date ,
		INTERVAL '1 day'
		) g
)
INSERT INTO dim_date (
	date_key,
	calendar_date,
	calendar_year,
	calendar_quarter,
	month_number,
	month_name,
	quarter_label,
	quarter_end,
	is_month_end,
	is_quarter_end)
SELECT
	to_char(d, 'YYYYMMDD')::integer,
	d,
	EXTRACT (YEAR FROM d)::SMALLINT,
	EXTRACT (quarter FROM d)::SMALLINT,
	EXTRACT (MONTH FROM d)::SMALLINT,
	to_char(d, 'FMMonth'),
	EXTRACT (YEAR FROM d):: text || 'Q' || EXTRACT(Quarter FROM d)::text,
	(
	DATE_TRUNC('quarter', d)::date
	+ INTERVAL '3 months'
	- INTERVAL '1 day'
	)::date,
	d = (date_trunc ('month', d)
		+ INTERVAL '1 month - 1 day')::date,
	d = (
		date_trunc ('quarter', d)::date
		+ INTERVAL '3 months'
		- INTERVAL '1 day'
		)::date
FROM calendar
ON CONFLICT (date_key) DO NOTHING;

CREATE TABLE dim_bank(
	bank_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	bank_entity_type varchar(20) NOT NULL
		CHECK (bank_entity_type IN ('charter', 'holding_company')),
	cert varchar(20),
	holding_company_id integer,
	bank_name text NOT NULL,
	charter_code varchar(10),
	state_code varchar(10),
	active boolean,
	CONSTRAINT dim_bank_charter_unique UNIQUE (cert)
);

INSERT INTO dim_bank(
	bank_entity_type,
	cert,
	holding_company_id,
	bank_name,
	charter_code,
	state_code,
	active)
SELECT
	'charter',
	i.cert,
	i.holding_company_id ,
	i.institituion_name  ,
	cc.charter_code,
	i.state_number ,
	i.active
FROM warehouse.institution i
LEFT JOIN warehouse.charter_class cc
	ON cc.charter_class_id = i.charter_class_id
WHERE i.holding_company_id IS NOT NULL;

INSERT INTO dim_bank(
	bank_entity_type,
	cert,
	holding_company_id,
	bank_name,
	charter_code,
	state_code,
	active)
SELECT
	'holding_company',
	NULL,
	hc.holding_company_id,
	hc.holding_company_name,
	NULL,
	NULL,
	NULL
FROM warehouse.holding_company hc ;

CREATE TABLE dim_company (
	company_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	company_id bigint NOT NULL UNIQUE,
	company_name text NOT NULL UNIQUE,
	match_method varchar(20) NOT NULL,
	unmatched_category varchar(30),
	matched_bank_key bigint REFERENCES dim_bank(bank_key)
	);

INSERT INTO dim_company (
	company_id,
	company_name,
	match_method,
	unmatched_category,
	matched_bank_key)
SELECT
	cc.company_id,
	cc.company_name ,
	coalesce(cbm.match_method , 'unmatched'),
	cbm.unmatched_category,
	CASE
		WHEN cbm.institution_cert IS NOT NULL
			THEN db.bank_key
		WHEN cbm.holding_company_id IS NOT NULL
			THEN db2.bank_key
		ELSE NULL
	END
FROM warehouse.cfpb_company cc
LEFT JOIN warehouse.company_bank_match cbm
	ON cbm.company_id = cc.company_id
LEFT JOIN mart.dim_bank db
	ON db.bank_entity_type = 'charter'
	AND db.cert = cbm.institution_cert
LEFT JOIN mart.dim_bank db2
	ON db2.bank_entity_type  = 'holding_company'
	AND db2.holding_company_id = cbm.holding_company_id;

CREATE TABLE dim_product (
	product_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	product_id bigint NOT NULL UNIQUE,
	product_name text NOT NULL UNIQUE);

INSERT INTO dim_product(
	product_id,
	product_name)
SELECT
	p.product_id ,
	p.product_name
FROM warehouse.product p;

CREATE TABLE dim_state (
	state_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	state_code text NOT NULL UNIQUE);

INSERT INTO dim_state (
	state_code)
SELECT
	s.state_code
FROM warehouse.state s ;

CREATE TABLE dim_response(
	response_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	public_response text,
	consumer_response text,
	timely_response boolean,
	CONSTRAINT dim_response_combination_unique
		UNIQUE NULLS NOT DISTINCT (
			public_response, consumer_response, timely_response)
);

INSERT INTO dim_response (
	public_response,
	consumer_response,
	timely_response)
SELECT DISTINCT
	pr.response_name ,
	cr.response_name ,
	c.timely_response
FROM warehouse.complaint c
LEFT JOIN warehouse.public_response pr
	ON pr.public_response_id = c.public_response_id
LEFT JOIN warehouse.consumer_response cr
	ON cr.consumer_response_id = c.consumer_response_id ;

CREATE TABLE dim_channel (
	channel_key bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	channel_id bigint NOT NULL UNIQUE,
	channel_name text NOT NULL UNIQUE);

INSERT INTO dim_channel (
	channel_id,
	channel_name)
SELECT
	sc.channel_id ,
	sc.channel_name
FROM warehouse.submission_channel sc ;

CREATE TABLE fact_complaint (
	complaint_id bigint PRIMARY KEY,
	date_key integer REFERENCES dim_date(date_key),
	company_key bigint NOT NULL REFERENCES dim_company(company_key),
	bank_key bigint REFERENCES dim_bank(bank_key),
	product_key bigint REFERENCES dim_product(product_key),
	state_key bigint REFERENCES dim_state(state_key),
	response_key bigint REFERENCES dim_response(response_key),
	channel_key bigint REFERENCES dim_channel(channel_key),
	date_sent_to_company date,
	sub_product text,
	issue text,
	sub_issue text,
	zip_code text,
	tags text,
	complaint_count SMALLINT NOT NULL DEFAULT 1
		CHECK (complaint_count = 1));

INSERT INTO fact_complaint (
	complaint_id,
	date_key,
	company_key,
	bank_key,
	product_key,
	state_key,
	response_key,
	channel_key,
	date_sent_to_company,
	sub_product,
	issue,
	sub_issue,
	zip_code,
	tags)
SELECT
	c.complaint_id ,
	to_char(c.date_received , 'YYYYMMDD')::integer,
	dc.company_key ,
	dc.matched_bank_key ,
	dp.product_key ,
	s.state_number,
	dr.response_key ,
	ch.channel_key,
	c.date_sent_to_company ,
	sp.sub_product_name,
	iss.issue_name,
	si.sub_issue_name,
	c.zip_code ,
	c.tags
FROM warehouse.complaint c
JOIN mart.dim_company dc
	ON dc.company_id = c.company_id
LEFT JOIN mart.dim_product dp
	ON dp.product_id = c.product_id
LEFT JOIN warehouse.state s
	ON s.state_number  = c.state_number
LEFT JOIN mart.dim_state ds
	ON ds.state_code = s.state_code
LEFT JOIN warehouse.public_response pr
	ON pr.public_response_id = c.public_response_id
LEFT JOIN warehouse.consumer_response cr
	ON cr.consumer_response_id = c.consumer_response_id
LEFT JOIN mart.dim_response dr
	ON dr.public_response IS NOT DISTINCT FROM pr.response_name
	AND dr.consumer_response IS NOT DISTINCT FROM cr.response_name
	AND dr.timely_response IS NOT DISTINCT FROM c.timely_response
LEFT JOIN warehouse.submission_channel sc
	ON sc.channel_id = c.channel_id
LEFT JOIN mart.dim_channel ch
	ON ch.channel_id = sc.channel_id
LEFT JOIN warehouse.sub_product sp
	ON sp.sub_product_id = c.sub_product_id
LEFT JOIN warehouse.issue iss
	ON iss.issue_id = c.issue_id
LEFT JOIN warehouse.sub_issue si
	ON si.sub_issue_id = c.sub_issue_id;

CREATE TABLE fact_bank_quarter (
	bank_key bigint NOT NULL REFERENCES dim_bank(bank_key),
	date_key integer NOT NULL REFERENCES dim_date(date_key),
	netinc_ytd NUMERIC (20,3),
	netinc_qtr NUMERIC (20,3),
	intinc_ytd NUMERIC (20,3),
	intinc_qtr NUMERIC (20,3),
	eintexp_ytd NUMERIC (20,3),
	eintexp_qtr NUMERIC (20,3),
	nonii_ytd NUMERIC (20,3),
	nonii_qtr NUMERIC  (20,3),
	nonix_ytd NUMERIC (20,3),
	nonix_qtr NUMERIC (20,3),
	elnatr_ytd NUMERIC  (20,3),
	elnatr_qtr NUMERIC (20,3),
	roa NUMERIC  (12,6),
	roe NUMERIC (12,6),
	nimy NUMERIC (12,6),
	total_assets NUMERIC (20,3),
	total_deposits NUMERIC (20,3),
	fedfunds NUMERIC (12,6),
	unrate NUMERIC (12,6),
	mortgage30us NUMERIC (12,6),
	dgs10 NUMERIC (12,6),
	PRIMARY KEY (bank_key, date_key)
);

INSERT INTO fact_bank_quarter (
	bank_key,
	date_key,
	netinc_ytd,
	netinc_qtr,
	intinc_ytd,
	intinc_qtr,
	eintexp_ytd,
	eintexp_qtr,
	nonii_ytd,
	nonii_qtr,
	nonix_ytd,
	nonix_qtr,
	elnatr_ytd,
	elnatr_qtr,
	roa,
	roe,
	nimy,
	total_assets,
	total_deposits,
	fedfunds,
	unrate,
	mortgage30us,
	dgs10)
SELECT
	db.bank_key ,
	to_char(fo.repdte, 'YYYYMMDD' )::integer,
	fo.netinc_ytd ,
	fo.netinc_qtr,
	fo.intinc_ytd ,
	fo.intinc_qtr ,
	fo.eintexp_ytd ,
	fo.eintexp_qtr ,
	fo.nonii_ytd ,
	fo.nonii_qtr ,
	fo.nonix_ytd ,
	fo.nonix_qtr ,
	fo.elnatr_ytd ,
	fo.elnatr_qtr ,
	fo.roa ,
	fo.roe ,
	fo.nimy ,
	fo.total_assets ,
	fo.total_deposits ,
	fm.fedfunds ,
	fm.unrate ,
	fm.mortgate30us ,
	fm.dgs10
FROM warehouse.financial_observation fo
LEFT JOIN mart.dim_bank db
	ON  db.cert = fo.cert
LEFT JOIN warehouse.fred_macro fm
	ON fm.quarter_end = fo.repdte
WHERE db.bank_entity_type = 'charter'
	AND fo.cert = db.cert ;

INSERT INTO fact_bank_quarter (
	bank_key,
	date_key,
	netinc_ytd,
	netinc_qtr,
	intinc_ytd,
	intinc_qtr,
	eintexp_ytd,
	eintexp_qtr,
	nonii_ytd,
	nonii_qtr,
	nonix_ytd,
	nonix_qtr,
	elnatr_ytd,
	elnatr_qtr,
	roa,
	roe,
	nimy,
	total_assets,
	total_deposits,
	fedfunds,
	unrate,
	mortgage30us,
	dgs10)
SELECT
	db.bank_key ,
	to_char(fo.repdte, 'YYYYMMDD' )::integer,
	sum (fo.netinc_ytd) ,
	sum (fo.netinc_qtr),
	sum (fo.intinc_ytd ),
	sum (fo.intinc_qtr ),
	sum (fo.eintexp_ytd ),
	sum (fo.eintexp_qtr ),
	sum (fo.nonii_ytd ),
	sum (fo.nonii_qtr) ,
	sum (fo.nonix_ytd ),
	sum (fo.nonix_qtr ),
	sum (fo.elnatr_ytd ),
	sum (fo.elnatr_qtr ),
	NULL ,
	NULL ,
	NULL,
	sum (fo.total_assets) ,
	sum (fo.total_deposits ),
	max (fm.fedfunds) ,
	max (fm.unrate) ,
	max (fm.mortgate30us) ,
	max (fm.dgs10)
FROM warehouse.financial_observation fo
JOIN warehouse.institution i
	ON i.cert = fo.cert
LEFT JOIN mart.dim_bank db
	ON db.bank_entity_type = 'holding_company'
	AND db.holding_company_id = i.holding_company_id
LEFT JOIN warehouse.fred_macro fm
	ON fm.quarter_end = fo.repdte
WHERE db.bank_key IS NOT NULL
GROUP BY db.bank_key , fo.repdte ;

CREATE TABLE fact_industry_quarter (
	date_key integer PRIMARY KEY REFERENCES dim_date(date_key),
	institution_count integer NOT NULL,
	total_assets NUMERIC (20,3),
	total_deposits NUMERIC (20,3),
	netinc_qtr NUMERIC (20,3),
	complaint_count bigint NOT NULL,
	bank_matched_complaint_count bigint NOT NULL,
	fedfunds NUMERIC (12,6),
	unrate NUMERIC (12,6),
	mortgage30us NUMERIC (12,6),
	dgs10 NUMERIC (12,6)
	);


WITH financial_summary AS (
	SELECT
		fo.repdte ,
		count(DISTINCT fo.cert )::integer AS institution_count,
		sum (fo.total_assets ) AS total_assets,
		sum(fo.total_deposits ) AS total_deposits,
		sum(fo.netinc_qtr ) AS netinc_qtr
	FROM warehouse.financial_observation fo
	GROUP BY fo.repdte
),
complaint_summary AS (
	SELECT
		dd.quarter_end,
		count(*) AS complaint_count,
		count(*) FILTER (
			WHERE fc.bank_key IS NOT NULL) AS bank_matched_complaint_count
	FROM mart.fact_complaint fc
	JOIN mart.dim_date dd ON dd.date_key = fc.date_key
	GROUP BY dd.quarter_end
)
INSERT INTO fact_industry_quarter (
	date_key,
	institution_count,
	total_assets,
	total_deposits,
	netinc_qtr,
	complaint_count,
	bank_matched_complaint_count,
	fedfunds,
	unrate,
	mortgage30us,
	dgs10)
SELECT
	to_char(fs.repdte, 'YYYYMMDD')::integer,
	FS.institution_count,
	FS.total_assets,
	FS.total_deposits,
	FS.netinc_qtr,
	COALESCE (cs.complaint_count,0),
	COALESCE(cs.bank_matched_complaint_count, 0),
	m.fedfunds,
	m.unrate,
	m.mortgate30us,
	m.dgs10
FROM financial_summary FS
LEFT JOIN complaint_summary cs
	ON cs.quarter_end = FS.repdte
LEFT JOIN warehouse.fred_macro m
	ON m.quarter_end = FS.repdte;

CREATE TABLE fact_failure (
	failure_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	failure_date_key integer REFERENCES mart.dim_date (date_key),
	bank_key bigint REFERENCES mart.dim_bank (bank_key),
	institution_name text,
	resolution_date date,
	qbfasset NUMERIC (20,3),
	qbfdep NUMERIC (20,3),
	COST NUMERIC (20,3),
	uninsdep NUMERIC (20,3)
);

INSERT INTO fact_failure (
	failure_date_key,
	bank_key,
	institution_name,
	resolution_date,
	qbfasset,
	qbfdep,
	COST,
	uninsdep)
SELECT
	to_char(fe.failure_date, 'YYYYMMDD')::integer,
	db.bank_key ,
	fe.institution_name ,
	fe.resolution_date ,
	fe.qbfasset ,
	fe.qbfdep ,
	fe."cost" ,
	fe.uninsdep
FROM warehouse.failure_event fe
LEFT JOIN mart.dim_bank db
	ON db.bank_entity_type = 'charter'
	AND db.cert = fe.cert ;

ALTER TABLE dim_bank
ADD COLUMN parent_bank_key bigint REFERENCES dim_bank(bank_key);

UPDATE mart.dim_bank db
SET parent_bank_key = db.bank_key
FROM warehouse.institution i
JOIN mart.dim_bank db2
	ON db2.bank_entity_type = 'holding_company'
	AND db2.holding_company_id = i.holding_company_id
WHERE db.bank_entity_type = 'charter'
	AND db.cert = i.cert
	AND db.holding_company_id IS NOT NULL ;

COMMIT;