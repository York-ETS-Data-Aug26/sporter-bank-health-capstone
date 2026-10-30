import os
from pathlib import Path

import numpy as np
import pandas as pd

from sqlalchemy import create_engine, inspect
from sqlalchemy.schema import CreateSchema

db_url = os.getenv("DATABASE_URL", "postgresql://capstone:capstone@localhost:5432/bank_health")
base = Path("./raw_data")
c_base = Path("./cleaned_data")
c_base.mkdir(parents=True, exist_ok=True)

missing_values = [
    '', 'NA', 'N/A', 'NaN', 'null', 'None', '-', 'NULL', 'nan', 'na'
]

thou_amounts = [
    'asset', 'dep', 'depdom', 'depunins', 'netinc', 'eq', 'rbct1j',
    'lnlsnet', 'lnlsgr', 'lnre', 'lnatres', 'nclnls', 'p3asset', 'p9asset',
    'elnatr', 'sc', 'intinc', 'eintexp', 'nonii', 'nonix', 'numemp', 'offdom'
]

ratios = [
    'roa', 'roe', 'eqv', 'nclnlsr', 'nperfv', 'nimy'
]

ytd_fields = [
    'netinc', 'intinc', 'eintexp', 'nonii', 'nonix', 'elnatr'
]

def get_engine():
    return create_engine(db_url)


def create_schema(engine):
    with engine.connect() as conn:
        inspector = inspect(engine)
        if 'staging' not in inspector.get_schema_names():
            conn.execute(CreateSchema('staging'))
            conn.commit()


def normalize_columns(df):
    df.columns = (
        df.columns.astype(str)
        .str.strip()
        .str.lower()
        .str.replace(r"[^a-z0-9+]", "_", regex=True)
        .str.strip("_")
    )
    return df


def clean_blank_strings(df):
    return df.replace(r'^\s*$', np.nan, regex=True)


def clean_text_columns(df, columns):
    for col in columns:
        if col in df.columns:
            df[col] = df[col].astype(str).str.strip()
            df[col] = df[col].replace('', np.nan)
    return df


def delete_file(profile_table='Profile'):
    profile_path = c_base / f"{profile_table}.csv"

    # will delete since mode is set to append later
    if profile_path.is_file():
        profile_path.unlink()
        print("File deleted successfully.")

def save_clean_table(df, new_table_name, profile_table='Profile'):

    data_path = c_base / f"{new_table_name}.csv"
    profile_path = c_base / f"{profile_table}.csv"

    # Check if files exist to determine if headers are needed
    data_header = not os.path.exists(data_path)
    profile_header = not os.path.exists(profile_path)

    # Append data table
    df.to_csv(data_path, index=False, mode='a', header=data_header)

    profile = pd.DataFrame({
        "table_name": new_table_name,
        "column_name": df.columns,
        "dtype": [str(df[col].dtype) for col in df.columns],
        "null_count": [int(df[col].isnull().sum()) for col in df.columns],
        "distinct_count": [int(df[col].nunique(dropna=True)) for col in df.columns],
        "null_pct": [round(df[col].isna().mean() * 100, 2) for col in df.columns]
    })

    # Append profile table
    profile.to_csv(profile_path, index=False, mode='a', header=profile_header)

    print(f"Saved {new_table_name}: {len(df):,} rows")
    return df