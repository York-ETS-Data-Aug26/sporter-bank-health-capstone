Repository for fdic, cfpb, and fred records

## Setup

Create a `raw_data` folder inside the repository and place data there (8 files)

In terminal
```commandline
pip install sqlalchemy
```

```terminaloutput
raw_data/
    cfpb_complaints.csv
    fdic_failures.csv
    fdic_financials.csv
    fdic_institutions.json
    fred_DGS10.csv
    fred_FEDFUNDS.csv
    fred_MORTGAGE30US.csv
    fred_UNRATE.csv
    fred_UNRATE.csv
```

The raw files are intentionally ignored.

To run cleaning and sql scripts
```commandline
docker compose up -d
python python/01_clean.py


docker compose exec db psql -U capstone -d bank_health -f /sql/02_build.sql
docker compose exec db psql -U capstone -d bank_health -f /sql/03_build.sql

// analysis queries
docker compose exec db psql -U capstone -d bank_health -f /sql/05_build.sql 
```

Running `01_clean.py` will product staging_tables in csv format in `cleaned_data` folder , as well as directly to the staging schema, and product table_profiles.

You should not have to change anything.

When done with the database
```commandline
docker compose down
```

OR when you want to remove all data from the database
```commandline
docker compose down -v
```

## PowerBI Desktop

For connecting to the database

```commandline
      POSTGRES_USER: capstone
      POSTGRES_PASSWORD: capstone
      POSTGRES_DB: bank_health
      ports: "5432:5432"
```