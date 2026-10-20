## Directed Analysis

1. Data quality


All information is coming from the cleaning Layer. SQL for the null counts, distinct counts, etc.. can be found in ./sql/05_build.sql

Complaints: Most of the values stayed the same in this column with dates being changed


complaint_id | int-8,
date_received |date,
product  | text,
sub_product | text,
issue| text,
sub_issue | text,
company_public_response | text,
company | text,
state | varchar(2),
zip_code | text,
tags | text,
submitted_via | text,
date_sent_to_company | date,
company_response_to_consumer | text,
timely_response | bool,
product_original | text,
harmonized_product | text

Failures:

Numeric Columns : Those described to be in thousand amounts were converted to numeric columns
Identifier Columns: Those said to have been identifers were left as text as to keep that formatting. Still trimmed/cleaned

Financials:
Numeric Columns : Those described to be in thousand amounts were converted to numeric columns
Identifier Columns: Those said to have been identifers were left as text as to keep that formatting. Still trimmed/cleaned

Institutions:
Numeric Columns : Those described to be in thousand amounts were converted to numeric columns
Identifier Columns: Those said to have been identifers were left as text as to keep that formatting. Still trimmed/cleaned


FRED files (macro):
observation_date was changed to date, while the other values, were changed to numeric as I wanted to keep them in decimal form for percentages

**zip_code** : Was tricky as it didn't had strange values and very hard to clean but was also kept as text to perform regex
**date_columns** : Anything described with date formatting was turned into a date
**ratios** : Numeric data type: though it was (3,2) in order to preserve the percentage already in it.
**thou_columns** : Those described as thousand format weren't multiplied and were kept the same until further evaluation in powerBI desktop.

2. The crosswalk (refer to .sql/05_build.sql)
```terminaloutput

match_method category           complaints          pct_all_counts
unmatched	unknown	            511638	            47.48
rule	    bank	            218222	            20.25
unmatched	other lender	    178739	            16.59
unmatched	credit bureau	    60762	            5.64
unmatched	mortgage or lender	58267	            5.41
unmatched	credit union	    39102	            3.63
unmatched	fintech or payments	6459	            0.60
unmatched	auto finance	    4435	            0.41
```

Share contributed to bank : 20.25
Method : rule

Unmatched remainder outlier was unknown, with other lender, credit bureau, mortgage or lender, credit union, fintech payments , and then autofinance.
With the amount of unknowns, since cleaning will vary, the claim to complaints is that they could not be accurate.
With it matching on name, cert, holding_company, things could very well not line up.


3. Consolidation

```terminaloutput
calendar_year   reporting_date  reporting_banks
2008	        2008-12-31	    6958
2009	        2009-12-31	    6721
2010	        2010-12-31	    6436
2011	        2011-12-31	    6196
2012	        2012-12-31	    5974
2013	        2013-12-31	    5746
2014	        2014-12-31	    5497
2015	        2015-12-31	    5239
2016	        2016-12-31	    5025
2017	        2017-12-31	    4829
2018	        2018-12-31	    4613
2019	        2019-12-31	    4413
2020	        2020-12-31	    4252
2021	        2021-12-31	    4106
2022	        2022-12-31	    3980
2023	        2023-12-31	    3877
2024	        2024-12-31	    3793
2025	        2025-12-31	    3662
2026	        2026-06-30	    3569
```

TOP 10
```terminaloutput

period_label          |period_year|industry_assets_source_units|top_10_asset_share_pct|top_100_asset_share_pct|reporting_banks|
----------------------+-----------+----------------------------+----------------------+-----------------------+---------------+
Start                 |       2008|             13384005271.000|                 49.41|                  79.47|           6958|
End (latest available)|       2026|             25753624486.000|                 55.68|                  85.04|           3569|
```

Merger?

I would assume there were mergers in the history of these files. With the `industry_assets_source_units` column jumping more than 100% I would assume
that bigger banks or holding companies overtook smaller banks. Though there's no dedicated merger column, the holding_company column seems to be a way to
view those changes in company_hands.