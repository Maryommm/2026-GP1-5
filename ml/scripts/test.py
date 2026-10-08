import os
from pathlib import Path
import requests

# read .env without any extra dependency
env_path = Path(".env")
if env_path.exists():
    for line in env_path.read_text(encoding="utf-8").splitlines():
        if "=" in line and not line.strip().startswith("#"):
            key, _, value = line.partition("=")
            os.environ.setdefault(key.strip(), value.strip())

api_key = os.environ.get("OPENWEATHER_API_KEY")
if not api_key:
    raise SystemExit("OPENWEATHER_API_KEY not found in .env")

response = requests.get(
       "https://api.openweathermap.org/data/2.5/weather",
    params={"lat": 24.71, "lon": 46.67, "appid": api_key, "units": "metric"},
    timeout=15,
)

print("status:", response.status_code)
print(response.json())
