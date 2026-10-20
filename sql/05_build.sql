SET search_path TO staging;

DO $$
DECLARE
    rec RECORD;
    query TEXT := '';
    -- 1. Separated schema and table to fix the lookup bug
    target_schema TEXT := 'staging';
    target_table TEXT := 'stg_complaints';
BEGIN
    -- 2. Added schema filtering to ensure accuracy
    FOR rec IN
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = target_schema
          AND table_name = target_table
    LOOP
        IF query <> '' THEN
            query := query || ' UNION ALL ';
        END IF;

        -- 3. Fixed FROM clause to cleanly handle schema-qualified names using format() %I
        query := query || format(
            'SELECT %L::text AS column, %L::text AS dtype, %L::text AS row_type, ' ||
            'COUNT(*) - COUNT(%I) AS null_count, COUNT(DISTINCT %I) AS distinct_count FROM %I.%I',
            rec.column_name,
            rec.data_type,
            CASE WHEN rec.is_nullable = 'YES' THEN 'Nullable' ELSE 'NOT NULL' END,
            rec.column_name,
            rec.column_name,
            target_schema,
            target_table
        );
    END LOOP;

    -- 4. Added a safety check to make sure columns were actually found
    IF query = '' THEN
        RAISE EXCEPTION 'Table %. % not found or has no columns.', target_schema, target_table;
    END IF;

    EXECUTE 'DROP TABLE IF EXISTS table_profile; CREATE TEMP TABLE table_profile AS ' || query;
END $$;

-- View the results from the temp table
SELECT * FROM table_profile;

DO $$
DECLARE
    rec RECORD;
    query TEXT := '';
    -- 1. Separated schema and table to fix the lookup bug
    target_schema TEXT := 'staging';
    target_table TEXT := 'stg_crosswalk';
BEGIN
    -- 2. Added schema filtering to ensure accuracy
    FOR rec IN
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = target_schema
          AND table_name = target_table
    LOOP
        IF query <> '' THEN
            query := query || ' UNION ALL ';
        END IF;

        -- 3. Fixed FROM clause to cleanly handle schema-qualified names using format() %I
        query := query || format(
            'SELECT %L::text AS column, %L::text AS dtype, %L::text AS row_type, ' ||
            'COUNT(*) - COUNT(%I) AS null_count, COUNT(DISTINCT %I) AS distinct_count FROM %I.%I',
            rec.column_name,
            rec.data_type,
            CASE WHEN rec.is_nullable = 'YES' THEN 'Nullable' ELSE 'NOT NULL' END,
            rec.column_name,
            rec.column_name,
            target_schema,
            target_table
        );
    END LOOP;

    -- 4. Added a safety check to make sure columns were actually found
    IF query = '' THEN
        RAISE EXCEPTION 'Table %. % not found or has no columns.', target_schema, target_table;
    END IF;

    EXECUTE 'DROP TABLE IF EXISTS table_profile; CREATE TEMP TABLE table_profile AS ' || query;
END $$;

-- View the results from the temp table
SELECT * FROM table_profile;

DO $$
DECLARE
    rec RECORD;
    query TEXT := '';
    -- 1. Separated schema and table to fix the lookup bug
    target_schema TEXT := 'staging';
    target_table TEXT := 'stg_failures';
BEGIN
    -- 2. Added schema filtering to ensure accuracy
    FOR rec IN
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = target_schema
          AND table_name = target_table
    LOOP
        IF query <> '' THEN
            query := query || ' UNION ALL ';
        END IF;

        -- 3. Fixed FROM clause to cleanly handle schema-qualified names using format() %I
        query := query || format(
            'SELECT %L::text AS column, %L::text AS dtype, %L::text AS row_type, ' ||
            'COUNT(*) - COUNT(%I) AS null_count, COUNT(DISTINCT %I) AS distinct_count FROM %I.%I',
            rec.column_name,
            rec.data_type,
            CASE WHEN rec.is_nullable = 'YES' THEN 'Nullable' ELSE 'NOT NULL' END,
            rec.column_name,
            rec.column_name,
            target_schema,
            target_table
        );
    END LOOP;

    -- 4. Added a safety check to make sure columns were actually found
    IF query = '' THEN
        RAISE EXCEPTION 'Table %. % not found or has no columns.', target_schema, target_table;
    END IF;

    EXECUTE 'DROP TABLE IF EXISTS table_profile; CREATE TEMP TABLE table_profile AS ' || query;
END $$;

-- View the results from the temp table
SELECT * FROM table_profile;

DO $$
DECLARE
    rec RECORD;
    query TEXT := '';
    -- 1. Separated schema and table to fix the lookup bug
    target_schema TEXT := 'staging';
    target_table TEXT := 'stg_financials';
BEGIN
    -- 2. Added schema filtering to ensure accuracy
    FOR rec IN
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = target_schema
          AND table_name = target_table
    LOOP
        IF query <> '' THEN
            query := query || ' UNION ALL ';
        END IF;

        -- 3. Fixed FROM clause to cleanly handle schema-qualified names using format() %I
        query := query || format(
            'SELECT %L::text AS column, %L::text AS dtype, %L::text AS row_type, ' ||
            'COUNT(*) - COUNT(%I) AS null_count, COUNT(DISTINCT %I) AS distinct_count FROM %I.%I',
            rec.column_name,
            rec.data_type,
            CASE WHEN rec.is_nullable = 'YES' THEN 'Nullable' ELSE 'NOT NULL' END,
            rec.column_name,
            rec.column_name,
            target_schema,
            target_table
        );
    END LOOP;

    -- 4. Added a safety check to make sure columns were actually found
    IF query = '' THEN
        RAISE EXCEPTION 'Table %. % not found or has no columns.', target_schema, target_table;
    END IF;

    EXECUTE 'DROP TABLE IF EXISTS table_profile; CREATE TEMP TABLE table_profile AS ' || query;
END $$;

-- View the results from the temp table
SELECT * FROM table_profile;


DO $$
DECLARE
    rec RECORD;
    query TEXT := '';
    -- 1. Separated schema and table to fix the lookup bug
    target_schema TEXT := 'staging';
    target_table TEXT := 'stg_institutions';
BEGIN
    -- 2. Added schema filtering to ensure accuracy
    FOR rec IN
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = target_schema
          AND table_name = target_table
    LOOP
        IF query <> '' THEN
            query := query || ' UNION ALL ';
        END IF;

        -- 3. Fixed FROM clause to cleanly handle schema-qualified names using format() %I
        query := query || format(
            'SELECT %L::text AS column, %L::text AS dtype, %L::text AS row_type, ' ||
            'COUNT(*) - COUNT(%I) AS null_count, COUNT(DISTINCT %I) AS distinct_count FROM %I.%I',
            rec.column_name,
            rec.data_type,
            CASE WHEN rec.is_nullable = 'YES' THEN 'Nullable' ELSE 'NOT NULL' END,
            rec.column_name,
            rec.column_name,
            target_schema,
            target_table
        );
    END LOOP;

    -- 4. Added a safety check to make sure columns were actually found
    IF query = '' THEN
        RAISE EXCEPTION 'Table %. % not found or has no columns.', target_schema, target_table;
    END IF;

    EXECUTE 'DROP TABLE IF EXISTS table_profile; CREATE TEMP TABLE table_profile AS ' || query;
END $$;

-- View the results from the temp table
SELECT * FROM table_profile;


DO $$
DECLARE
    rec RECORD;
    query TEXT := '';
    -- 1. Separated schema and table to fix the lookup bug
    target_schema TEXT := 'staging';
    target_table TEXT := 'stg_macro';
BEGIN
    -- 2. Added schema filtering to ensure accuracy
    FOR rec IN
        SELECT column_name, data_type, is_nullable
        FROM information_schema.columns
        WHERE table_schema = target_schema
          AND table_name = target_table
    LOOP
        IF query <> '' THEN
            query := query || ' UNION ALL ';
        END IF;

        -- 3. Fixed FROM clause to cleanly handle schema-qualified names using format() %I
        query := query || format(
            'SELECT %L::text AS column, %L::text AS dtype, %L::text AS row_type, ' ||
            'COUNT(*) - COUNT(%I) AS null_count, COUNT(DISTINCT %I) AS distinct_count FROM %I.%I',
            rec.column_name,
            rec.data_type,
            CASE WHEN rec.is_nullable = 'YES' THEN 'Nullable' ELSE 'NOT NULL' END,
            rec.column_name,
            rec.column_name,
            target_schema,
            target_table
        );
    END LOOP;

    -- 4. Added a safety check to make sure columns were actually found
    IF query = '' THEN
        RAISE EXCEPTION 'Table %. % not found or has no columns.', target_schema, target_table;
    END IF;

    EXECUTE 'DROP TABLE IF EXISTS table_profile; CREATE TEMP TABLE table_profile AS ' || query;
END $$;

-- View the results from the temp table
SELECT * FROM table_profile;

/*
 * 2. COMPANY CROSSWALK
 */


SELECT
	sc.match_method ,
	sc.category ,
	sum(sc.complaint_count ) AS complaints,
	round(
		100.0 * sum(complaint_count)
			/ nullif(sum(sum(complaint_count)) OVER (), 0), 2
			) AS pct_all_counts
FROM staging.stg_crosswalk sc
GROUP BY match_method, category
ORDER BY complaints DESC;

/*
 * CONSOLIDATION
 */

WITH annual_reporting_date AS (
	SELECT
		dd.calendar_year ,
		MAX(dd.date_key ) AS date_key,
		max(dd.calendar_date ) AS reporting_date
	FROM mart.dim_date dd
	WHERE dd.calendar_year BETWEEN 2008 AND 2026
		AND (
			(dd.calendar_year < 2026 AND dd.is_quarter_end = TRUE
			AND dd.calendar_quarter = 4)
			OR dd.calendar_year = 2026
			)
		AND EXISTS (
			SELECT 1
			FROM mart.fact_bank_quarter fbq
			WHERE fbq.date_key = dd.date_key
		)
		GROUP BY dd.calendar_year
		),
annual_counts AS (
	SELECT
		r.calendar_year ,
		r.reporting_date,
		count(DISTINCT fbq.bank_key ) AS reporting_banks
	FROM annual_reporting_date r
	JOIN mart.fact_bank_quarter fbq
		ON fbq.date_key = r.date_key
	JOIN mart.dim_bank db
		ON db.bank_key = fbq.bank_key
	WHERE db.bank_entity_type = 'charter'
	GROUP BY r.calendar_year , r.reporting_date )
SELECT *
FROM annual_counts
ORDER BY calendar_year;


WITH reporting_dates AS (
    SELECT
        2008 AS period_year,
        'Start'::text AS period_label,
        (
            SELECT MAX(d.date_key)
            FROM mart.dim_date d
            WHERE d.calendar_year = 2008
              AND d.calendar_quarter = 4
              AND d.is_quarter_end = TRUE
              AND EXISTS (
                  SELECT 1 FROM mart.fact_bank_quarter f WHERE f.date_key = d.date_key
              )
        ) AS date_key
    UNION ALL
    SELECT
        2026 AS period_year,
        'End (latest available)'::text AS period_label,
        (
            SELECT MAX(d.date_key)
            FROM mart.dim_date d
            WHERE d.calendar_year = 2026
              AND EXISTS (
                  SELECT 1 FROM mart.fact_bank_quarter f WHERE f.date_key = d.date_key
              )
        ) AS date_key
),
bank_assets AS (
    SELECT
        r.period_label,
        r.period_year,
        r.date_key,
        b.bank_key,
        SUM(f.total_assets) AS assets
    FROM reporting_dates r
    JOIN mart.fact_bank_quarter f ON f.date_key = r.date_key
    JOIN mart.dim_bank b ON b.bank_key = f.bank_key
    WHERE b.bank_entity_type = 'charter'
    GROUP BY r.period_label, r.period_year, r.date_key, b.bank_key
),
ranked AS (
    SELECT
        *,
        ROW_NUMBER() OVER ( PARTITION BY date_key ORDER BY assets DESC, bank_key ) AS asset_rank,
        SUM(assets) OVER ( PARTITION BY date_key ) AS industry_assets
    FROM bank_assets
)
SELECT
    period_label,
    period_year,
    MAX(industry_assets) AS industry_assets_source_units,
    ROUND( 100.0 * SUM(assets) FILTER (WHERE asset_rank <= 10) / NULLIF(MAX(industry_assets), 0), 2 ) AS top_10_asset_share_pct,
    ROUND( 100.0 * SUM(assets) FILTER (WHERE asset_rank <= 100) / NULLIF(MAX(industry_assets), 0), 2 ) AS top_100_asset_share_pct,
    COUNT(*) AS reporting_banks
FROM ranked
GROUP BY period_label, period_year, date_key
ORDER BY date_key;

WITH snapshot_dates AS (
	SELECT
		dd.calendar_year ,
		max(dd.calendar_date ) AS snapshot_date,
		max(dd.date_key ) AS date_key
	FROM mart.dim_date dd
	WHERE dd.calendar_year BETWEEN 2008 AND 2026
		AND(
			(dd.calendar_quarter < 2026
			AND dd.calendar_quarter = 4
			AND dd.is_quarter_end = TRUE)
			OR dd.calendar_year = 2026
			)
		AND EXISTS (
			SELECT 1
			FROM mart.fact_bank_quarter fbq
			WHERE fbq.date_key = dd.date_key
			)
		GROUP BY dd.calendar_year
),
reporting_banks AS (
	SELECT DISTINCT
		s.calendar_year ,
		s.snapshot_date ,
		fbq.bank_key
	FROM snapshot_dates s
	JOIN mart.fact_bank_quarter fbq
		ON fbq.date_key = s.date_key
	JOIN mart.dim_bank db
		ON db.bank_key = fbq.bank_key
	WHERE db.bank_entity_type = 'charter'
),
exits AS (
	SELECT
		prev.calendar_year  AS exit_from_year,
		curr.calendar_year AS exit_to_year,
		prev.snapshot_date AS previous_snapshot,
		curr.snapshot_date AS curr_snapshot,
		prev.bank_key
	FROM reporting_banks prev
	JOIN reporting_banks curr
		ON curr.calendar_year = prev.calendar_year + 1
		AND curr.bank_key <> prev.bank_key
	WHERE NOT EXISTS (
		SELECT 1
		FROM reporting_banks new_reporting
		WHERE new_reporting.calendar_year = curr.calendar_year
			AND new_reporting.bank_key  = prev.bank_key
	)
),
classified_exits AS (
	SELECT
		e.*,
		CASE
			WHEN EXISTS(
				SELECT 1
				FROM mart.fact_failure ff
				JOIN mart.dim_date dd
				ON dd.date_key = ff.failure_date_key
				WHERE ff.bank_key = e.bank_key
					AND dd.calendar_date > e.previous_snapshot
					AND dd.calendar_date <= e.curr_snapshot
			)
			THEN 'Linked recorded failure'
			ELSE 'No linked failure: possible merger'
		END AS exit_classification
	FROM exits e
)
SELECT
	exit_from_year,
	exit_to_year,
	exit_classification,
	count(*) AS banks_exiting
FROM classified_exits
GROUP BY
	classified_exits.exit_from_year ,
	classified_exits.exit_to_year ,
	classified_exits.exit_classification
ORDER BY classified_exits.exit_from_year , classified_exits.exit_classification ;
