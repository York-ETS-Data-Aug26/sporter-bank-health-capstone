import json
import re

from helper import *

base = Path("./raw_data")

def cleaned_institutions():
    print("Cleaning institutions")

    path = base / 'fdic_institutions.json'
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

        invalid_active = (active_numeric.notna() & ~active_numeric.isin([0, 1]))

        print(f'Found Invalid Active: {invalid_active.sum()}')

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
    print(f'Rows with Duplicate Certs:{duplicate_cert.sum()}')

    return save_clean_table(df, 'institutions')

def clean_financials():
    print("Cleaning financials")

    path = base / 'fdic_financials.csv'
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

    df['quarter_date'] = pd.to_datetime(df['repdte'], format='%Y%m%d', errors='coerce')
    df['year'] = pd.to_datetime(df['quarter_date']).dt.year
    df['quarter'] = pd.to_datetime(df['quarter_date']).dt.quarter

    for col in thou_amounts:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce').astype('Int64')

    for col in ratios:
        if col in df.columns:
            df[col] = pd.to_numeric(df[col], errors='coerce').astype('Float64')

    duplicate_key = df.duplicated(['cert', 'repdte'], keep=False)

    print(f'duplicate cert quarter rows: {duplicate_key.sum()}')

    df = df.sort_values(by=['cert', 'quarter_date'])

    for field in ytd_fields:
        if field in df.columns:
            ytd_col = f"{field}_ytd"
            qtr_col = f"{field}_qtr"
            df[ytd_col] = df[field]

            df[qtr_col] = df.groupby(['cert', 'year'])[ytd_col].diff()

            first_row = ~df.duplicated(subset=['cert', 'year'])

            df.loc[first_row, qtr_col] = df.loc[first_row, ytd_col]

    df.sort_values(by='repdte', inplace=True, ascending=True)

    df['repdte'] = pd.to_datetime(df['repdte'], format='%Y%m%d', errors='coerce')

    return save_clean_table(df, 'financials')

def clean_failures():
    print("Cleaning failures")

    path = base / 'fdic_failures.csv'
    if not path.exists():
        raise FileNotFoundError(f'File {path} not found')

    df = pd.read_csv(path, dtype='string', na_values=missing_values, keep_default_na=True, low_memory=False)

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

    path = base / 'cfpb_complaints.csv'
    if not path.exists():
        raise FileNotFoundError(f'File {path} not found')

    df = pd.read_csv(path, dtype='string', na_values=missing_values, keep_default_na=True, low_memory=False)

    df = normalize_columns(df)
    df = clean_blank_strings(df)

    text_cols = [
        'product', 'sub_product', 'issue', 'sub_issue', 'company', 'company_public_response',
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

        product_map = {
            'Checking or savings account': 'Bank Account',
            'Mortgage': 'Mortgage',
            'Credit card': 'Credit Card',
            'Payday loan, title loan, personal loan, or advance loan': 'Loan',
            'Vehicle loan or lease': 'Vehicle Loan',
        }

        df['harmonized_product'] = df['product'].replace(product_map)

    if 'complaint_id' in df.columns:
        print('Duplicate Complaints ID', df['complaint_id'].duplicated(keep=False).sum())

    return save_clean_table(df,'complaints')

def crosswalk(complaints_df, institution_df):
    manual_overrides = {
        "CITIBANK, N.A.": "CITIGROUP INC",
        "PNC Bank N.A.": "PNC FINL SERVICES GROUP INC",
        "BBVA FINANCIAL CORPORATION": "PNC FINL SERVICES GROUP INC",  # merged into PNC
        "AMERICAN EXPRESS COMPANY": "AMERICAN EXPRESS CO",
        "Comerica": "COMERICA INC",
        "SANTANDER HOLDINGS USA, INC.": "BANCO SANTANDER SA",
        "M&T BANK CORPORATION": "M&T BANK CORP",
        "FIFTH THIRD FINANCIAL CORPORATION": "FIFTH THIRD BCORP",
        "TD BANK US HOLDING COMPANY": "TORONTO-DOMINION BANK THE",
        "Bread Financial Holdings, Inc.": "COMENITY BANK",
        "UNITED SERVICES AUTOMOBILE ASSOCIATION": "USAA FEDERAL SAVINGS BANK",
        "HSBC NORTH AMERICA HOLDINGS INC.": "HSBC BANK USA NATIONAL ASSOCIATION",
        "Flagstar Bank, N.A.": "FLAGSTAR BANK NATIONAL ASSOCIATION",
    }

    suffixes = {"INCORPORATED", "INC", "CORPORATION", "CORP", "COMPANY", "CO", "LIMITED", "LTD", "LLC",
                "NATIONAL ASSOCIATION", "N A", "NA", "FSB", "SSB", "SB", "BANCORPORATION", "BANCSHARES",
                "HOLDINGS", "HOLDING", "GROUP", "FINANCIAL", "FINANCIALS", "THE", "AND"}

    def normalize(name):
        if pd.isna(name):
            return ""

        name = str(name).upper().replace("&", " AND ")
        name = re.sub(r"\bN\s*\.?\s*A\.?\b", " NA ", name)
        name = re.sub(r"[^A-Z0-9 ]", " ", name)

        return " ".join(name.split())

    def strip_suffixes(name):
        words = name.split()

        while words and words[-1] in suffixes:
            words.pop()

        return " ".join(words)

    companies = complaints_df['company'].dropna().unique()

    result = pd.DataFrame({'company_name': companies})
    result['company_name_normalized'] = (
        result['company_name'].apply(normalize)
    )

    banks = institution_df.copy()

    banks['name_normalized'] = banks['name'].apply(normalize)
    banks['holding_normalized'] = banks['namehcr'].apply(normalize)


    name_lookup = (
        banks.dropna(subset=['cert'])
        .drop_duplicates('name_normalized')
        .set_index('name_normalized')['cert']
        .to_dict()
    )

    holding_lookup = (
        banks.dropna(subset=['cert'])
        .drop_duplicates('holding_normalized')
        .set_index('holding_normalized')['cert']
        .to_dict()
    )

    holding_company_lookup = (
        banks.dropna(subset=['cert'])
        .drop_duplicates('cert')
        .set_index('cert')['namehcr']
        .to_dict()
    )

    fdic_lookup = {**holding_lookup, **name_lookup}

    certs = []
    methods = []
    categories = []
    holding_companies = []

    for _, row in result.iterrows():
        name = row['company_name']
        normalized = row['company_name_normalized']

        cert = None
        method = 'unmatched'
        category = 'unknown'

        if normalized in fdic_lookup:
            cert = fdic_lookup[normalized]
            method = 'exact'

        if cert is None:
            stripped = strip_suffixes(normalized)

            for fdic_name, fdic_cert in fdic_lookup.items():
                if strip_suffixes(fdic_name) == stripped and stripped:
                    cert = fdic_cert
                    method = 'suffix_stripped'
                    break
        if cert is None:
            for complaint_name, fdic_name in manual_overrides.items():
                if normalize(complaint_name) == normalized:
                    cert = fdic_lookup.get(normalize(fdic_name))

                    if cert is not None:
                        method = "manual_override"
                        break

        if cert is not None:
            category = 'bank'
        else:
            upper = name.upper()

            if any(x in upper for x in
                   ['EXPERIAN', 'TRANSUNION', 'EQUIFAX']):
                category = 'credit_bureau'

            elif any(x in upper for x in
                     ['CREDIT UNION', 'FEDERAL CREDIT']):
                category = 'credit_union'
            elif any(x in upper for x in
                     ['MORTGAGE', 'SHELLPOINT', 'OCWEN', 'MR COOPER', 'NATIONSTAR', 'CARRINGTON', 'PENNYMAC', 'SERVICING',
                      'LOANCARE', 'FREEDOM MORTGAGE', 'ROCKET MORTGAGE', 'PHH MORTGAGE',]):
                category = 'mortgage_servicer'
            elif any(x in upper for x in
                     ['HYUNDAI CAPITAL', 'TOYOTA MOTOR', 'GM FINANCIAL', 'FORD MOTOR', 'ALLY FINANCIAL', 'WESTLAKE',
                      'AUTO FINANCE']):
                category = 'auto_finance'
            elif any(x in upper for x in
                     ['PAYPAL', 'CHIME', 'SOFI', 'ROBINHOOD', 'STRIPE', 'PLAID', 'AFFIRM', 'VENMO',
                      'NETSPEND', 'SQUARE', 'GREEN DOT']):
                    category = 'fintech_or_payments'
            elif any(x in upper for x in
                     ['LENDING', 'FINANCE COMPANY', 'ONEMAIN', 'LOAN', 'PAYDAY', 'CASH ADVANCE']):
                category = 'other_lender'
            elif any(x in upper for x in
                     ['BANK', 'SAVINGS', 'BANCORP', 'BANCSHARES']):
                category = 'bank_named_unmatched'
            else:
                category = 'unknown'

        holding_company = holding_company_lookup.get(cert)

        certs.append(cert)
        methods.append(method)
        categories.append(category)
        holding_companies.append(holding_company)

    result['matched_fdic_certificate_number'] = certs
    result['match_method'] = methods
    result['company_category'] = categories
    result['holding_company'] = holding_companies



    return save_clean_table(result, 'crosswalk')

def clean_macro():
    print('Cleaning and Aliging FRED Series')

    files_to_use = {
        'FEDFUNDS': base / "fred_FEDFUNDS.csv",
        'UNRATE': base / 'fred_UNRATE.csv',
        'MORTGAGE30US': base / 'fred_MORTGAGE30US.csv',
        'DGS10': base / 'fred_DGS10.csv',
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

    delete_file()
    
    engine = get_engine()

    create_schema(engine)

    inst_df = cleaned_institutions()
    fin_df = clean_financials()
    fail_df = clean_failures()
    comp_df = clean_complaints()
    cw_df = crosswalk(comp_df, inst_df)
    macro_df = clean_macro()

    print("Loading clean tables into PostgreSQL")

    inst_df.to_sql('stg_institutions', engine, schema='staging', if_exists='replace', index=False)
    fin_df.to_sql('stg_financials', engine, schema='staging', if_exists='replace', index=False)
    fail_df.to_sql('stg_failures', engine, schema='staging', if_exists='replace', index=False)
    comp_df.to_sql('stg_complaints', engine, schema='staging', if_exists='replace', index=False)
    cw_df.to_sql('stg_crosswalk', engine, schema='staging', if_exists='replace', index=False)
    macro_df.to_sql('stg_macro', engine, schema='staging', if_exists='replace', index=False)
    return f'Cleaning and loading complete.'

if __name__ == '__main__':
    run_pipeline()