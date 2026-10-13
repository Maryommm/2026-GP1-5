## Setup
1. Download ethmar_master_dataset.csv  into data/raw/
2. python recommender/scripts/clean_dataset.py   # generates the processed tables
3. python recommender/scripts/load_check.py      # verifies them
4. python recommender/scripts/scoring.py         # runs the recommender
