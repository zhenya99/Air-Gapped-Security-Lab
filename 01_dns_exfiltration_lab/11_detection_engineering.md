# 11 â€” Detection Engineering

## Purpose

Detection engineering means creating and testing logic that finds suspicious behavior.

## DNS Behaviors to Detect

- Very long DNS names.
- Many subdomains in one request.
- Random-looking or encoded text.
- A large number of requests in a short time.
- Requests to an unusual DNS server.

## Splunk Searches

Add each SPL search here with a plain-language explanation of what it detects.

## Security Onion Detections

Add each Suricata rule or Security Onion hunt here with a plain-language explanation.

## Testing

Record whether each detection fired during normal traffic and simulated suspicious traffic.