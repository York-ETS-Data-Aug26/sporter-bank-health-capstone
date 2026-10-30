\set ON_ERROR_STOP on
SET client_min_messages = warning;

BEGIN;

DROP SCHEMA warehouse CASCADE;
CREATE SCHEMA IF NOT EXISTS warehouse;

SET search_path TO warehouse;

DROP TABLE IF EXISTS
	complaint,
	company_bank_match,
	failure_event,
	financial_observation,
	cfpb_company,
	instituion,
	holding_company,
	charter_class,
	state,
	product,
	sub_product,
	issue,
	sub_issue,
	public_response,
	consumer_response,
	submission_channel
CASCADE;

CREATE TABLE state (
	state_number SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	state_code text UNIQUE);

CREATE TABLE charter_class (
	charter_class_id SMALLINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	charter_code varchar(10) NOT NULL UNIQUE);

CREATE TABLE holding_company (
	holding_company_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	holding_company_name text NOT NULL UNIQUE);

CREATE TABLE institution (
	cert varchar(20) PRIMARY KEY,
	institituion_name text NOT NULL,
	active boolean,
	established_date date,
	end_date date,
	charter_class_id SMALLINT REFERENCES charter_class(charter_class_id),
	state_number SMALLINT  REFERENCES state(state_number),
	holding_company_id bigint REFERENCES holding_company(holding_company_id),
	city text,
	zip_code text,
	website text,
	CONSTRAINT institution_cert_not_null CHECK (btrim(cert) <> '')
	);

CREATE TABLE financial_observation(
	cert varchar(20) NOT NULL,
	quarter_date date NOT NULL,
	fiscal_year SMALLINT,
	fiscal_quarter SMALLINT NOT NULL
		CHECK (fiscal_quarter BETWEEN 1 AND 4),
	netinc_ytd NUMERIC (20,3),
	netinc_qtr NUMERIC (20,3),
	intinc_ytd NUMERIC (20,3),
	intinc_qtr NUMERIC (20,3),
	eintexp_ytd NUMERIC (20,3),
	eintexp_qtr NUMERIC (20,3),
	nonii_ytd NUMERIC (20,3),
	nonii_qtr NUMERIC (20,3),
	nonix_ytd NUMERIC (20,3),
	nonix_qtr NUMERIC (20,3),
	elnatr_ytd NUMERIC (20,3),
	elnatr_qtr NUMERIC (20,3),
	roa NUMERIC (12,6),
	roe NUMERIC (12,6),
	nimy NUMERIC (12,6),
	total_assets NUMERIC (20,3),
	total_deposits NUMERIC (20,3),

	CONSTRAINT financial_observation_pk PRIMARY KEY (cert, quarter_date),
	CONSTRAINT fiancial_observation_quarter_end CHECK (
		quarter_date = ( date_trunc('quarter', quarter_date)::date + INTERVAL '3 months' - INTERVAL '1 day')::date)) ;


CREATE TABLE failure_event (
	failure_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	cert varchar(20) REFERENCES institution(cert),
	institution_name text,
	failure_date date,
	resolution_date date,
	failure_year SMALLINT,
	state_number SMALLINT  REFERENCES state(state_number),
	qbfasset NUMERIC (20,3),
	qbfdep NUMERIC (20,3),
	COST NUMERIC (20,3),
	uninsdep NUMERIC (20,3)
);

CREATE TABLE cfpb_company (
	company_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	company_name text NOT NULL UNIQUE,
	CONSTRAINT cfpb_company_name_not_blank CHECK (
		btrim(company_name) <> ''
	)
);


CREATE TABLE company_bank_match (
	company_id bigint PRIMARY KEY REFERENCES cfpb_company(company_id),
	institution_cert varchar(20) REFERENCES institution(cert),
	holding_company_id bigint REFERENCES holding_company(holding_company_id),
	match_method varchar(20) NOT NULL CHECK (match_method IN ('exact', 'suffix_stripped','unmatched', 'manual_override')),
	unmatched_category varchar(30)
);

CREATE TABLE product (
	product_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	product_name text NOT NULL UNIQUE);

CREATE TABLE sub_product (
	sub_product_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	sub_product_name text NOT NULL UNIQUE);

CREATE TABLE issue(
	issue_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	issue_name text NOT NULL UNIQUE);

CREATE TABLE sub_issue (
	sub_issue_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	sub_issue_name text NOT NULL UNIQUE);

CREATE TABLE public_response (
	public_response_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	response_name text NOT NULL UNIQUE);

CREATE TABLE consumer_response (
	consumer_response_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	response_name text NOT NULL UNIQUE);

CREATE TABLE submission_channel (
	channel_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	channel_name text NOT NULL UNIQUE);

CREATE TABLE complaint (
	complaint_id bigint PRIMARY KEY,
	company_id bigint NOT NULL REFERENCES cfpb_company(company_id),
	date_received date,
	date_sent_to_company date,
	product_id bigint REFERENCES product(product_id),
	sub_product_id bigint REFERENCES sub_product(sub_product_id),
	issue_id bigint REFERENCES issue(issue_id),
	sub_issue_id bigint REFERENCES sub_issue(sub_issue_id),
	public_response_id bigint REFERENCES public_response(public_response_id),
	consumer_response_id bigint REFERENCES consumer_response(consumer_response_id),
	channel_id bigint REFERENCES submission_channel(channel_id),
	state_number SMALLINT  REFERENCES state(state_number),
	zip_code text,
	timely_response boolean,
	tags text
	);

CREATE TABLE fred_macro(
	quarter_end date PRIMARY KEY,
	fedfunds NUMERIC (12,6),
	unrate NUMERIC (12,6),
	mortgate30us NUMERIC (12,6),
	dgs10 NUMERIC (12,6),
	CONSTRAINT macro_quarter_end CHECK (
		quarter_end = (
			date_trunc('quarter', quarter_end)::date
			+ INTERVAL '3 months'
			- INTERVAL '1 day'
			)::date
		)
);

COMMIT;


/* INSERTS
 */

INSERT INTO state (state_code)
	SELECT DISTINCT upper(btrim(state_code))
	FROM (
		SELECT stalp AS state_code
		FROM staging.stg_institutions si
		UNION ALL
		SELECT pstalp
		FROM staging.stg_failures sf
		UNION ALL
		SELECT state
		FROM staging.stg_complaints sc
	) s
	WHERE nullif(btrim(state_code), '') IS NOT NULL
	ON CONFLICT (state_number) DO NOTHING;

INSERT INTO charter_class (charter_code)
SELECT DISTINCT upper(btrim(bkclass))
FROM staging.stg_institutions si
WHERE nullif(btrim(bkclass), '') IS NOT NULL
ON conflict (charter_code) DO NOTHING;

INSERT INTO charter_class (charter_code)
SELECT DISTINCT upper(btrim(chclass1))
FROM staging.stg_failures sf
WHERE nullif(btrim(sf.chclass1), '') IS NOT NULL
ON CONFLICT (charter_code) DO NOTHING;

INSERT INTO holding_company (holding_company_name)
SELECT DISTINCT btrim(si.namehcr )
FROM staging.stg_institutions si
WHERE nullif(btrim(si.namehcr ), '') IS NOT NULL
ON conflict (holding_company_name) DO NOTHING;

INSERT INTO product (product_name)
SELECT DISTINCT btrim(sc.harmonized_product )
FROM staging.stg_complaints sc
WHERE nullif(btrim(harmonized_product), '') IS NOT NULL
ON conflict (product_name) DO NOTHING;

INSERT INTO sub_product (sub_product_name)
SELECT DISTINCT btrim(sc.sub_product )
FROM staging.stg_complaints sc
WHERE nullif(btrim(sub_product), '') IS NOT NULL
ON CONFLICT (sub_product_name) DO NOTHING ;

INSERT INTO issue (issue_name)
SELECT DISTINCT btrim(issue)
FROM staging.stg_complaints sc
WHERE nullif(btrim(issue), '') IS NOT NULL
ON CONFLICT (issue_name) DO NOTHING;

INSERT INTO sub_issue (sub_issue_name)
SELECT DISTINCT btrim(sub_issue)
FROM staging.stg_complaints sc
WHERE nullif(btrim(sc.sub_issue ), '') IS NOT NULL
ON CONFLICT (sub_issue_name) DO NOTHING;

INSERT INTO public_response(response_name)
SELECT DISTINCT btrim(company_public_response)
FROM staging.stg_complaints sc
WHERE nullif(btrim(sc.company_public_response ), '') IS NOT NULL
ON conflict (response_name) DO NOTHING;

INSERT INTO consumer_response(response_name)
SELECT DISTINCT btrim(company_response_to_consumer)
FROM staging.stg_complaints sc
WHERE nullif(btrim(sc.company_response_to_consumer),'') IS NOT NULL
ON CONFLICT (response_name) DO NOTHING;

INSERT INTO submission_channel (channel_name)
SELECT DISTINCT btrim(submitted_via)
FROM staging.stg_complaints sc
WHERE nullif(btrim(sc.submitted_via), '') IS NOT NULL
ON CONFLICT (channel_name) DO NOTHING;

INSERT INTO institution(
	cert,
	institituion_name,
	active,
	established_date,
	end_date,
	charter_class_id,
	state_number,
	holding_company_id,
	city,
	zip_code,
	website
	)
	SELECT
		btrim(si.cert),
		btrim(si."name" ),
		si.active ,
		si.estymd ,
		si.endefymd,
		cc.charter_class_id,
		st.state_number,
		hc.holding_company_id,
		nullif(btrim(si.city), ''),
		nullif(btrim(si.zip), ''),
		nullif(btrim(si.webaddr), '')
	FROM staging.stg_institutions si
	LEFT JOIN charter_class cc
		ON cc.charter_code = upper(btrim(si.bkclass ))
	LEFT JOIN state st
		ON st.state_code = upper(btrim(si.stalp ))
	LEFT JOIN holding_company hc
		ON hc.holding_company_name = nullif(btrim(si.namehcr ), '')
	WHERE nullif(btrim(si.cert), '') IS NOT NULL;

INSERT INTO financial_observation(
	cert,
	quarter_date,
	fiscal_year,
	fiscal_quarter,
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
	total_deposits)
	SELECT
		btrim(sf.cert),
		sf.quarter_date  ,
		sf."year",
		sf.quarter ,
		sf.netinc ,
		sf.netinc_qtr ,
		sf.intinc ,
		sf.intinc_qtr ,
		sf.eintexp ,
		sf.eintexp_qtr ,
		sf.nonii ,
		sf.nonii_qtr ,
		sf.nonix ,
		sf.nonix_qtr ,
		sf.elnatr ,
		sf.elnatr_qtr ,
		sf.roa ,
		sf.roe ,
		sf.nimy ,
		sf.asset ,
		sf.dep
	FROM staging.stg_financials sf;

INSERT INTO failure_event (
	cert,
	institution_name,
	failure_date,
	resolution_date,
	failure_year,
	state_number,
	qbfasset,
	qbfdep,
	"cost",
	uninsdep)
	SELECT
		i.cert,
		nullif(btrim(sf."name" ), ''),
		sf.faildate ,
		sf.resdate,
		sf.failyr ,
		s.state_number ,
		sf.qbfasset ,
		sf.qbfdep ,
		sf."cost" ,
		sf.uninsdep
	FROM staging.stg_failures sf
	LEFT JOIN warehouse.institution i
		ON i.cert = nullif(btrim(sf.cert ), '')
	LEFT JOIN warehouse.state s
		ON s.state_code = sf.bidstate ;

INSERT INTO cfpb_company (
	company_name)
	SELECT DISTINCT btrim(company_name) AS company_name
	FROM (
		SELECT company AS company_name
		FROM staging.stg_complaints sc
		UNION
		SELECT sc.company_name_normalized
		FROM staging.stg_crosswalk sc ) companies
	WHERE nullif(btrim(company_name), '') IS NOT NULL
	ON CONFLICT  (company_name) DO NOTHING;

INSERT INTO company_bank_match(
	company_id,
	institution_cert,
	holding_company_id,
	match_method,
	unmatched_category)
SELECT
	co.company_id,
	i.cert,
	i.holding_company_id,
	sc.match_method ,
	sc.company_category
FROM warehouse.cfpb_company co
RIGHT JOIN staging.stg_crosswalk sc
	ON btrim(sc.company_name) = co.company_name
LEFT JOIN warehouse.institution i
	ON i.cert = nullif(btrim(sc.matched_fdic_certificate_number ), '')
LEFT JOIN warehouse.holding_company hc
	ON hc.holding_company_name = nullif(btrim(sc.holding_company), '');

INSERT INTO complaint (
	complaint_id,
	company_id,
	date_received,
	date_sent_to_company,
	product_id,
	sub_product_id,
	issue_id,
	sub_issue_id,
	public_response_id,
	consumer_response_id,
	channel_id,
	state_number,
	zip_code,
	timely_response,
	tags)
SELECT
	sc.complaint_id ,
	cc.company_id,
	sc.date_received ,
	sc.date_sent_to_company ,
	p.product_id,
	sp.sub_product_id,
	i.issue_id,
	si.sub_issue_id,
	pr.public_response_id,
	cr.consumer_response_id,
	sc2.channel_id,
	s.state_number ,
	nullif(btrim(sc.zip_code), ''),
	CASE
		WHEN lower(btrim(sc.timely_response)) IN ('yes', 'true', '1')
			THEN TRUE
		WHEN lower(btrim(sc.timely_response)) IN ('no', 'false', '0')
			THEN FALSE
		ELSE NULL
	END,
	NULLIF (btrim(sc.tags), '')
FROM staging.stg_complaints sc
JOIN warehouse.cfpb_company cc
	ON cc.company_name = btrim(sc.company )
LEFT JOIN warehouse.product p
	ON p.product_name = nullif(btrim(sc.harmonized_product ), '')
LEFT JOIN warehouse.sub_product sp
	ON sp.sub_product_name = nullif(btrim(sc.sub_product ), '')
LEFT JOIN warehouse.issue i
	ON i.issue_name = nullif(btrim(sc.issue ), '')
LEFT JOIN warehouse.sub_issue si
	ON si.sub_issue_name = NULLIF (btrim(sc.sub_issue ), '')
LEFT JOIN warehouse.public_response pr
	ON pr.response_name = nullif(btrim(sc.company_public_response ), '')
LEFT JOIN warehouse.consumer_response cr
	ON cr.response_name = nullif(btrim(sc.company_response_to_consumer ), '')
LEFT JOIN warehouse.submission_channel sc2
	ON sc2.channel_name = nullif(btrim(sc.submitted_via ), '')
LEFT JOIN warehouse.state s
	ON s.state_code = upper(btrim(sc.state ));

INSERT INTO fred_macro (
	quarter_end,
	fedfunds,
	unrate,
	mortgate30us,
	dgs10
	)
SELECT
	sm.observation_date ,
	sm.fedfunds ,
	sm.unrate ,
	sm.mortgage30us ,
	sm.dgs10
FROM staging.stg_macro sm ;

--INSERT INTO sub_product (sub_product_name)
--SELECT DISTINCT btrim(sc.sub_product )
--FROM staging.stg_complaints sc
--WHERE nullif(btrim(sub_product), '') IS NOT NULL
--ON CONFLICT (sub_product_name) DO NOTHING ;

SELECT
	(SELECT count(*) FROM warehouse.cfpb_company) AS cfpb_company_count,
	(SELECT count(*) FROM warehouse.charter_class) AS charter_count,
	(SELECT count(*) FROM warehouse.company_bank_match) AS match_count,
	(SELECT count(*) FROM warehouse.complaint) AS complaint_count,
	(SELECT count(*) FROM warehouse.consumer_response) AS c_response_count,
	(SELECT count(*) FROM warehouse.failure_event) AS failure_count,
	(SELECT count(*) FROM warehouse.financial_observation) AS financial_count,
	(SELECT count(*) FROM warehouse.fred_macro) AS macro_count,
	(SELECT count(*) FROM warehouse.holding_company) AS holding_count,
	(SELECT count(*) FROM warehouse.institution) AS inst_count,
	(SELECT count(*) FROM warehouse.issue) AS issue_count,
	(SELECT count(*) FROM warehouse.product) AS product_count,
	(SELECT count(*) FROM warehouse.public_response) AS p_response_count,
	(SELECT count(*) FROM warehouse.state) AS state_count,
	(SELECT count(*) FROM warehouse.sub_issue) AS sub_i_count,
	(SELECT count(*) FROM warehouse.sub_product) AS sub_product_count,
	(SELECT count(*) FROM warehouse.submission_channel) AS submission_count;


SELECT DISTINCT chclass1
FROM staging.stg_failures sf ;


