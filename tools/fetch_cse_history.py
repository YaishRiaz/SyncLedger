#!/usr/bin/env python3
"""
fetch_cse_history.py
=====================
Fetch 6 months of end-of-day OHLCV data for CSE-listed stocks and save to CSV.

Key findings from API exploration:
  - todaySharePrice  → returns live ticker (only traded-today stocks on weekdays;
                        very few on weekends).  Use --symbols on weekends.
  - companyInfoSummery?symbol=LOLC.N0000 → returns reqSymbolInfo.id (= stockId)
  - companyChartDataByStock stockId=<id> period=5 → ~1 year of daily OHLCV
    Period enum: 1=intraday  2=1wk  3=1mo  4=3mo  5=1yr

Usage
-----
    pip install requests pandas

    # All actively-traded stocks (best on a weekday when market is open)
    python fetch_cse_history.py

    # Specific symbols (works any day)
    python fetch_cse_history.py --symbols HHL LOLC APLA TKYO BFL DIPD

    # Custom months / output file
    python fetch_cse_history.py --months 3 --out my_prices.csv

Output columns: symbol, date (YYYY-MM-DD), open, high, low, close, volume
"""

import argparse
import json
import sys
import time
from datetime import datetime, timedelta

import pandas as pd
import requests

BASE_URL   = "https://www.cse.lk/api/"
HEADERS    = {"Content-Type": "application/x-www-form-urlencoded"}
TIMEOUT    = 15
REQ_DELAY  = 0.35   # seconds – polite rate limit

# ---------------------------------------------------------------------------
# Step 1: Resolve symbols → stockIds
# ---------------------------------------------------------------------------

def get_stock_id(full_symbol: str) -> dict | None:
    """
    Call companyInfoSummery to get the numeric stockId for a full CSE symbol
    (e.g., 'HHL.N0000').  Returns {'id', 'symbol', 'name', 'suffix'} or None.
    """
    r = requests.post(
        BASE_URL + "companyInfoSummery",
        data={"symbol": full_symbol},
        headers=HEADERS,
        timeout=TIMEOUT,
    )
    if r.status_code != 200:
        return None
    info = (r.json().get("reqSymbolInfo") or {})
    sid = info.get("id")
    if not sid:
        return None
    bare   = full_symbol.split(".")[0]
    suffix = full_symbol.split(".")[1][0] if "." in full_symbol else "N"
    return {
        "id":         sid,
        "symbol":     bare,
        "fullSymbol": full_symbol,
        "suffix":     suffix,
        "name":       info.get("name", ""),
    }


def get_all_from_live_ticker() -> list[dict]:
    """
    Fetch the current trading ticker.  On weekdays (market open) this returns
    all actively traded stocks.  On weekends / holidays it returns far fewer.
    """
    r = requests.post(BASE_URL + "todaySharePrice", headers=HEADERS, timeout=TIMEOUT)
    if r.status_code != 200 or not isinstance(r.json(), list):
        return []
    items = []
    for item in r.json():
        sym = item.get("symbol")
        sid = item.get("id")
        if sym and sid and "." in sym:
            bare   = sym.split(".")[0]
            suffix = sym.split(".")[1][0]
            items.append({
                "id":         sid,
                "symbol":     bare,
                "fullSymbol": sym,
                "suffix":     suffix,
                "name":       item.get("name", ""),
            })
    return items


# ---------------------------------------------------------------------------
# Step 2: Fetch OHLCV history for one stock (period=5 → ~1 year)
# ---------------------------------------------------------------------------

def fetch_history(stock: dict, cutoff_date) -> pd.DataFrame:
    """
    Fetch ~1 year of daily OHLCV and return rows >= cutoff_date.
    Uses companyChartDataByStock with stockId + period=5.
    """
    r = requests.post(
        BASE_URL + "companyChartDataByStock",
        data={"stockId": str(stock["id"]), "period": "5"},
        headers=HEADERS,
        timeout=TIMEOUT,
    )
    if r.status_code != 200:
        return pd.DataFrame()

    chart_data = r.json().get("chartData") or []
    if not chart_data:
        return pd.DataFrame()

    rows = []
    for bar in chart_data:
        try:
            bar_date = datetime.fromtimestamp(bar["t"] / 1000).date()
            if bar_date < cutoff_date:
                continue
            rows.append({
                "symbol":   stock["symbol"],
                "date":     bar_date.strftime("%Y-%m-%d"),
                "open":     bar.get("o"),
                "high":     bar.get("h"),
                "low":      bar.get("l"),
                "close":    bar.get("p"),   # last traded / closing price
                "volume":   bar.get("q"),
            })
        except (KeyError, TypeError, ValueError, OSError):
            continue

    return pd.DataFrame(rows)


# ---------------------------------------------------------------------------
# Step 3: Build dataset
# ---------------------------------------------------------------------------

SUFFIX_VARIANTS = [".N0000", ".X0000", ".Y0000", ".W0000"]


def resolve_symbols(bare_symbols: list[str]) -> list[dict]:
    """
    Try each suffix variant for every bare symbol until one resolves.
    """
    resolved = []
    for bare in bare_symbols:
        found = False
        for suffix in SUFFIX_VARIANTS:
            full = f"{bare}{suffix}"
            result = get_stock_id(full)
            time.sleep(REQ_DELAY)
            if result:
                print(f"  {full:<20} -> id={result['id']}  {result['name'][:45]}")
                resolved.append(result)
                found = True
                break
        if not found:
            print(f"  {bare:<20} -> not found on CSE")
    return resolved


def build_dataset(symbols_filter: list[str] | None, months: int, output_file: str):
    cutoff = (datetime.today() - timedelta(days=months * 30)).date()
    print(f"Fetching CSE history from {cutoff} ({months} months)\n")

    # --- Resolve which stocks to fetch ---
    if symbols_filter:
        print(f"Resolving {len(symbols_filter)} specified symbol(s)...")
        stocks = resolve_symbols(symbols_filter)
    else:
        print("Fetching live ticker for all actively traded stocks...")
        stocks = get_all_from_live_ticker()
        if len(stocks) < 20:
            print(
                f"  WARNING: Only {len(stocks)} stocks returned (market may be closed).\n"
                f"  For complete coverage run on a weekday or use --symbols.\n"
                f"  Continuing with the {len(stocks)} stocks available...\n"
            )
        else:
            print(f"  Found {len(stocks)} stocks.\n")

    if not stocks:
        print("ERROR: No stocks to fetch. Try --symbols or run on a weekday.", file=sys.stderr)
        sys.exit(1)

    # --- Fetch OHLCV history ---
    total  = len(stocks)
    frames = []
    failed = []

    for i, stock in enumerate(stocks, start=1):
        sys.stdout.write(
            f"\r[{i:4d}/{total}] {stock['fullSymbol']:<14}  {stock['name'][:40]:<40}"
        )
        sys.stdout.flush()

        try:
            df = fetch_history(stock, cutoff)
            if not df.empty:
                frames.append(df)
            else:
                failed.append((stock["fullSymbol"], "no data in range"))
        except Exception as e:
            failed.append((stock["fullSymbol"], str(e)))

        time.sleep(REQ_DELAY)

    print()  # newline

    if not frames:
        print("ERROR: No data collected.", file=sys.stderr)
        sys.exit(1)

    master = pd.concat(frames, ignore_index=True)
    master.sort_values(["symbol", "date"], inplace=True)
    master.reset_index(drop=True, inplace=True)
    master.to_csv(output_file, index=False)

    # Summary
    print(f"\n{'='*62}")
    print(f"  Symbols with data : {master['symbol'].nunique()}")
    print(f"  Total rows        : {len(master):,}")
    print(f"  Date range        : {master['date'].min()} to {master['date'].max()}")
    print(f"  Output file       : {output_file}")
    print(f"{'='*62}")

    if failed:
        print(f"\n  {len(failed)} symbol(s) returned no data:")
        for sym, reason in failed[:20]:
            print(f"    {sym:<20} {reason}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Fetch CSE historical OHLCV data.")
    parser.add_argument(
        "--out", default="tools/cse_historical_6months.csv",
        help="Output CSV path (default: tools/cse_historical_6months.csv)"
    )
    parser.add_argument(
        "--months", type=int, default=6,
        help="Months of history to fetch (default: 6)"
    )
    parser.add_argument(
        "--symbols", nargs="+",
        help="Bare tickers to fetch (e.g. HHL LOLC APLA).  "
             "Omit to fetch all currently trading stocks."
    )
    args = parser.parse_args()
    build_dataset(
        symbols_filter=args.symbols,
        months=args.months,
        output_file=args.out,
    )


if __name__ == "__main__":
    main()
