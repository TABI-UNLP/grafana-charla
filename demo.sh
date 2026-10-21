#!/usr/bin/env bash
# Demo local de Grafana: up | create | delete | down
set -euo pipefail
cd "$(dirname "$0")"
URL="http://localhost:3030"
AUTH="admin:admin"
UID_DASH="charla-grafana-demo"

case "${1:-}" in
  up)
    docker compose up -d
    until curl -sf "$URL/api/health" >/dev/null; do sleep 2; done
    echo "Grafana lista en $URL (admin / admin)"
    ;;
  create)
    python3 -c 'import json,sys; print(json.dumps({"dashboard": json.load(open("dashboard-demo.json")), "overwrite": True}))' \
      | curl -sf -u "$AUTH" -H "Content-Type: application/json" -X POST "$URL/api/dashboards/db" -d @-
    echo
    echo "Abrí $URL/d/$UID_DASH"
    ;;
  delete)
    curl -sf -u "$AUTH" -X DELETE "$URL/api/dashboards/uid/$UID_DASH" && echo
    ;;
  alerts)
    # ./demo.sh alerts [umbral °C]: recrea las dos alertas. Un umbral bajo dispara "Calor en Buenos Aires".
    curl -s -u "$AUTH" -H "Content-Type: application/json" -X POST "$URL/api/folders" -d '{"uid":"charla","title":"Charla"}' >/dev/null
    python3 - "${2:-30}" "$URL" "$AUTH" <<'PY'
import base64, json, sys, urllib.request
threshold, url, auth = float(sys.argv[1]), sys.argv[2], sys.argv[3]
headers = {"Content-Type": "application/json", "X-Disable-Provenance": "true",
           "Authorization": "Basic " + base64.b64encode(auth.encode()).decode()}
def call(method, path, body=None):
    req = urllib.request.Request(url + path, method=method, headers=headers,
                                 data=json.dumps(body).encode() if body is not None else None)
    try:
        body = urllib.request.urlopen(req).read()
        return json.loads(body) if body else None
    except urllib.error.HTTPError as e:
        if e.code == 404 and method == "PUT":
            return "missing"
        sys.exit(f"{method} {path}: {e.code} {e.read().decode()}")
for rule in json.load(open("alerts-demo.json")):
    if rule["uid"] == "charla-calor":
        rule["data"][1]["model"]["conditions"][0]["evaluator"]["params"] = [threshold]
    if call("PUT", f"/api/v1/provisioning/alert-rules/{rule['uid']}", rule) == "missing":
        call("POST", "/api/v1/provisioning/alert-rules", rule)
group_path = "/api/v1/provisioning/folder/charla/rule-groups/charla"
group = call("GET", group_path)
group["interval"] = 10
call("PUT", group_path, group)
print(f"Alertas creadas. Calor dispara arriba de {threshold} °C. Ver {url}/alerting/list")
PY
    ;;
  down)
    docker compose down
    ;;
  *)
    echo "uso: $0 up | create | delete | alerts [umbral] | down" >&2
    exit 1
    ;;
esac
