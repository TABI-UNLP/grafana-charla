# Grafana en 15 minutos

Charla pública. No incluye sistemas internos.

- Duración: 15 minutos
- Eje: toda la práctica corre contra una Grafana local, operada por MCP
- Demo: Docker + plugin Infinity + Open-Meteo + USGS

## Orden

1. Qué es Grafana
2. Qué se puede hacer
3. Cómo instalarla
4. La familia LGTM
5. Fuentes de datos
6. Lenguajes
7. Alertas, con un ejemplo de la demo
8. MCP local: cómo se crea y que ya funciona
9. Skills
10. Demo del dashboard
11. Qué mide cada panel
12. Cierre

## Guion corto

Grafana no guarda las series. Se conecta a donde ya están y dibuja dashboards, consultas y alertas. Esas definiciones son JSON.

Se puede usar en Grafana Cloud, Amazon Managed Grafana, Docker o Kubernetes. Esta charla usa Docker.

La familia es Loki (logs), Grafana, Tempo (trazas), Prometheus o Mimir (métricas), más Pyroscope, Alloy, k6 y OnCall. La demo no levanta ese stack: lee dos APIs públicas.

Cada fuente tiene un lenguaje: PromQL, LogQL, TraceQL, SQL, metric math de CloudWatch y JSONata para Infinity.

Una alerta es una consulta, un umbral, un tiempo de espera, etiquetas y un aviso. Ejemplo público: lluvia en Buenos Aires mayor a 5 mm.

El MCP local no requiere otro programa. Es el binario `mcp-grafana` apuntando a `http://localhost:3030` con usuario y contraseña. En Cursor hay que recargar los MCP después de agregarlo.

## Crear el MCP local

En `~/.cursor/mcp.json`:

```json
"grafana-demo": {
  "command": "mcp-grafana",
  "env": {
    "GRAFANA_URL": "http://localhost:3030",
    "GRAFANA_USERNAME": "admin",
    "GRAFANA_PASSWORD": "admin"
  }
}
```

`mcp-grafana` se instala con `brew install grafana/tap/mcp-grafana`. La URL no debe llevar `?orgId=1`.

Probado: contra esa Grafana, `search_dashboards` devuelve el dashboard `charla-grafana-demo`.

## Comandos

```bash
cd grafana-charla
./demo.sh up       # Grafana en http://localhost:3030
./demo.sh delete   # dejarla vacía para crearla en vivo
./demo.sh create   # plan B: sube el JSON
./demo.sh alerts   # crea las dos alertas (umbral de calor en 30 °C)
./demo.sh down
```

Usuario local: `admin` / `admin`.

## JSON de prueba

`grafana-charla/dashboard-demo.json`

UID: `charla-grafana-demo`. Lo sube `./demo.sh create`.

## Las URLs de datos

La demo usa dos APIs públicas, sin API key. Hay tres URLs: dos de clima y una de sismos.

### Clima del dashboard

https://api.open-meteo.com/v1/forecast?latitude=-34.6037&longitude=-58.3816&current=temperature_2m,relative_humidity_2m,apparent_temperature,wind_speed_10m&hourly=temperature_2m,apparent_temperature,precipitation&timezone=UTC&past_days=1&forecast_days=2

Open-Meteo devuelve el pronóstico de un punto, en JSON, unos 3 KB. El punto es el centro de Buenos Aires (`latitude=-34.6037`, `longitude=-58.3816`).

Trae dos bloques, y cada uno alimenta paneles distintos:

- `current`: el instante actual. Temperatura del aire a 2 m, humedad relativa, sensación térmica y viento a 10 m. Son los números grandes y los dos relojes.
- `hourly`: la misma temperatura, la sensación y la lluvia en milímetros, hora por hora. `past_days=1` y `forecast_days=2` cubren desde ayer hasta pasado mañana. Son la serie de temperatura y las barras de lluvia.

`timezone=UTC` deja las horas en UTC para que Grafana las lea sin corrimiento.

### Clima de la alerta de calor

https://api.open-meteo.com/v1/forecast?latitude=-34.6037&longitude=-58.3816&current=temperature_2m&timezone=UTC

Es el mismo servicio y el mismo punto, recortado a un solo número: la temperatura actual. La alerta «Calor en Buenos Aires» compara ese valor con el umbral. No pide el pronóstico por hora porque la regla solo mira el ahora.

### Sismos del dashboard y de la alerta

https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/4.5_week.geojson

Feed público del USGS (Servicio Geológico de Estados Unidos), en GeoJSON, unos 80 KB. El nombre del archivo es el filtro: magnitud 4.5 o más, últimos 7 días, en todo el mundo.

Cada sismo trae lugar, magnitud, hora, latitud, longitud y profundidad. Con eso se arman el conteo, el máximo, el mapa, el histograma, el top 10 y la tabla. La alerta «Sismo fuerte en la última semana» usa esta misma URL y se queda solo con la magnitud máxima.

## Qué mide cada panel

Clima, Open-Meteo, Buenos Aires:

- Temperatura actual: aire a 2 m.
- Sensación térmica: temperatura más humedad y viento.
- Humedad relativa: vapor respecto del máximo posible. 40–70 % es la zona cómoda del reloj.
- Viento: velocidad media a 10 m. Arriba de 40 km/h, el reloj pasa a fuerte.
- Temperatura vs. sensación: 72 h, un día pasado y dos de pronóstico.
- Lluvia por hora: milímetros. 1 mm = 1 litro por m².

Sismos, USGS, magnitud 4.5 o más, últimos 7 días:

- Cantidad: cuántos eventos hay en el feed.
- Magnitud máxima: el más fuerte. Un punto entero es unas 32 veces más energía.
- Mapa: un círculo por evento.
- Histograma: muchos chicos, pocos grandes.
- Top 10: los mayores, ordenados en Grafana sin cambiar la consulta.
- Tabla: lugar, hora, magnitud y profundidad. Menos de 70 km es superficial.

## Prompt para crear el dashboard

```text
Usando el MCP grafana-demo (Grafana en http://localhost:3030), creá o
sobrescribí el dashboard "Charla Grafana · Demo con datos públicos",
uid charla-grafana-demo.

Datasource: Infinity, uid public-json, type yesoreyeram-infinity-datasource.
Consultas type json, source url, parser backend. El root_selector va en JSONata.

Clima:
https://api.open-meteo.com/v1/forecast?latitude=-34.6037&longitude=-58.3816&current=temperature_2m,relative_humidity_2m,apparent_temperature,wind_speed_10m&hourly=temperature_2m,apparent_temperature,precipitation&timezone=UTC&past_days=1&forecast_days=2

Actual: format table, root_selector current.
Serie: format timeseries, root_selector
$map(hourly.time, function($v, $i) { {"time": $v & ":00Z", "temp": $$.hourly.temperature_2m[$i], "feels": $$.hourly.apparent_temperature[$i], "rain": $$.hourly.precipitation[$i]} })

Sismos:
https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/4.5_week.geojson
format table, root_selector
$map(features, function($f) { {"lugar": $f.properties.place, "mag": $f.properties.mag, "hora": $f.properties.time, "lat": $f.geometry.coordinates[1], "lon": $f.geometry.coordinates[0], "prof": $f.geometry.coordinates[2]} })

Paneles: temperatura, sensación térmica, humedad (gauge), viento (gauge),
texto de fuentes, serie temperatura vs sensación, barras de lluvia,
cantidad de sismos, magnitud máxima, mapa OpenStreetMap, histograma,
top 10 y tabla. Rango now-24h a now+48h, refresco 5m.
Describí en cada panel qué mide. Devolvé el link.
```

Para borrarlo en vivo: «Usando grafana-demo, borrá el dashboard charla-grafana-demo».

## Alertas de la demo

Hay dos alertas en la carpeta «Charla» de la Grafana local. Se evalúan cada 10 segundos:

- **Calor en Buenos Aires:** se dispara cuando la temperatura actual supera el umbral. Arranca en 30 °C, así que queda en Normal.
- **Sismo fuerte en la última semana:** se dispara si hubo un sismo de magnitud 6.5 o más en los últimos 7 días. Hoy está disparada, porque el máximo de la semana es 6.9.

Las dos se ven en `http://localhost:3030/alerting/list`.

No hay un canal de aviso configurado: el cambio de estado se ve en la pantalla de alertas, no llega a Slack ni a un mail.

### Cómo crearlas

La definición está en `grafana-charla/alerts-demo.json`. Cada regla tiene dos pasos: la consulta (Infinity, parser backend) y el umbral.

Para crearlas o volver a dejarlas como al principio:

```bash
./demo.sh alerts       # crea la carpeta Charla y las dos reglas; calor en 30 °C
./demo.sh alerts 10    # igual, pero el umbral de calor queda en 10 °C y se dispara
```

El script hace tres cosas: crea la carpeta si no existe, crea o actualiza cada regla, y deja el grupo evaluándose cada 10 segundos. Si la regla ya existe, la actualiza; no hace falta borrar nada antes.

Para crearlas en vivo con el MCP, en vez del script:

```text
Usando grafana-demo, creá dos alertas en la carpeta Charla y evalualas cada 10 segundos.

La primera se llama "Calor en Buenos Aires". Consultá la temperatura actual de Buenos Aires en Open-Meteo, con el datasource public-json, parser backend y root_selector current:
https://api.open-meteo.com/v1/forecast?latitude=-34.6037&longitude=-58.3816&current=temperature_2m&timezone=UTC
Disparala si pasa de 30 grados. Etiqueta severity=warning.

La segunda se llama "Sismo fuerte en la última semana". Usá el feed del USGS de magnitud 4.5 o más:
https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/4.5_week.geojson
La magnitud máxima sale con este JSONata:
$map([$max(features.properties.mag)], function($v) { {"max": $v} })
Disparala si es mayor a 6.4. Etiqueta severity=critical.

Las dos llevan también la etiqueta demo=charla. No configures ningún canal de aviso: las queremos ver en pantalla.
```

### Prompts para alertas

```text
Usando grafana-demo, mostrame qué alertas hay y en qué estado está cada una.
```

```text
Explicame la alerta "Sismo fuerte en la última semana": qué consulta usa,
cuál es el umbral y por qué está disparada.
```

```text
Bajá el umbral de "Calor en Buenos Aires" a 10 grados así la vemos disparar.
Después volvela a 30.
```

```text
Creá una alerta nueva en la carpeta Charla que avise si va a llover más de
2 mm en alguna hora de las próximas 24 horas. Usá el datasource public-json
con la API de Open-Meteo y evaluala cada 10 segundos.
```
