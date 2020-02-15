<p align="center">
    <img align="center" src="https://user-images.githubusercontent.com/1072598/31840406-1fe37936-b59a-11e7-939a-71d36e584fc9.png" />
    <h3 align="center">CertStream-Server</h3>
    <p align="center">Aggregate and broadcast SSL certs as they're issued live.</p>
</p>

**Certstream-server** is a service written in elixir to aggregate, parse, and stream certificate data from multiple [certificate transparency logs](https://www.certificate-transparency.org/what-is-ct). It leverages the amazing power of elixir/erlang to achieve great network throughput and concurrency with very little resource usage.

This is a rewrite of the [original version written in python](https://github.com/CaliDog/certstream-server-python), and is much more efficient than the original and currently ships millions of certificates a day on a small Heroku instance no problem.

## Getting Started

Getting up and running is pretty easy (especially if you use Heroku, as we include a Dockerfile!).

First install elixir

```
$ brew install elixir
```

Then fetch the dependencies

```
$ mix deps.get
```

From there you can run it

```
$ mix run --no-halt
```

Alternatively, you can run it in an iex session (so you can interact with it while it's running) for development

```
$ iex -S mix
Interactive Elixir (1.8.2) - press Ctrl+C to exit (type h() ENTER for help)
iex(1)> :observer.start
```

This will open up an http/websocket server on port 4000 (override this by setting a `PORT` environment variable). Connecting to it with a websocket client will subscribe you to a live aggregated stream of certificates and heartbeat messages.

Connecting over a normal HTTP connection will show the certstream introduction and frontpage.

## Internals

The structure of the application is pretty simple, and is essentially entirely outlined in the [supervisor configuration](https://github.com/CaliDog/certstream-server/blob/master/lib/supervisor.ex#L11-L19).

The dataflow basically looks like this

```
               CertificateBuffer
                      |
HTTP Watcher \        |        / Websocket Connection Process
HTTP Watcher  - ClientManager -  Websocket Connection Process
HTTP Watcher /                 \ Websocket Connection Process

```
### HTTP Watchers
First we spin up 1 process for every entry in the [known CTL list from the CT project](https://www.gstatic.com/ct/log_list/all_logs_list.json), with each of them being responsible for sleeping for 10 seconds and checking to see if the top of the merkle tree has changed. Once a difference has been found, they go out and download the certificate data, parsing it and coercing it to a hashmap structure using [the EasySSL library](https://github.com/CaliDog/EasySSL) and sending it to the ClientManager.

### ClientManager
This agent is responsible for brokering communication between the CT watchers and the currently connected websocket clients. Certificates are broadcast to websocket connection processes through an erlang [pobox](https://github.com/ferd/pobox) in order to properly load-shed when a slow client isn't reading certificates fast enough. The ClientManager also sends a copy of every certificate received to the CertificateBuffer.

### CertificateBuffer
This agent is responsible for keeping a ring-buffer in memory of the most recently seen 25 certificates, as well as counting the certificates processed by Certstream.

### Websocket Connection Process
Under the hood we use the erlang library [Cowboy](https://github.com/ninenines/cowboy) to handle static content serving, the json APIs, and websocket connections. There's nothing too special about them other than they're assigned a paired pobox at the start of every connection.

## HTTP Routes

`/latest.json` - Get the most recent 25 certificates CertStream has seen

`/example.json` - Get the most recent certificate CertStream has seen

## Data Structure

**Certificate Updates**

```
{
    "message_type": "certificate_update",
    "data": {
        "update_type": "X509LogEntry",
        "leaf_cert": {
            "subject": {
                "aggregated": "/CN=e-zigarette-liquid-shop.de",
                "C": null,
                "ST": null,
                "L": null,
                "O": null,
                "OU": null,
                "CN": "e-zigarette-liquid-shop.de"
            },
            "extensions": {
                "keyUsage": "Digital Signature, Key Encipherment",
                "extendedKeyUsage": "TLS Web Server Authentication, TLS Web Client Authentication",
                "basicConstraints": "CA:FALSE",
                "subjectKeyIdentifier": "AC:4C:7B:3C:E9:C8:7F:CB:E2:7D:5D:64:F2:25:0C:89:C2:AE:F0:5E",
                "authorityKeyIdentifier": "keyid:A8:4A:6A:63:04:7D:DD:BA:E6:D1:39:B7:A6:45:65:EF:F3:A8:EC:A1\n",
                "authorityInfoAccess": "OCSP - URI:http://ocsp.int-x3.letsencrypt.org\nCA Issuers - URI:http://cert.int-x3.letsencrypt.org/\n",
                "subjectAltName": "DNS:e-zigarette-liquid-shop.de, DNS:www.e-zigarette-liquid-shop.de",
                "certificatePolicies": "Policy: 2.23.140.1.2.1\nPolicy: 1.3.6.1.4.1.44947.1.1.1\n  CPS: http://cps.letsencrypt.org\n  User Notice:\n    Explicit Text: This Certificate may only be relied upon by Relying Parties and only in accordance with the Certificate Policy found at https://letsencrypt.org/repository/\n"
            },
            "not_before": 1508123861.0,
            "not_after": 1515899861.0,
            "as_der": "::BASE64_DER_CERT::",
            "all_domains": [
                "e-zigarette-liquid-shop.de",
                "www.e-zigarette-liquid-shop.de"
            ]
        },
        "chain": [
            {
                "subject": {
                    "aggregated": "/C=US/O=Let's Encrypt/CN=Let's Encrypt Authority X3",
                    "C": "US",
                    "ST": null,
                    "L": null,
                    "O": "Let's Encrypt",
                    "OU": null,
                    "CN": "Let's Encrypt Authority X3"
                },
                "extensions": {
                    "basicConstraints": "CA:TRUE, pathlen:0",
                    "keyUsage": "Digital Signature, Certificate Sign, CRL Sign",
                    "authorityInfoAccess": "OCSP - URI:http://isrg.trustid.ocsp.identrust.com\nCA Issuers - URI:http://apps.identrust.com/roots/dstrootcax3.p7c\n",
                    "authorityKeyIdentifier": "keyid:C4:A7:B1:A4:7B:2C:71:FA:DB:E1:4B:90:75:FF:C4:15:60:85:89:10\n",
                    "certificatePolicies": "Policy: 2.23.140.1.2.1\nPolicy: 1.3.6.1.4.1.44947.1.1.1\n  CPS: http://cps.root-x1.letsencrypt.org\n",
                    "crlDistributionPoints": "\nFull Name:\n  URI:http://crl.identrust.com/DSTROOTCAX3CRL.crl\n",
                    "subjectKeyIdentifier": "A8:4A:6A:63:04:7D:DD:BA:E6:D1:39:B7:A6:45:65:EF:F3:A8:EC:A1"
                },
                "not_before": 1458232846.0,
                "not_after": 1615999246.0,
                "as_der": "::BASE64_DER_CERT::"
            },
            {
                "subject": {
                    "aggregated": "/O=Digital Signature Trust Co./CN=DST Root CA X3",
                    "C": null,
                    "ST": null,
                    "L": null,
                    "O": "Digital Signature Trust Co.",
                    "OU": null,
                    "CN": "DST Root CA X3"
                },
                "extensions": {
                    "basicConstraints": "CA:TRUE",
                    "keyUsage": "Certificate Sign, CRL Sign",
                    "subjectKeyIdentifier": "C4:A7:B1:A4:7B:2C:71:FA:DB:E1:4B:90:75:FF:C4:15:60:85:89:10"
                },
                "not_before": 970348339.0,
                "not_after": 1633010475.0,
                "as_der": "::BASE64_DER_CERT::"
            }
        ],
        "cert_index": 19587936,
        "seen": 1508483726.8601687,
        "source": {
            "url": "mammoth.ct.comodo.com",
            "name": "Comodo 'Mammoth' CT log"
        }
    }
}
```
