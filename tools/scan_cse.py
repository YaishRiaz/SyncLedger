import requests, re, sys, json
sys.stdout.reconfigure(encoding='utf-8')

chunks = [
    '/_next/static/chunks/e283c3f99cf1669f.js',
    '/_next/static/chunks/ce90238d631da638.js',
    '/_next/static/chunks/32595b1160a10f28.js',
    '/_next/static/chunks/68befc78165508a3.js',
]
all_apis = set()
for chunk in chunks:
    r = requests.get(f'https://www.cse.lk{chunk}', timeout=20, headers={'User-Agent': 'Mozilla/5.0'})
    if r.status_code == 200:
        text = r.text
        # Find strings that look like API endpoint method names
        # Look for patterns like "api/" followed by camelCase name
        found = re.findall(r'["\']api/([a-zA-Z][a-zA-Z0-9]+)["\'\?/]', text)
        all_apis.update(found)
        # Also look for isolated endpoint names near "api" context
        contexts = re.findall(r'.{0,30}api.{0,60}', text)
        for ctx in contexts:
            m = re.findall(r'["\']([a-z][a-zA-Z]{6,35})["\']', ctx)
            for name in m:
                if any(k in name for k in ['Price', 'Symbol', 'Stock', 'List', 'Company', 'Share', 'Market', 'Chart', 'Trade', 'Listing']):
                    all_apis.add(name)

print('API endpoints / method names found:')
for a in sorted(all_apis):
    print(' ', a)

# Also fetch the largest chunk to get more context
r_big = requests.get('https://www.cse.lk/_next/static/chunks/32595b1160a10f28.js', timeout=20, headers={'User-Agent': 'Mozilla/5.0'})
if r_big.status_code == 200:
    # Find all strings after "endpoint" or "url" or "path" keywords
    pairs = re.findall(r'(?:endpoint|url|path|route)["\s:=,]*["\']([a-zA-Z/][a-zA-Z0-9/_-]{5,50})["\']', r_big.text, re.IGNORECASE)
    if pairs:
        print('\nEndpoint strings:')
        for p in sorted(set(pairs))[:30]:
            print(' ', p)
