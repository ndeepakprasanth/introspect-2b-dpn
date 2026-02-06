# CloudWatch Logs Insights Queries for Introspect Claims API

## Query 1: API Gateway Request Analysis
```
fields @timestamp, requestId, httpMethod, routeKey, status, responseLength
| filter routeKey like /claims/
| sort @timestamp desc
| limit 100
```

## Query 2: Error Rate Analysis
```
fields @timestamp, status, routeKey
| filter status >= 400
| stats count() by status, routeKey
```

## Query 3: Response Time Analysis
```
fields @timestamp, routeKey, responseLength
| stats avg(responseLength), max(responseLength), min(responseLength) by routeKey
```

## Query 4: Top IP Addresses
```
fields @timestamp, ip, httpMethod, routeKey
| stats count() by ip
| sort count desc
| limit 20
```

## Query 5: Bedrock Invocation Tracking
```
fields @timestamp, @message
| filter @message like /bedrock/
| parse @message "model: *" as model
| stats count() by model
```

## Query 6: Application Error Logs
```
fields @timestamp, @message
| filter @message like /ERROR/ or @message like /Exception/
| sort @timestamp desc
| limit 50
```

## Query 7: Request Volume by Route
```
fields @timestamp, routeKey
| stats count() as requestCount by routeKey, bin(5m)
| sort requestCount desc
```

## Query 8: Latency Percentiles
```
fields @timestamp, routeKey
| stats pct(@duration, 50) as p50, pct(@duration, 95) as p95, pct(@duration, 99) as p99 by routeKey
```
