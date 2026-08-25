import urllib.request
import json

url = "https://api.github.com/repos/200012Yoel/SarahAI/actions/runs"
req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
try:
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read().decode())
        for r in data.get("workflow_runs", [])[:4]:
            print(f"Run #{r.get('run_number')} ({r.get('id')}): {r.get('name')} | Status: {r.get('status')} | Conclusion: {r.get('conclusion')} | Commit: {r.get('head_commit',{}).get('id','')[:7]}")
            jobs_url = r.get('jobs_url')
            if jobs_url:
                jreq = urllib.request.Request(jobs_url, headers={"User-Agent": "Mozilla/5.0"})
                with urllib.request.urlopen(jreq) as jresp:
                    jdata = json.loads(jresp.read().decode())
                    for j in jdata.get('jobs', []):
                        print(f"   Job: {j.get('name')} -> {j.get('status')} / {j.get('conclusion')}")
                        for s in j.get('steps', []):
                            print(f"     Step: {s.get('name')} -> {s.get('status')} ({s.get('conclusion')})")
except Exception as e:
    print(f"Error: {e}")
