import urllib.request, json, os, sys

TOKEN='***'

headers = {
    'Authorization': f'Bearer {TOKEN}',
    'Accept': 'application/vnd.github+json',
    'User-Agent': 'TodoApp-Release'
}

list_url = 'https://api.github.com/repos/Alorith-H/TodoApp/releases/344187834/assets'
try:
    req = urllib.request.Request(list_url, headers=headers)
    resp = urllib.request.urlopen(req)
    assets = json.loads(resp.read())
    print(f'Assets: {len(assets)}')
    for asset in assets:
        if asset['name'] in ('TODO.apk', 'app-release.apk'):
            del_req = urllib.request.Request(asset['url'], headers=headers, method='DELETE')
            urllib.request.urlopen(del_req)
            print(f'Deleted: {asset["name"]}')
except Exception as e:
    print(f'List err: {e}')
    if hasattr(e, 'read'):
        print(e.read().decode()[:300])

upload_url = 'https://uploads.github.com/repos/Alorith-H/TodoApp/releases/344187834/assets?name=TODO.apk'
apk_path = r'C:\\Users\\28351\\Desktop\\TodoApp.apk'
file_size = os.path.getsize(apk_path)
print(f'Uploading {file_size} bytes...')

with open(apk_path, 'rb') as f:
    apk_data = f.read()

upload_headers = headers.copy()
upload_headers['Content-Type'] = 'application/vnd.android.package-archive'

req2 = urllib.request.Request(upload_url, data=apk_data, headers=upload_headers, method='POST')
resp2 = urllib.request.urlopen(req2, timeout=120)
result = json.loads(resp2.read())
print(f'OK: {result["browser_download_url"]}')
