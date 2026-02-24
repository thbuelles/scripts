# bici-utils

Small utility scripts used by bici.

## Scripts

- `battery_status.sh` — prints a one-line battery summary from `pmset -g batt`
- `dump_append.py` — appends structured text entries to `dumps/YYYY-MM-DD.jsonl`

## Usage

```bash
./battery_status.sh
python3 dump_append.py "text to record" '{"source":"manual"}'
```
