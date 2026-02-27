# bici-utils

Small utility scripts used by bici.

## Scripts

- `battery_status.sh` — prints a one-line battery summary from `pmset -g batt`
- `dump_append.py` — appends structured `DUMP` entries to `dumps/YYYY-MM-DD.jsonl`
- `amazon_append.py` — appends structured `AMAZON` entries to `shopping/amazon_wishlist.jsonl`

## Usage

```bash
./battery_status.sh
python3 dump_append.py "text to record" '{"source":"manual"}'
python3 amazon_append.py "item to order later" '{"source":"manual"}'
```
