import requests

url = "https://d1.fikri.dev/signin"
print(f"Testing: {url}")

try:
    response = requests.get(url, timeout=10)
    print(f"Status Code: {response.status_code}")
    print(f"Content-Type: {response.headers.get('Content-Type')}")
    print(f"Content-Length: {len(response.text)}")
    print(f"Response preview: {response.text[:200]}")
except Exception as e:
    print(f"Error: {e}")
