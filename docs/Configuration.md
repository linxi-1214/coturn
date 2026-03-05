# TURN Server Configuration File Reference

When using the `-c` option to specify a configuration file (e.g., `turnserver -c /etc/coturn/turnserver.conf`), the following parameters are supported. A full annotated example is provided in `examples/etc/turnserver.conf`.

> **Boolean values:** Where a boolean value is expected, use `0`, `off`, `no`, `false`, or `f` for false, and `1`, `on`, `yes`, `true`, or `t` for true. If the value is omitted, it defaults to `true`.

---

## Table of Contents

1. [Network & Listeners](#network--listeners)
2. [Relay Settings](#relay-settings)
3. [Protocol Settings](#protocol-settings)
4. [Authentication](#authentication)
5. [Database Backends](#database-backends)
6. [Quota & Bandwidth](#quota--bandwidth)
7. [TLS / SSL](#tls--ssl)
8. [Logging](#logging)
9. [Redirection & Load Balancing](#redirection--load-balancing)
10. [Security](#security)
11. [Process Management](#process-management)
12. [CLI (Command-Line Interface)](#cli-command-line-interface)
13. [Web Admin Interface](#web-admin-interface)
14. [Prometheus Metrics](#prometheus-metrics)
15. [Miscellaneous](#miscellaneous)

---

## Network & Listeners

| Option | Type | Default | Description |
|---|---|---|---|
| `listening-device` | string | — | Listener interface device name. Optional, Linux only. **NOT RECOMMENDED.** |
| `listening-port` | integer | `3478` | TURN listener port for UDP and TCP. TLS/DTLS sessions may also connect to this port. |
| `tls-listening-port` | integer | `5349` | TURN listener port for TLS and DTLS. Plain TCP/UDP sessions may also connect to this port. |
| `alt-listening-port` | integer | `listening-port + 1` | Alternative listening port for UDP/TCP; used for RFC 5780 (NAT behavior discovery). `0` means default. |
| `alt-tls-listening-port` | integer | `tls-listening-port + 1` | Alternative listening port for TLS/DTLS. `0` means default. |
| `tcp-proxy-port` | integer | — | Accept TCP connections from a load balancer using the HAProxy PROXY protocol v2 on this port. |
| `listening-ip` | string (repeatable) | all IPv4 | Listener IP address. May be specified multiple times. Use `::` for all IPv6. If omitted, all IPv4 addresses are used. |
| `aux-server` | string (repeatable) | — | Auxiliary STUN/TURN server endpoint (`ip:port` or `[ipv6]:port`). May be specified multiple times. No RFC 5780 support on aux servers. |
| `udp-self-balance` | boolean | `false` | Automatically balance UDP traffic over auxiliary servers using ALTERNATE-SERVER (recommended for older Linux kernels only). |

---

## Relay Settings

| Option | Type | Default | Description |
|---|---|---|---|
| `relay-device` | string | — | Relay interface device name. Optional, Linux only. **NOT RECOMMENDED.** |
| `relay-ip` | string (repeatable) | client IP | IP address used to relay packets to peers. Multiple values allowed. If omitted, the client socket IP is used. |
| `external-ip` | string (repeatable) | — | Public/private address mapping for servers behind NAT. Format: `public-ip` or `public-ip/private-ip`. May be specified multiple times for multi-address setups. |
| `relay-threads` | integer | OS default | Number of relay threads. `0` means relay runs in the same thread as the listener. |
| `cpus` | integer | auto-detected | Override the system CPU count used to compute the default relay thread count. Useful in containerized environments. |
| `min-port` | integer | `49152` | Lower bound of the UDP relay port range. |
| `max-port` | integer | `65535` | Upper bound of the UDP relay port range. |
| `sock-buf-size` | integer | `2097152` | Socket send/receive buffer size in bytes (2 MB default). |

---

## Protocol Settings

| Option | Type | Default | Description |
|---|---|---|---|
| `no-udp` | boolean | `false` | Disable UDP client listeners. |
| `no-tcp` | boolean | `false` | Disable TCP client listeners. |
| `no-tls` | boolean | `false` | Disable TLS client listeners. |
| `no-dtls` | boolean | `false` | Disable DTLS client listeners. |
| `no-udp-relay` | boolean | `false` | Disallow UDP relay endpoints (allow TCP relay only). |
| `no-tcp-relay` | boolean | `false` | Disallow TCP relay endpoints (allow UDP relay only). |
| `fingerprint` | boolean | `false` | Use STUN message fingerprints in TURN messages. |
| `stale-nonce` | integer | `600` | Nonce lifetime in seconds. `0` for unlimited. Clients receive a 438 error after expiry and must re-authenticate. |
| `max-allocate-lifetime` | integer | `3600` | Maximum allocation lifetime in seconds before it must be refreshed. |
| `channel-lifetime` | integer | `600` | Channel binding lifetime in seconds. Do not change in production. |
| `permission-lifetime` | integer | `300` | Permission lifetime in seconds. Do not change in production. |
| `stun-only` | boolean | `false` | Operate as a STUN-only server; reject all TURN requests. |
| `no-stun` | boolean | `false` | Operate as a TURN-only server; reject all STUN requests. |
| `max-allocate-timeout` | integer | `60` | Maximum time in seconds allowed for full allocation establishment. |

---

## Authentication

| Option | Type | Default | Description |
|---|---|---|---|
| `lt-cred-mech` | boolean | `false` | Enable the long-term credential mechanism. Default if any users are defined. |
| `no-auth` | boolean | `false` | Disable all credential checks (anonymous access). Default if no users are defined. |
| `use-auth-secret` | boolean | `false` | Enable TURN REST API (time-limited long-term credential) authentication. Internally depends on `lt-cred-mech`, so it automatically enables it. **Use either `lt-cred-mech` or `use-auth-secret`, not both explicitly** — the two mechanisms validate credentials differently and cannot be used at the same time. |
| `static-auth-secret` | string | — | Shared secret for TURN REST API. If not set, the server looks up the secret in the `turn_secret` database table. |
| `server-name` | string | realm value | Server name used for oAuth authentication. |
| `oauth` | boolean | `false` | Enable oAuth authentication support. |
| `user` | string (repeatable) | — | Static long-term credential: `username:password` or `username:0xKEY`. May be specified multiple times. Keys are generated with `turnadmin -k`. |
| `realm` | string | host domain | Default realm for users when no explicit origin/realm mapping exists in the database. Required for `lt-cred-mech` and TURN REST API. |
| `check-origin-consistency` | boolean | `false` | Require that all requests in a session use the same ORIGIN attribute value. |
| `rest-api-separator` | character | `:` | Separator character between timestamp and user ID in TURN REST API credentials. |
| `secure-stun` | boolean | `false` | Require authentication for STUN Binding requests (anonymous STUN is disallowed). |
| `no-auth-pings` | boolean | `false` | Disable periodic health checks to dynamic authentication secret tables. |
| `no-dynamic-ip-list` | boolean | `false` | Do not use the dynamic allowed/denied peer IP list from the database. |
| `no-dynamic-realms` | boolean | `false` | Do not use dynamic realm assignment and per-realm options from the database. |

---

## Database Backends

| Option | Type | Default | Description |
|---|---|---|---|
| `userdb` | string | `/var/db/turndb` | Path to the SQLite database file used for credentials and secrets. |
| `psql-userdb` | string | — | PostgreSQL connection string (requires `--enable-psql` build). Example: `"host=localhost dbname=coturn user=coturn password=secret connect_timeout=30"` |
| `mysql-userdb` | string | — | MySQL connection string (requires `--enable-mysql` build). Example: `"host=localhost dbname=coturn user=coturn password=secret port=3306"` |
| `secret-key-file` | string | — | Path to the AES key file used to encrypt the MySQL password in `mysql-userdb`. If set, the MySQL password must be encrypted. |
| `mongo-userdb` | string | — | MongoDB connection URI (requires `--enable-mongo` build). Example: `"mongodb://user:pass@host/dbname"` |
| `redis-userdb` | string | — | Redis connection string for the user database (requires `--enable-redis` build). Example: `"ip=127.0.0.1 dbname=0 password=secret port=6379 connect_timeout=30"` |
| `redis-statsdb` | string | — | Redis connection string for the statistics/events database. Same format as `redis-userdb`. |

---

## Quota & Bandwidth

| Option | Type | Default | Description |
|---|---|---|---|
| `user-quota` | integer | `0` | Maximum concurrent allocations per user. `0` means unlimited. Can also be set per-realm in the database. |
| `total-quota` | integer | `0` | Maximum total concurrent allocations on the server. `0` means unlimited. Can also be set per-realm in the database. |
| `max-bps` | integer | `0` | Maximum bytes-per-second per TURN session (input and output treated separately). `0` means unlimited. |
| `bps-capacity` | integer | `0` | Maximum total bytes-per-second across all sessions combined. `0` means unlimited. |

---

## TLS / SSL

| Option | Type | Default | Description |
|---|---|---|---|
| `cert` | string | — | TLS certificate file path (PEM format). Relative paths are resolved against the configuration file directory. |
| `pkey` | string | — | TLS private key file path (PEM format). |
| `raw-public-keys` | boolean | `false` | Enable RFC 7250 raw public keys (requires OpenSSL ≥ 3.2.1). |
| `pkey-pwd` | string | — | Password for an encrypted private key file. |
| `cipher-list` | string | `"DEFAULT"` | OpenSSL cipher list string for TLS/DTLS connections. |
| `CA-file` | string | — | CA certificate file (PEM format). When set, the server verifies client certificates. |
| `ec-curve-name` | string | `prime256v1` | Named elliptic curve for EC ciphers (TLS and DTLS). With OpenSSL 1.0.2+, an optimal curve is selected automatically if not set. |
| `dh566` | boolean | `false` | Use a 566-bit predefined DH key (default DH key size is 2066 bits). |
| `dh1066` | boolean | `false` | Use a 1066-bit predefined DH key. |
| `dh-file` | string | — | Custom DH key file (PEM format). Overrides `dh566` and `dh1066`. |
| `tlsv1` | boolean | `false` | Set TLS 1.0 as the minimum supported TLS protocol version. |
| `tlsv1_1` | boolean | `false` | Set TLS 1.1 as the minimum supported TLS protocol version. |
| `no-tlsv1_2` | boolean | `false` | Set TLS 1.3 / DTLS 1.2 as the minimum supported protocol version (disables TLS 1.2 and below). |

---

## Logging

| Option | Type | Default | Description |
|---|---|---|---|
| `verbose` | boolean | `false` | Enable moderate (normal) verbose logging. |
| `Verbose` | boolean | `false` | Enable extra verbose logging. Very noisy; not recommended for production. |
| `log-file` | string | auto | Full path to the log file. Special values: `stdout` or `-` for console output; `syslog` for the system log. |
| `no-stdout-log` | boolean | `false` | Suppress log output to stdout; write to the log file only. |
| `syslog` | boolean | `false` | Send all log output to the system log (syslog). |
| `syslog-facility` | string | `""` | Syslog facility to use (e.g., `"LOG_LOCAL1"`). |
| `simple-log` | boolean | `false` | Disable log file rotation; the log file name is used as-is (useful with logrotate). |
| `new-log-timestamp` | boolean | `false` | Use full ISO-8601 timestamps in all log messages. |
| `new-log-timestamp-format` | string | — | `strftime(3)` format string for log timestamps. Requires `new-log-timestamp`. |
| `log-binding` | boolean | `false` | Log STUN Binding requests and UDP endpoint events in verbose mode. Disabled by default to reduce DoS amplification risk. |

---

## Redirection & Load Balancing

| Option | Type | Default | Description |
|---|---|---|---|
| `alternate-server` | string (repeatable) | — | Redirect ALLOCATE requests (UDP/TCP) to an alternate TURN server (`ip:port`). Multiple entries enable round-robin load balancing. IPv6 addresses must be enclosed in brackets. Default port is `3478`. |
| `tls-alternate-server` | string (repeatable) | — | Redirect ALLOCATE requests (TLS/DTLS) to an alternate TURN server. Same format as `alternate-server`. Default port is `5349`. |

---

## Security

| Option | Type | Default | Description |
|---|---|---|---|
| `allow-loopback-peers` | boolean | `false` | Allow relay connections to loopback addresses (`127.x.x.x` and `::1`). **Development only — do not use in production.** |
| `no-multicast-peers` | boolean | `false` | Disallow relay connections to multicast addresses (`224.0.0.0/4` and `FFxx::`). |
| `allowed-peer-ip` | string (repeatable) | — | Explicitly allow a specific IP address or range (`start-ip-end-ip`). Allowed entries override denied entries. |
| `denied-peer-ip` | string (repeatable) | — | Deny relay connections to a specific IP address or range (`start-ip-end-ip`). |
| `no-software-attribute` | boolean | `false` | **Deprecated.** Hide the software version in responses. Use `software-attribute=false` instead. |
| `software-attribute` | boolean | `true` | Send the SOFTWARE attribute in responses. Disable in production to reduce fingerprinting risk. |
| `drop-invalid-packets` | boolean | `false` | Drop malformed/invalid packets early (before processing). |
| `drop-invalid-packets-log` | boolean | `false` | Log dropped invalid packets. |

---

## Process Management

| Option | Type | Default | Description |
|---|---|---|---|
| `daemon` | boolean | `false` | Detach from the current shell and run as a background daemon. |
| `pidfile` | string | `/var/run/turnserver.pid` | File path to store the process ID. Falls back to `/var/tmp/turnserver.pid` for non-root users. |
| `proc-user` | string | — | Drop privileges to this OS user after initialization. |
| `proc-group` | string | — | Drop privileges to this OS group after initialization. |

---

## CLI (Command-Line Interface)

| Option | Type | Default | Description |
|---|---|---|---|
| `no-cli` | boolean | `false` | Disable the CLI server. |
| `cli-ip` | string | `127.0.0.1` | Local IP address for the CLI server endpoint. |
| `cli-port` | integer | `5766` | CLI server port. |
| `cli-password` | string | `""` | CLI access password. Use the encrypted form generated by `turnadmin -P` for better security. Example encrypted value: `$5$79a316b350311570$81df9...` |
| `cli-max-output-sessions` | integer | `256` | Maximum number of sessions shown in the `ps` CLI command. Can be changed at runtime in the CLI. |

---

## Web Admin Interface

| Option | Type | Default | Description |
|---|---|---|---|
| `web-admin` | boolean | `false` | Enable the HTTPS web admin interface. Also starts a plain HTTP server with a redirect banner. Not supported when `no-tls` is set. |
| `web-admin-ip` | string | `127.0.0.1` | Local IP address for the web admin server. |
| `web-admin-port` | integer | `8080` | Web admin server port. |
| `web-admin-listen-on-workers` | boolean | `false` | Allow the web admin server to listen on STUN/TURN worker threads. **Not recommended in production.** |

---

## Prometheus Metrics

| Option | Type | Default | Description |
|---|---|---|---|
| `prometheus` | boolean | `false` | Enable the Prometheus metrics exporter. Exposes metrics at `/metrics` on the configured port. |
| `prometheus-port` | integer | `9641` | Port for the Prometheus metrics endpoint. |
| `prometheus-address` | string | all interfaces | IP address on which the Prometheus metrics endpoint listens. |
| `prometheus-path` | string | `/metrics` | URL path for the Prometheus metrics endpoint. |
| `prometheus-username-labels` | boolean | `false` | Label traffic metrics with client usernames. Disabled by default to prevent memory leaks when using ephemeral usernames (e.g., TURN REST API). |

---

## Miscellaneous

| Option | Type | Default | Description |
|---|---|---|---|
| `mobility` | boolean | `false` | Enable Mobility with ICE (MICE) as per RFC 8016. |
| `keep-address-family` | boolean | `false` | **Deprecated.** Use `allocation-default-address-family=keep` instead. |
| `allocation-default-address-family` | string | `"ipv4"` | Default address family for allocations when the client does not explicitly request one. Values: `"ipv4"`, `"ipv6"`, or `"keep"` (use the same family as the client connection). |
| `acme-redirect` | string | `""` | Redirect HTTP GET requests matching `^/.well-known/acme-challenge/(.*)` to `<URL>$1`. Useful for Let's Encrypt certificate renewal. |
| `server-relay` | boolean | `false` | **Non-standard and dangerous.** Allow server applications on relay endpoints by skipping IP permission checks. |
| `ne` | integer (`1`–`3`) | — | Set the internal network engine type (for development/debugging only). |
| `rfc5780` | boolean | `false` | Enable RFC 5780 NAT behavior discovery. Disabled by default to reduce STUN amplification attack risk. |
| `no-rfc5780` | boolean | `true` | **Deprecated.** RFC 5780 is now disabled by default; use `rfc5780` to enable it. |
| `stun-backward-compatibility` | boolean | `false` | Handle legacy STUN Binding requests and enable MAPPED-ADDRESS in binding responses. Disabled by default to reduce amplification risk. |
| `response-origin-only-with-rfc5780` | boolean | `false` | Only include RESPONSE-ORIGIN attribute in responses when RFC 5780 is active. |
| `respond-http-unsupported` | boolean | `false` | Return an HTTP `400 Not Supported` response when an HTTP connection is made to a STUN/TURN-only TCP port. Useful for debugging. |

---

## Configuration File Syntax

- Lines beginning with `#` are comments.
- Options are written as `key=value` or as bare flags (boolean options without a value default to `true`).
- Boolean flags can appear without a value: `verbose` is equivalent to `verbose=true`.
- Some options may be repeated (marked *repeatable* above) to specify multiple values, e.g., multiple `listening-ip` or `user` entries.
- The configuration file is searched in the following locations (in order) unless an absolute path is provided:
  1. Current directory
  2. `/usr/local/etc/`
  3. `/etc/`
  4. OS-specific platform paths

## See Also

- [Full annotated example config](../examples/etc/turnserver.conf)
- [Project wiki](https://github.com/coturn/coturn/wiki)
- `man turnserver` — manual page for the turnserver binary
- [TURN REST API documentation](https://tools.ietf.org/html/draft-uberti-behave-turn-rest-00)