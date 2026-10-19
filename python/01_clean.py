import os
import json
import re

from pathlib import Path

import numpy as np
import pandas as pd
from sqlalchemy import create_engine, inspect
from sqlalchemy.schema import CreateSchema

DB_URL = os.getenv("DATABASE_URL", "postgresql://capstone:capstone@localhost:5432/bank_health")
BASE = Path("./raw_data")
C_BASE = Path("./cleaned_data")
C_BASE.mkdir(parents=True, exist_ok=True)

MISSING_VALUES = [
    '', 'NA', 'N/A', 'NaN', 'null', 'None', '-', 'NULL', 'nan', 'na'
]

THOU_AMOUNTS = [
    'asset', 'dep', 'depdom', 'depunins', 'netinc', 'eq', 'rbct1j',
    'lnlsnet', 'lnlsgr', 'lnre', 'lnatres', 'nclnls', 'p3asset', 'p9asset',
    'elnatr', 'sc', 'intinc', 'eintexp', 'nonii', 'nonix', 'numemp', 'offdom'
]

RATIOS = [
    'roa', 'roe', 'eqv', 'nclnlsr', 'nperfv', 'nimy'
]

YTD_FIELDS = [
    'netinc', 'intinc', 'eintexp', 'nonii', 'nonix', 'elnatr'
]

def get_engine():
    return create_engine(DB_URL)

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

def save_clean_table(df, table_name):
    df.to_csv(
        C_BASE / f"{table_name}.csv", index=False
    )

    profile = pd.DataFrame({
        "column" : df.columns,
        "dtype" : [str(df[col].dtype) for col in df.columns],
        "row_type": len(df),
        "null_count": [
            int(df[col].isnull().sum()) for col in df.columns
        ],
        "distinct_count": [
            int(df[col].nunique(dropna=True)) for col in df.columns
        ],
        "null_pct": [
            round(df[col].isna().mean() * 100, 2) for col in df.columns
        ]
    })

    profile.to_csv(C_BASE / f"{table_name}_profile.csv", index=False)

    print(f"Saved {table_name}: {len(df):,} rows")
    return df


    # macro_df.to_csv(f'{C_BASE}/cleaned_macro.csv', index=False)

def cleaned_institutions():
    print("Cleaning institutions")

    path = BASE / 'fdic_institutions.json'
    if not path.exists():
        raise FileNotFoundError(f'File {path} not found')

    with open(path, 'r', encoding='utf-8') as f:
        raw_json = json.load(f)

    if isinstance(raw_json, dict):
        records = raw_json.get('data', raw_json)
    else:
        records = raw_json

    if not isinstance(records, list):
        raise ValueError(
            'Expected institution records'
        )

    records = [
        record.get('data', record)
        for record in records if isinstance(record, dict)
    ]

    df = pd.DataFrame(records)
    df = normalize_columns(df)
    df = clean_blank_strings(df)

    text_cols = [
        'cert', 'name', 'city', 'stalp', 'zip', 'bkclass',
        'namehcr', 'fed_rssd', 'webaddr', 'id'
    ]

    df = clean_text_columns(df, text_cols)

    if 'cert' not in df.columns:
        raise ValueError('No cert column present')

    invalid_cert = (df['cert'].isna() | ~df['cert'].str.fullmatch(r'\d+', na=False))

    if invalid_cert.any():
        print(f'Found invalid cert: {invalid_cert.sum()}')

    for col in ['asset', 'dep']:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce').astype('Int64')

    if 'active' in df.columns:
        active_numeric = pd.to_numeric(df['active'], errors='coerce')

        invalid_active = ( active_numeric.notna() & ~active_numeric.isin([0,1]))

        print(f'Found invalid active: {invalid_active.sum()}')

        df['active'] = active_numeric.map({1: True, 0: False}).astype('boolean')

    if 'bkclass' in df.columns:
        df['bkclass'] = df['bkclass'].str.upper()

    for col in ['estymd', 'endefymd']:
        if col in df.columns:
            date_text = df[col].astype('string').str.strip()
            date_text = date_text.replace(
                ['12/31/9999', '9999-12-31'], np.nan
            )

            df[col] = pd.to_datetime(date_text, format='%m/%d/%Y', errors='coerce')

    duplicate_cert = df['cert'].duplicated(keep=False)
    print(f'rows with duplicate cert:{duplicate_cert.sum()}')

    return save_clean_table(df, 'institutions')

def clean_financials():
    print("Cleaning financials")

    path = BASE / 'fdic_financials.csv'
    if not path.exists():
        raise FileNotFoundError(f'File {path} not found')

    df = pd.read_csv(path, dtype={'CERT': 'string', 'ID': 'string'}, low_memory=False)

    df = normalize_columns(df)
    df = clean_blank_strings(df)
    df = clean_text_columns(df, ['cert', 'id'])

    if 'cert' not in df.columns or 'repdte' not in df.columns:
        raise ValueError('No cert or repdte column present')

    invalid_cert = ~df['cert'].str.fullmatch(r'\d+', na=False)
    print(f'invalid cert values: {invalid_cert.sum()}')
    df.loc[invalid_cert, 'cert'] = np.nan

    df['repdte'] = pd.to_datetime(df['repdte'], format='%Y%m%d', errors='coerce')

    for col in THOU_AMOUNTS:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce').astype('Int64')

    for col in RATIOS:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce').astype('Float64')

    duplicate_key = df.duplicated(['cert', 'repdte'], keep=False)

    print(f'duplicate cert quarter rows: {duplicate_key.sum()}')

    df['year'] = df['repdte'].dt.year.astype('Int64')
    df['quarter'] = df['repdte'].dt.quarter.astype('Int64')

    df = df.sort_values(['cert', 'repdte']).reset_index(drop=True)

    quarter_number = df['year'] * 4 * df['quarter']
    previous_quarter_number = quarter_number.groupby(df['cert']).shift(1)

    for col in YTD_FIELDS:
        if col in df.columns:
            qtr_col_name = f'{col}_qtr'
            diff_series = df.groupby(['cert', 'year'])[col].diff()
            is_first_in_group = df.groupby(['cert', 'year']).cumcount() == 0
            df[qtr_col_name] = diff_series.where(~is_first_in_group, df[col])
    # for col in YTD_FIELDS:
    #     if col not in df.columns:
    #         continue
    #
    #     previous_ytd = df.groupby(
    #         ['cert', 'year'], dropna=False
    #     )[col].shift(1)
    #
    #     df[f'{col}_qtr'] = df[col].astype('Int64')
    #
    #     later_quarter = df['quarter'].gt(1)
    #     has_previous_quarter = ( quarter_number - previous_quarter_number).eq(1)
    #
    #     can_calculate = (
    #         later_quarter
    #         & has_previous_quarter
    #         & previous_ytd.notna()
    #         & df[col].notna()
    #     )
    #
    #     df.loc[can_calculate, f'{col}_qtr'] = (
    #         df.loc[can_calculate, col] - previous_ytd.loc[can_calculate]
    #     )
    #
    #     cannot_calculate = later_quarter & ~can_calculate
    #     df.loc[cannot_calculate, f'{col}_qtr'] = np.nan

    return save_clean_table(df, 'financials')

def clean_failures():
    print("Cleaning failures")

    path = BASE / 'fdic_failures.csv'
    if not path.exists():
        raise FileNotFoundError(f'File {path} not found')

    df = pd.read_csv(path, dtype='string', na_values=MISSING_VALUES, keep_default_na=True, low_memory=False)

    df = normalize_columns(df)
    df = clean_blank_strings(df)

    text_cols = ['cert', 'name', 'city', 'pstalp', 'cityst', 'restype', 'restype1',
                 'chclass1', 'chclass', 'savr', 'fund', 'bidname', 'bidcity',
                 'bidstate', 'fin', 'bstatus', 'closcd', 'termi', 'fsl_prog',
                 'bankno', 'url', 'comments', 'id']

    text_cols = [c for c in text_cols if c in df.columns]
    df = clean_text_columns(df, text_cols)

    if 'cert' in df.columns:
        invalid_cert = df['cert'].notna() & ~df['cert'].str.fullmatch(r'\d+', na=False)
        print(f'Invalid cert values: {invalid_cert.sum()}')
        df.loc[invalid_cert, 'cert'] = np.nan

    for col in ['faildate', 'resdate']:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], format='%m/%d/%Y', errors='coerce')

    for col in ['costmostrecentasof', 'ptrdate', 'brdate']:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], format='%Y-%m-%d', errors='coerce')

    if 'faildate' in df.columns and 'failyr' in df.columns:
        derived_year = df['faildate'].dt.year.astype('Int64')
        original_year = pd.to_numeric(df['failyr'], errors='coerce').astype('Int64')

        year_mismatch = (
            derived_year.notna()
            & original_year.notna()
            & derived_year.ne(original_year)
        )
        print(f'failyr mismatches: {year_mismatch.sum()}')

        df['failyr_source'] = df['failyr']
        df['failyr'] = derived_year

    for col in ['qbfaset', 'qbfasset', 'qbfdep', 'cost', 'uninsdep']:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce').astype('Float64')

    if {'cert', 'faildate'}.issubset(df.columns):
        duplicate_key = df.duplicated(['cert', 'faildate'], keep=False)
        print(f'rows with duplicate cert and faildate: {duplicate_key.sum()}')

    return save_clean_table(df, 'failures')

def clean_complaints():
    print("Cleaning complaints")

    path = BASE / 'cfpb_complaints.csv'
    if not path.exists():
        raise FileNotFoundError(f'File {path} not found')

    df = pd.read_csv(path, dtype='string', na_values=MISSING_VALUES, keep_default_na=True, low_memory=False)

    df = normalize_columns(df)
    df = clean_blank_strings(df)

    text_cols = [
        'product', 'sub_product', 'issue', 'sub_issue','company', 'company_public_response',
        'company_response_to_consumer', 'timely_response', 'state', 'zip_code', 'tags', 'submitted_via'
    ]

    df = clean_text_columns(df, text_cols)

    if 'complaint_id' in df.columns:
        df['complaint_id'] = pd.to_numeric(df['complaint_id'], errors='coerce').astype('Int64')


    for col in ['date_received', 'date_sent_to_company']:
        if col in df.columns:
            df[col] = pd.to_datetime(df[col], format='%Y-%m-%d', errors='coerce')

    if 'state' in df.columns:
        df['state'] = df['state'].str.upper()

    if 'product' in df.columns:
        df['product_original'] = df['product']

        product_map = {
            'Checking or savings account': 'Bank Account',
            'Mortgage': 'Mortgage',
            'Credit Card': 'Credit Card',
            'Payday loan, title loan, personal loan, or advance loan': 'Loan',
            'Vehicle loan or lease': 'Vehicle Loan',
        }

        df['harmonized_product'] = df['product'].replace(product_map)

    if 'complaint_id' in df.columns:
        print('duplicate complaints id', df['complaint_id'].duplicated(keep=False).sum())

    return save_clean_table(df,'complaints')

def crosswalk_table(complaints_df, instiution_df):
    def normalize_name(text):
        if pd.isna(text):
            return ''
        text = str(text).upper()
        text = text.replace('&', 'AND')
        text = re.sub(r'[^\w\s]', '', text)
        text = re.sub(r'\s+', ' ', text).strip()
        return text

    #suffix list
    SUFFIXES = {
     'INC',
     'CORP',
     'CORPORATION',
     'NA',
     'N A',
     'N.A.',
     'FINANCIAL',
     'BANCORP',
     'HOLDINGS',
     'BANK',
     'COMPANY',
     'CO',
     'LLC',
     'LP',
     'L P',
     'L.P.',
     'SAVINGS',
     'BCORP',
     'THE'
     'ASSOCIATION',
    }

    def strip_suffixes(text):
        words = text.split()
        cleaned = [w for w in words if w not in SUFFIXES]
        return ' '.join(cleaned)

    # manual override
    MANUAL_OVERRIDES = {
        'CHASE': 'JPMORGAN CHASE BANK NATIONAL ASSOCIATION',
        'BOA': 'BANK OF AMERICA NATIONAL ASSOCIATION',
        'WELLS FARGO': 'WELLS FARGO BANK NATIONAL ASSOCIATION',
        'JPMORGAN CHASE & CO': 'JPMORGAN CHASE AND CO',
        'CAPITAL ONE FINANCIAL CORPORATION': 'CAPITAL ONE FINANCIAL CORPORATION',
    }

    def categorize_unmatched(company_name):
         name = str(company_name).upper()
         if any(
         kw in name for kw in['CREDIT UNION', 'FCU', 'CU ', 'FEDERAL CREDIT', 'FEDERAL CREDIT UNION']
         ):
             return 'credit union'
         elif any(
             kw in name for kw in ['CREDIT BUREAU', 'CREDIT REPORT', 'EQUIFAX', 'EXPERIAN', 'TRANSUNION']
         ): return 'credit bureau'
         elif any (
             kw in name for kw in ['AUTO FINANCE', 'AUTOMOTIVE FINANCE', 'MOTOR CREDIT', 'CAR FINANCE', 'VEHICLE FINANCE']
         ): return 'auto finance'
         elif any(
             kw in name for kw in ['FINTECH', 'PAYMENT', 'PAYMENTS', 'PAYPAL', 'VENMO', 'STRIPE', 'SQUARE', 'CASH APP']
         ): return 'fintech or payments'
         elif any(
             kw in name for kw in ['MORTGAGE', 'HOME LOAN', 'LENDING', 'LENDER', 'LOAN', 'LOANS']
         ): return 'mortgage or lender'
         elif any(
             kw in name for kw in ['FINANCIAL', 'FUNDING', 'CAPITAL', 'CREDIT']
         ): return 'other lender'
         else:
            return 'unknown'

    # normalizing from step 1 of assignment
    complaints_df['norm_company'] = complaints_df['company'].apply(normalize_name)
    instiution_df['norm_name'] = instiution_df['name'].apply(normalize_name)

    # complaints df names
    complaint_counts = (
        complaints_df.groupby('company').size().reset_index(name='complaint_count')
    )
    crosswalk = complaints_df[['company', 'norm_company']].drop_duplicates().copy()
    crosswalk = crosswalk.merge(complaint_counts, on='company', how='left')

    # Initialize targeting columns
    crosswalk['CERT'] = None
    crosswalk['Matched_FDIC_Name'] = None
    crosswalk['NAMEHCR'] = None
    crosswalk['match_method'] = 'unmatched'
    crosswalk['category'] = None

    # hoping for exact
    exact_map = (
        instiution_df[['norm_name', 'cert', 'name', 'namehcr']]
        .drop_duplicates(subset=['norm_name'])
        .set_index('norm_name')
    )

    crosswalk['cert'] = crosswalk['norm_company'].map(exact_map['cert'])
    crosswalk['Matched_FDIC_Name'] = crosswalk['norm_company'].map(
    exact_map['name']
    )
    crosswalk['namehcr'] = crosswalk['norm_company'].map(exact_map['namehcr'])
    crosswalk.loc[crosswalk['CERT'].notna(), 'match_method'] = 'exact'

    #suffix strip
    instiution_df['clean_suffix'] = instiution_df['norm_name'].apply(strip_suffixes)
    crosswalk['clean_suffix'] = crosswalk['norm_company'].apply(strip_suffixes)

    suffix_map = (
         instiution_df[['clean_suffix', 'cert', 'name', 'namehcr']]
        .drop_duplicates(subset=['clean_suffix'])
        .set_index('clean_suffix')
    )

    mask_unmatched = crosswalk['match_method'] == 'unmatched'
    rule_cert = crosswalk.loc[mask_unmatched, 'clean_suffix'].map(
     suffix_map['cert']
    )
    rule_name = crosswalk.loc[mask_unmatched, 'clean_suffix'].map(
     suffix_map['name']
    )
    rule_hcr = crosswalk.loc[mask_unmatched, 'clean_suffix'].map(
     suffix_map['namehcr']
    )

    valid_rule = mask_unmatched & pd.notna(rule_cert)
    crosswalk.loc[valid_rule, 'cert'] = rule_cert[valid_rule]
    crosswalk.loc[valid_rule, 'Matched_FDIC_Name'] = rule_name[valid_rule]
    crosswalk.loc[valid_rule, 'namehcr'] = rule_hcr[valid_rule]
    crosswalk.loc[valid_rule, 'match_method'] = 'rule'

   #overriding
    mask_unmatched = crosswalk['match_method'] == 'unmatched'
    for idx in crosswalk[mask_unmatched].index:
        comp = crosswalk.loc[idx, 'norm_company']
        if comp in MANUAL_OVERRIDES:
            target_name = MANUAL_OVERRIDES[comp]
            match_row = instiution_df[instiution_df['name'] == target_name]
            if not match_row.empty:
                crosswalk.loc[idx, 'cert'] = match_row.iloc[0]['cert']
                crosswalk.loc[idx, 'Matched_FDIC_Name'] = match_row.iloc[0]['name']
                crosswalk.loc[idx, 'namehcr'] = match_row.iloc[0]['namehcr']
                crosswalk.loc[idx, 'match_method'] = 'manual'

    # still unmatched at this point
    mask_still_unmatched = crosswalk['match_method'] == 'unmatched'
    crosswalk.loc[mask_still_unmatched, 'category'] = crosswalk.loc[
        mask_still_unmatched, 'company'
    ].apply(categorize_unmatched)

    # For matched entities, set category to bank
    crosswalk.loc[crosswalk['match_method'] != 'unmatched', 'category'] = 'bank'

    # Finalize company_crosswalk table layout
    company_crosswalk = crosswalk[
     [
     'company',
     'cert',
     'Matched_FDIC_Name',
     'namehcr',
     'match_method',
     'category',
     'complaint_count',
    ]
    ]
    total_complaints = company_crosswalk['complaint_count'].sum()
    shares = (
          company_crosswalk.groupby(['match_method', 'category'])['complaint_count']
    .sum()
    .reset_index()
    )
    shares['share_pct'] = (shares['complaint_count'] / total_complaints) * 100

    print('--- Complaint Coverage Shares ---')
    print(shares.sort_values(by='complaint_count', ascending=False))

    return company_crosswalk
def clean_macro():
    print('Cleaning and Aliging FRED Series')

    files_to_use = {
        'FEDFUNDS': BASE / "fred_FEDFUNDS.csv",
        'UNRATE': BASE / 'fred_UNRATE.csv',
        'MORTGAGE30US': BASE / 'fred_MORTGAGE30US.csv',
        'DGS10': BASE / 'fred_DGS10.csv',
    }

    quartelry_series = []

    for series, path in files_to_use.items():
        if not path.exists():
            raise FileNotFoundError(f'File not found: {path}')

        df = pd.read_csv(path)
        df = normalize_columns(df)
        df = clean_blank_strings(df)

        if 'observation_date' not in df.columns:
            raise ValueError(f' {path.name} does not contain observation_date')

        df['observation_date'] = pd.to_datetime(df['observation_date'], format='%Y-%m-%d', errors='coerce')

        value_col = series.lower()

        if value_col not in df.columns:
            candidates = [
                c for c in df.columns if c != 'observation_date'
            ]
            if len(candidates) != 1:
                raise ValueError(f'Cannot identity value column in {path.name}: {candidates}')
            value_col = candidates[0]

        df[value_col] = pd.to_numeric(df[value_col], errors='coerce').astype('Float64')

        df = df.dropna(subset=['observation_date'])

        quartelry = (
            df.set_index('observation_date')[[value_col]]
            .sort_index()
            .resample('QE')
            .mean()
        )

        quartelry = quartelry.rename(columns={value_col: series.lower()})
        quartelry_series.append(quartelry)

    macro_table = pd.concat(quartelry_series, axis=1, join='outer', sort=False).reset_index()

    macro_table['quarter'] = (
        macro_table['observation_date']
        .dt.to_period('Q')
        .astype('string')
    )

    macro_table = macro_table[
        ['quarter', 'observation_date', 'fedfunds', 'unrate', 'mortgage30us', 'dgs10']
    ]

    return save_clean_table(macro_table, 'macro')

def run_pipeline():
    engine = get_engine()

    create_schema(engine)

    inst_df = cleaned_institutions()
    fin_df = clean_financials()
    fail_df = clean_failures()
    comp_df = clean_complaints()
    cw_df = crosswalk_table(comp_df, inst_df)
    macro_df = clean_macro()

    print("Loading clean tables into PostgreSQL")

    inst_df.to_sql('stg_institutions', engine, schema= 'staging',if_exists='replace', index=False)
    fin_df.to_sql('stg_financials', engine, schema= 'staging',if_exists='replace', index=False)
    fail_df.to_sql('stg_failures', engine, schema= 'staging', if_exists='replace', index=False)
    comp_df.to_sql('stg_complaints', engine,schema= 'staging',  if_exists='replace', index=False)
    cw_df.to_sql('stg_crosswalk', engine, schema= 'staging', if_exists='replace', index=False)
    macro_df.to_sql('stg_macro', engine, schema= 'staging',if_exists='replace', index=False)
    return f'Cleaning and loading complete.'

if __name__ == '__main__':
    run_pipeline()