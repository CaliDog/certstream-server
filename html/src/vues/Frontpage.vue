<template>
    <div class="main-wrapper">
        <!-- <top-panel></top-panel> -->
        <section class="section top-panel">
            <div class="container">
                <div class="columns">
                    <div class="column"></div>
                    <div class="column splash">
                        <h1 class="title animated fadeInDown">
                            CERTSTREAM
                        </h1>
                        <h2 class="subtitle animated fadeIn slow delayed">
                            Real-time <a href="https://www.certificate-transparency.org/what-is-ct">certificate transparency log</a> update stream.
                            <br>
                            See SSL certificates as they're issued in real time.
                        </h2>
                        <a @click="scrollDown" class="button learn-more animated fadeIn slow delayed">Learn More </i></a>
                    </div>
                </div>
            </div>
        </section>

        <img id="rolling-transition" class="transition" src="../assets/rolling-transition.png">

        <!-- <intro-panel></intro-panel> -->
        <section class="section intro-panel" id="intro-panel">
            <div class="container has-text-centered">
                <div class="columns">
                    <div class="column has-text-centered">
                        <img class="overview" src="../assets/certstream-overview.png">
                    </div>
                    <div class="column right-column">
                        <p class="title">TL;DR</p>
                        <p class="content">
                            CertStream is an intelligence feed that gives you real-time updates from the <a
                                href="https://www.certificate-transparency.org/what-is-ct">Certificate
                            Transparency Log network</a>, allowing you to use it as a building block to make tools that react to new certificates being
                            issued in real time. We do all the hard work of watching, aggregating, and parsing the transparency logs, and give you super simple
                            libraries that enable you to do awesome things with minimal effort.
                            <br><br>
                            It's our way of saying "thank you" to the amazing security community in general, as well as a
                            good way to give people a taste of the sort of intelligence feeds that are powering our flagship
                            product - <a href="https://phishfinder.io" target="_blank">PhishFinder</a>.
                        </p>
                    </div>
                </div>
            </div>
        </section>

        <feed-watcher></feed-watcher>

        <!-- <get-started-panel></get-started-panel> -->
        <section class="section get-started-panel">
            <div class="container has-text-centered get-started-content">
                <p class="title">GET STARTED</p>
                <div class="container has-text-centered">
                    <div class="columns">
                        <div class="column">
                            <div class="content-section">
                                <h2 id="install" class="small-title">Install CertStream</h2>
                                <p class="white-text">
                                    CertStream is hosted <a href="https://github.com/search?q=org%3ACaliDog+certstream">on Github</a> and we currently have libraries for <a href="https://github.com/CaliDog/certstream-python">Python</a>, <a href="https://github.com/CaliDog/certstream-js">Javascript</a>, <a href="https://github.com/CaliDog/certstream-go">Go</a>, and <a href="https://github.com/CaliDog/certstream-java">Java</a>.
                                    These libraries are intended to lower the barrier of entry to interacting with the <a href="https://www.certificate-transparency.org/what-is-ct">Certificate Transparency Log</a> network so you can craft simple but powerful analytics tools with just a few lines of code!
                                </p>
                                <div class="columns language-buttons">
                                    <div class="python column" :class="{active: activeLanguage == 'python'}" @mouseover="setLanguage('python')">
                                        <i :class="{colored: activeLanguage == 'python'}" class="devicon-python-plain"></i>
                                        <a target="_blank" href="https://github.com/CaliDog/certstream-python">Python</a>
                                    </div>

                                    <div class="javascript column" :class="{active: activeLanguage == 'javascript'}" @mouseover="setLanguage('javascript')">
                                        <i :class="{colored: activeLanguage == 'javascript'}" class="devicon-javascript-plain"></i>
                                        <a target="_blank" href="https://github.com/CaliDog/certstream-js">JavaScript</a>
                                    </div>

                                    <div class="go column" :class="{active: activeLanguage == 'go'}" @mouseover="setLanguage('go')">
                                        <i :class="{colored: activeLanguage == 'go'}" class="devicon-go-plain"></i>
                                        <a target="_blank" href="https://github.com/CaliDog/certstream-go">Go</a>
                                    </div>

                                    <div class="java column" :class="{active: activeLanguage == 'java'}" @mouseover="setLanguage('java')">
                                        <i :class="{colored: activeLanguage == 'java'}" class="devicon-java-plain"></i>
                                        <a target="_blank" href="https://github.com/CaliDog/certstream-java">Java</a>
                                    </div>
                                </div>
                                <div class="typer-wrapper">
                                    <p :class="{active: activeLanguage !== null && activeLanguage != 'java'}" class="content typer-content">
                                        <span class="dollar">$</span>
                                        <span class="typer"></span>
                                        <span ref="clipboard" @click="showToolTip" @mouseleave="hideToolTip" v-tooltip.top-center="{content: 'Copied to your clipboard!', trigger: 'manual', hide: 1000}" class="copy">
                                            <i class="fa fa-clipboard" aria-hidden="true"></i>
                                        </span>
                                    </p>
                                </div>

                            </div>
                            <div class="content-section cli-example">
                                <h2 id="cli" class="small-title">CertStream CLI</h2>

                                <p class="white-text">
                                    Installing the CLI is easy, all you have to do is <a @click="showPipInstructions">install the python library</a> and run it like any other program. It can be used to emit certificate data in a number of forms to be processed by other command line utilities (or just for storage). Pipe it into grep, sed, awk, jq, or any other utility to send alerts, gather statistics, or slice and dice certs as you want!
                                </p>

                                <div class="columns demo-gifs">
                                    <div class="column">
                                        <div class="columns demo-selector-wrapper">
                                            <div :class="{active: activeDemo.name == 'basic'}" @mouseover="setActiveDemo('basic')" class="column">
                                                <div class="demo-selector">
                                                    <p>Basic output</p>
                                                </div>
                                            </div>
                                            <div :class="{active: activeDemo.name == 'full'}" @mouseover="setActiveDemo('full')" class="column">
                                                <div class="demo-selector">
                                                    <p>Full SAN output</p>
                                                </div>
                                            </div>
                                            <div :class="{active: activeDemo.name == 'json'}" @mouseover="setActiveDemo('json')" class="column">
                                                <div class="demo-selector">
                                                    <p>JSON output mode + JQ</p>
                                                </div>
                                            </div>
                                        </div>
                                        <div class="demo-data-wrapper">
                                            <div class="command-wrapper">
                                                <p class="content typer-content">
                                                    <span class="dollar">$</span> <span class="demo-typer"></span>
                                                </p>
                                            </div>
                                            <div class="section-wrapper">
                                                <img @click="showExampleModal('basic')" class="demo-gif" :src="activeDemo.image">
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <!-- <data-structures></data-structures> -->
        <section class="section data-structures">
            <div class="container has-text-centered data-structures-content">
                <p class="title">SIMPLE(ISH) DATA</p>
                <div class="container has-text-centered">
                    <div class="columns">
                        <div class="column subsection-wrapper heartbeat-subsection">
                            <h2 class="small-title">Heartbeat Messsages</h2>
                            <div class="json-tree-wrapper">
                                <json-tree :data="heartbeat" :options="{maxDepth: 3}"></json-tree>
                            </div>
                        </div>
                    </div>
                    <div class="columns">
                        <div class="column subsection-wrapper update-subsection">
                            <h2 class="small-title">Certificate Update</h2>
                            <p>If you prefer the raw data blob, there's a live example <a target="_blank" href="https://certstream.calidog.io/example.json">here</a></p>
                            <div class="json-tree-wrapper">
                                <json-tree :data="exampleMessage" :level="3"></json-tree>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </section>

        <!-- <footer></footer> -->
        <section class="section footer">
            <div class="container has-text-centered">
                <div class="container has-text-centered">
                    <img class="doghead" src="../assets/doghead.png">
                    <p>Made with love by Cali Dog Security</p>
                    <span class="icons">
                        <a target="_blank" href="https://medium.com/cali-dog-security">
                            <i class="fa fa-medium" aria-hidden="true"></i>
                        </a>
                        <a target="_blank" href="https://github.com/calidog">
                            <i class="fa fa-github" aria-hidden="true"></i>
                        </a>
                    </span>
                    <p>© 2017 Cali Dog Security</p>
                </div>
            </div>
        </section>
    </div>
</template>


<script>
    import FeedWatcher from "./FeedWatcher.vue"
    import Vue from "vue"

    import VTooltip from 'v-tooltip'
    import VueScrollTo from 'vue-scrollto'
    import JsonTree from 'vue-json-tree'

    Vue.use(VTooltip);
    Vue.use(VueScrollTo);

    import Typed from 'typed.js';

    let heartbeat = {
        "message_type": "heartbeat",
        "timestamp": 1509613330.63217
    };

    let exampleMessage = {
        "message_type": "certificate_update",
        "data": {
            "update_type": "X509LogEntry",
            "leaf_cert": {
                "subject": {
                    "aggregated": "/CN=app.theaffairsite.com",
                    "C": null,
                    "ST": null,
                    "L": null,
                    "O": null,
                    "OU": null,
                    "CN": "app.theaffairsite.com"
                },
                "extensions": {
                    "keyUsage": "Digital Signature, Key Encipherment",
                    "extendedKeyUsage": "TLS Web Server Authentication, TLS Web Client Authentication",
                    "basicConstraints": "CA:FALSE",
                    "subjectKeyIdentifier": "01:BE:17:27:B8:D8:26:EF:E1:5C:7A:F6:14:A7:EA:B5:D0:D8:B5:9B",
                    "authorityKeyIdentifier": "keyid:A8:4A:6A:63:04:7D:DD:BA:E6:D1:39:B7:A6:45:65:EF:F3:A8:EC:A1\n",
                    "authorityInfoAccess": "OCSP - URI:http://ocsp.int-x3.letsencrypt.org\nCA Issuers - URI:http://cert.int-x3.letsencrypt.org/\n",
                    "subjectAltName": "DNS:app.theaffairsite.com",
                    "certificatePolicies": "Policy: 2.23.140.1.2.1\nPolicy: 1.3.6.1.4.1.44947.1.1.1\n  CPS: http://cps.letsencrypt.org\n  User Notice:\n    Explicit Text: This Certificate may only be relied upon by Relying Parties and only in accordance with the Certificate Policy found at https://letsencrypt.org/repository/\n"
                },
                "not_before": 1509908649.0,
                "not_after": 1517684649.0,
                "serial_number": "33980d1bef9b6a76cfc708e3139f55f33c5",
                "fingerprint": "95:CA:86:6B:B4:98:59:D2:EC:C7:CA:E8:42:70:80:0B:18:03:C7:75",
                "as_der": "MIIFDTCCA/WgAwIBAgISAzmA0b75tqds/HCOMTn1XzPFMA0GCSqGSIb3DQEBCwUAMEoxCzAJBgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MSMwIQYDVQQDExpMZXQncyBFbmNyeXB0IEF1dGhvcml0eSBYMzAeFw0xNzExMDUxOTA0MDlaFw0xODAyMDMxOTA0MDlaMCAxHjAcBgNVBAMTFWFwcC50aGVhZmZhaXJzaXRlLmNvbTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBALtVFBtTDAMq5yt/fRujvt3XbxjAb58NG6ThmXiFN/rDyysKt4tsqYcOQRZc5D/z4Pm8hI3lgLgmiZdxJF6zUnJ7GoYGdpPwItmYHmp1rWo735NNw16zFMKw9KPi1l+aiKQqZQA9hcgXpbWoyoIZBwHS5K5Id6/uXfLk//9nRxaKqDQzB1ZokIzlv0u+hJxKA4Q+JyOiZvfQKDBcC9lEXsNJ74MTkCwu75qjvHYHB4jSrb3aiCxn7q934bI+CFFjCK1adyGJVnckXOcumZrPo4c8GL0Fc1uwZ/PdLvU9/4d/PpbSHdaN94B3bVxCjio/KnSJ8QNJo60QoEOZ60aCFN0CAwEAAaOCAhUwggIRMA4GA1UdDwEB/wQEAwIFoDAdBgNVHSUEFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIwDAYDVR0TAQH/BAIwADAdBgNVHQ4EFgQUAb4XJ7jYJu/hXHr2FKfqtdDYtZswHwYDVR0jBBgwFoAUqEpqYwR93brm0Tm3pkVl7/Oo7KEwbwYIKwYBBQUHAQEEYzBhMC4GCCsGAQUFBzABhiJodHRwOi8vb2NzcC5pbnQteDMubGV0c2VuY3J5cHQub3JnMC8GCCsGAQUFBzAChiNodHRwOi8vY2VydC5pbnQteDMubGV0c2VuY3J5cHQub3JnLzAgBgNVHREEGTAXghVhcHAudGhlYWZmYWlyc2l0ZS5jb20wgf4GA1UdIASB9jCB8zAIBgZngQwBAgEwgeYGCysGAQQBgt8TAQEBMIHWMCYGCCsGAQUFBwIBFhpodHRwOi8vY3BzLmxldHNlbmNyeXB0Lm9yZzCBqwYIKwYBBQUHAgIwgZ4MgZtUaGlzIENlcnRpZmljYXRlIG1heSBvbmx5IGJlIHJlbGllZCB1cG9uIGJ5IFJlbHlpbmcgUGFydGllcyBhbmQgb25seSBpbiBhY2NvcmRhbmNlIHdpdGggdGhlIENlcnRpZmljYXRlIFBvbGljeSBmb3VuZCBhdCBodHRwczovL2xldHNlbmNyeXB0Lm9yZy9yZXBvc2l0b3J5LzANBgkqhkiG9w0BAQsFAAOCAQEASpYg0ISnbyXpqYYzgpLdc8o6GZwKrMDrTARm63aT+2L88s2Ff6JlMz4XRH3v4iihLpLVUDoiXbNUyggyVqbkQLFtHtgj8ScLvWku8n7l7lp6DpV7j3h6byM2K6a+jasJKplL+Zbqzng0RaJlFFnnBXYE9a5BW3JlOzNbOMUOSKTZSB0+6pmeohU1DhNiPQNqT2katRu0LLGbwtcEpsWyScVc3VkJVu1l0QNq8gC+F3C2MpBtiSjjz6umP1F1z+sXhUx9dFVzJ2nSk7XxZaH+DW4OAb6zjwqqYjjf2S0VQM398URhfYzLQX6xEyDuZG4W58g5SMtOWDnslPhlIax3LA==",
                "all_domains": [
                    "app.theaffairsite.com"
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
                    "serial_number": "a0141420000015385736a0b85eca708",
                    "fingerprint": "E6:A3:B4:5B:06:2D:50:9B:33:82:28:2D:19:6E:FE:97:D5:95:6C:CB",
                    "as_der": "MIIEkjCCA3qgAwIBAgIQCgFBQgAAAVOFc2oLheynCDANBgkqhkiG9w0BAQsFADA/MSQwIgYDVQQKExtEaWdpdGFsIFNpZ25hdHVyZSBUcnVzdCBDby4xFzAVBgNVBAMTDkRTVCBSb290IENBIFgzMB4XDTE2MDMxNzE2NDA0NloXDTIxMDMxNzE2NDA0NlowSjELMAkGA1UEBhMCVVMxFjAUBgNVBAoTDUxldCdzIEVuY3J5cHQxIzAhBgNVBAMTGkxldCdzIEVuY3J5cHQgQXV0aG9yaXR5IFgzMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAnNMM8FrlLke3cl03g7NoYzDq1zUmGSXhvb418XCSL7e4S0EFq6meNQhY7LEqxGiHC6PjdeTm86dicbp5gWAf15Gan/PQeGdxyGkOlZHP/uaZ6WA8SMx+yk13EiSdRxta67nsHjcAHJyse6cF6s5K671B5TaYucv9bTyWaN8jKkKQDIZ0Z8h/pZq4UmEUEz9l6YKHy9v6Dlb2honzhT+Xhq+w3Brvaw2VFn3EK6BlspkENnWAa6xK8xuQSXgvopZPKiAlKQTGdMDQMc2PMTiVFrqoM7hD8bEfwzB/onkxEz0tNvjj/PIzark5McWvxI0NHWQWM6r6hCm21AvA2H3DkwIDAQABo4IBfTCCAXkwEgYDVR0TAQH/BAgwBgEB/wIBADAOBgNVHQ8BAf8EBAMCAYYwfwYIKwYBBQUHAQEEczBxMDIGCCsGAQUFBzABhiZodHRwOi8vaXNyZy50cnVzdGlkLm9jc3AuaWRlbnRydXN0LmNvbTA7BggrBgEFBQcwAoYvaHR0cDovL2FwcHMuaWRlbnRydXN0LmNvbS9yb290cy9kc3Ryb290Y2F4My5wN2MwHwYDVR0jBBgwFoAUxKexpHsscfrb4UuQdf/EFWCFiRAwVAYDVR0gBE0wSzAIBgZngQwBAgEwPwYLKwYBBAGC3xMBAQEwMDAuBggrBgEFBQcCARYiaHR0cDovL2Nwcy5yb290LXgxLmxldHNlbmNyeXB0Lm9yZzA8BgNVHR8ENTAzMDGgL6AthitodHRwOi8vY3JsLmlkZW50cnVzdC5jb20vRFNUUk9PVENBWDNDUkwuY3JsMB0GA1UdDgQWBBSoSmpjBH3duubRObemRWXv86jsoTANBgkqhkiG9w0BAQsFAAOCAQEA3TPXEfNjWDjdGBX7CVW+dla5cEilaUcne8IkCJLxWh9KEik3JHRRHGJouM2VcGfl96S8TihRzZvoroed6ti6WqEBmtzw3Wodatg+VyOeph4EYpr/1wXKtx8/wApIvJSwtmVi4MFU5aMqrSDE6ea73Mj2tcMyo5jMd6jmeWUHK8so/joWUoHOUgwuX4Po1QYz+3dszkDqMp4fklxBwXRsW10KXzPMTZ+sOPAveyxindmjkW8lGy+QsRlGPfZ+G6Z6h7mjem0Y+iWlkYcV4PIWL1iwBi8saCbGS5jN2p8M+X+Q7UNKEkROb3N6KOqkqm57TH2H3eDJAkSnh6/DNFu0Qg=="
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
                    "serial_number": "44afb080d6a327ba893039862ef8406b",
                    "fingerprint": "DA:C9:02:4F:54:D8:F6:DF:94:93:5F:B1:73:26:38:CA:6A:D7:7C:13",
                    "as_der": "MIIDSjCCAjKgAwIBAgIQRK+wgNajJ7qJMDmGLvhAazANBgkqhkiG9w0BAQUFADA/MSQwIgYDVQQKExtEaWdpdGFsIFNpZ25hdHVyZSBUcnVzdCBDby4xFzAVBgNVBAMTDkRTVCBSb290IENBIFgzMB4XDTAwMDkzMDIxMTIxOVoXDTIxMDkzMDE0MDExNVowPzEkMCIGA1UEChMbRGlnaXRhbCBTaWduYXR1cmUgVHJ1c3QgQ28uMRcwFQYDVQQDEw5EU1QgUm9vdCBDQSBYMzCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAN+v6ZdQCINXtMxiZfaQguzH0yxrMMpb7NnDfcdAwRgUi+DoM3ZJKuM/IUmTrE4Orz5Iy2Xu/NMhD2XSKtkyj4zl93ewEnu1lcCJo6m67XMuegwGMoOifooUMM0RoOEqOLl5CjH9UL2AZd+3UWODyOKIYepLYYHsUmu5ouJLGiifSKOeDNoJjj4XLh7dIN9bxiqKqy69cK3FCxolkHRyxXtqqzTWMIn/5WgTe1QLyNau7Fqckh49ZLOMxt+/yUFw7BZy1SbsOFU5Q9D8/RhcQPGX69Wam40dutolucbY38EVAjqr2m7xPi71XAicPNaDaeQQmxkqtilX4+U9m5/wAl0CAwEAAaNCMEAwDwYDVR0TAQH/BAUwAwEB/zAOBgNVHQ8BAf8EBAMCAQYwHQYDVR0OBBYEFMSnsaR7LHH62+FLkHX/xBVghYkQMA0GCSqGSIb3DQEBBQUAA4IBAQCjGiybFwBcqR7uKGY3Or+Dxz9LwwmglSBd49lZRNI+DT69ikugdB/OEIKcdBodfpga3csTS7MgROSR6cz8faXbauX+5v3gTt23ADq1cEmv8uXrAvHRAosZy5Q6XkjEGB5YGV8eAlrwDPGxrancWYaLbumR9YbK+rlmM6pZW87ipxZzR8srzJmwN0jP41ZL9c8PDHIyh8bwRLtTcm1D9SZImlJnt1ir/md2cXjbDaJWFBM5JDGFoqgCWjBH4d1QB7wCCZAA62RjYJsWvIjJEubSfZGL+T0yjWW06XyxV3bqxbYoOb8VZRzI9neWagqNdwvYkQsEjgfbKbYK7p2CNTUQ"
                }
            ],
            "cert_index": 27910635,
            "seen": 1509912803.959279,
            "source": {
                "url": "sabre.ct.comodo.com",
                "name": "Comodo 'Sabre' CT log"
            }
        }
    };

    export default {
        name: 'frontpage',
        data() {
            return {
                activeLanguage: null,
                activeDemo: {},
                typer: null,
                languages: {
                    python: {install: "pip install certstream"},
                    javascript: {install: "npm install certstream"},
                    go: {install: "go get github.com/CaliDog/certstream-go"},
                    java: {install: "<a href='https://github.com/calidog/certstream-java#installing' target='_blank'>Click Here</a> for instructions (because Java 😓 ️)"},
                },
                demos: {
                    "basic": {
                        name: "basic",
                        command: "certstream",
                        image: require("../assets/demo1.gif")
                    },
                    "full": {
                        name: "full",
                        command: "certstream --full",
                        image: require("../assets/demo2.gif")
                    },
                    "json": {
                        name: "json",
                        command: "certstream --json | jq -r '.data | [.source.url, (.cert_index|tostring), .leaf_cert.subject.aggregated] | join(\",\")'",
                        image: require("../assets/demo3.gif")
                    }
                },
                heartbeat: heartbeat,
                exampleMessage: exampleMessage

            }
        },
        mounted() {
            this.typer = new Typed('.typer', {
                strings: ["Select a language above"],
                showCursor: false,
            });
            this.demoTyper = new Typed('.demo-typer', {
                strings: ["certstream"],
                showCursor: false,
            })
            this.activeDemo = this.demos['basic']
        },
        methods: {
            scrollDown (){
                this.$scrollTo("#intro-panel", 500);
            },
            setActiveDemo (demoName){
                if (this.demos[demoName] == this.activeDemo){return}

                this.activeDemo = this.demos[demoName];
                this.demoTyper.strings = [this.activeDemo.command];

                this.demoTyper.reset();
            },
            showPipInstructions(){
                this.$scrollTo("#install", 500);
                this.setLanguage("python");
            },
            showToolTip(){
                this.$refs.clipboard._tooltip.show();
                this.copyToClipboard(this.languages[this.activeLanguage].install);
            },
            hideToolTip(){
                setTimeout(this.$refs.clipboard._tooltip.hide, 1000)
            },
            setLanguage(lang) {
                if (this.activeLanguage === lang){return}

                this.activeLanguage = lang;

                this.typer.strings = [this.languages[lang].install];

                this.typer.reset();
            },
            copyToClipboard(text) {
                if (window.clipboardData && window.clipboardData.setData) {
                    // IE specific code path to prevent textarea being shown while dialog is visible.
                    return clipboardData.setData("Text", text);

                } else if (document.queryCommandSupported && document.queryCommandSupported("copy")) {
                    var textarea = document.createElement("textarea");
                    textarea.textContent = text;
                    textarea.style.position = "fixed";  // Prevent scrolling to bottom of page in MS Edge.
                    document.body.appendChild(textarea);
                    textarea.select();
                    try {
                        return document.execCommand("copy");  // Security exception may be thrown by some browsers.
                    } catch (ex) {
                        console.warn("Copy to clipboard failed.", ex);
                        return false;
                    } finally {
                        document.body.removeChild(textarea);
                    }
                }
            }
        },
        components: {
            FeedWatcher,
            JsonTree
        }
    }
</script>

<style lang="scss">

    @import url('../lib/json-tree.css');

    body {
        line-height: 1.8;
    }

    .splash{
        margin-top: -20vh;
    }

    @media screen and (max-width:768px) and (min-width:0px) {
        html{
            font-size: 12px;
        }
        a{
            border-bottom: 1px solid rgb(236, 240, 241) !important;
        }
        .main-wrapper{
            overflow: hidden;
        }
        .column.splash{
            text-align: center;
        }
        .typer-content{
            margin: 0;
        }
        .demo-selector-wrapper{
            .column{
                margin: 0 !important;
                .demo-selector{
                    border-radius: 0 !important;
                }
            }
        }
        .data-structures-content{
            padding: 10px !important;
        }
    }

    @media screen and (max-width:930px){
        .get-started-panel{
            padding: 0;
            .get-started-content{
                padding-right: 10px !important;
                padding-left: 10px !important;
            }
        }
        .title{
            font-size: 3rem !important;
        }
    }
    @media screen and (max-width:1155px) {
        .get-started-panel, .data-structures{
            padding-right: 0 !important;
            padding-left: 0 !important;
        }

    }


        .footer{
        color: #555555;
        background: #D7E7D4;
        font-weight: 700;
        padding-bottom: 3rem;
        .doghead{
            width: 111px;
            margin: 10px;
        }
        .icons{
            font-size: 26px;
            margin-bottom: 10px;
            display: block;
            a{
                padding: 10px;
                color: #555555;
                &:hover{
                    color: #1E82C8;
                }
            }
        }
    }


    .button.learn-more{
        background: #1AAF5D;
        border: none;
        padding: 14px 60px;
        border-radius: 50px;
        display: inline;
        color: #ECF0F1;
        font-weight: 700;
        font-size: 1.125rem;
        &:hover{
            box-shadow: 0 4px 16px 0 rgba(0, 0, 0, 0.2);
        }
        &:active{
            box-shadow: none;
        }
    }

    .cli-example{
        .columns{
            margin: 0;
        }
        .demo-gifs{
            color: #ECF0F1;

            .demo-gif{
                width: 100%;
                max-width: 100%;
                height: 100%;
                max-height: 100%;
                border-radius: 4px;
            }

            .demo-data-wrapper{
                background: #217C4B;
                margin-top: 30px;
                padding: 30px 20px 20px;
                border-radius: 4px;
            }

            .demo-selector-wrapper{
                margin-top: 30px;
                margin-bottom: 20px;
            }

            .command-wrapper{
                margin: 0;
            }

            .columns > .column.active .demo-selector{
                background: rgba(47, 49, 51, 1);
            }

            .demo-selector-wrapper .column{
                margin-right: 30px;
                &:last-child{
                    margin-right: 0;
                }
            }

            .demo-selector{
                background: rgba(47, 49, 51, 0.8);
                font-weight: 700;
                border-radius: 4px;
                padding: 1rem;
            }
            .column{
                text-align: center;
                padding: 0;
            }
            .dollar{
                opacity: 1 !important;
            }
            .typer-content{
                width: 100% !important;
                margin-bottom: 20px;
                display: inline-block;
                text-align: left;
            }
        }
    }

    .top-panel {
        @media screen and (max-width:768px) and (min-width:0px) {
            height: 90vh;
            background-attachment: scroll;
            .container .columns .column:first-child{
                display: none;
            }
            .subtitle, .title{
                text-align: center;
            }
        }

        background: url('../assets/certstream-bg.png') no-repeat center center fixed;
        background-size: cover;
        background-position-y: 0;

        display: flex;
        align-content: center;
        justify-content: center;
        height: 100vh;

        .container{
            margin: 0;
            width: 100%;
            display: flex;
            align-content: center;
            justify-content: center;
            .columns{
                width: 100%;
                display: flex;
                justify-content: center;
                align-items: center;
            }
        }

        .title {
            font-size: 4rem;
            color: #ECF0F1;
            margin-bottom: 48px;
        }

        .subtitle {
            font-weight: 700;
            font-size: 1.25rem;
            color: #ECF0F1;
            line-height: 1.6;
            margin-bottom: 2.5rem;
            a{
                color: #ECF0F1;
                border-bottom: 1px solid transparent;
                transition: all .5s;
                border-bottom: 1px dashed #ECF0F1;
                &:hover{
                    border-bottom: 1px solid #ECF0F1;
                }
            }
        }

    }

    .transition {
        display: block;
        margin-top: -80px;
        min-width: 100%;
    }

    .small-title {
        font-weight: 700;
        font-size: 1.125rem;
        color: #ECF0F1;
    }

    .content-section{
        margin-bottom: 80px;
    }

    .mobile-only-disclaimer{
        display: none;
    }

    .data-structures{
        .subsection-wrapper{
            width: 100%;

            &.heartbeat-subsection{
                margin-top: 20px;
                margin-bottom: 45px;
                h2{
                    margin-bottom: 20px;
                }
            }

            &>p{
                color: #ECF0F1;
                padding: 5px 0 20px;
                a{
                    font-weight: 600;
                }
            }
        }

        .json-tree{
            font-size: .9rem !important;
        }
        .json-tree-root{

            background: #333;
            color: #ECF0F1;
            min-width: 0;
            .json-tree-paired, .json-tree-row:hover{
                background-color: #3e3e3e;
            }
            .json-tree{
                color: #ECF0F1;
                .json-tree-value-number{
                    color: #1E82C8;
                }
                .json-tree-value-string{
                    color: #c66c66;
                }
            }

        }

        .data-structures-content{
            padding: 1rem 140px;
        }
        .content{
            padding: 13px 20px;
            background: #2E3032;
            border-radius: 2px;
        }
    }

    .intro-panel, .get-started-panel, .data-structures {
        &.data-structures{
            background: #179D53 !important;
        }
        background: #1AAF5D;
        padding: 75px 100px 64px 100px;

        @media screen and (max-width:768px) and (min-width:0px) {
            padding: 7rem 2.5rem;
            .overview{
                margin-top: 0 !important;
            }
            .title{
                text-align: center;
                font-size: 2.5rem !important;
            }
            .content{
                font-size: 1.5rem !important;
            }
        }

        .right-column{
            margin-top: 60px;
        }

        img.overview {
            margin-top: -1rem;
            max-height: 585px;
            max-width: 90vw;
            width: auto;
            height: auto;
        }

        .column {
            text-align: left;
        }

        .title {
            font-size: 1.5rem;
            color: #ECF0F1;
            letter-spacing: 2px;
        }

        .white-text{
            color: #ECF0F1;
            padding: 20px 1px 30px 1px;
        }
        .typer-wrapper{
            padding: 30px 20px;
            background: #217C4B;
            border-radius: 4px;
        }
        .content {
            font-size: 1rem;
            color: #ECF0F1;
            &.typer-content{
                margin-left: auto;
                margin-right: auto;
                position: relative;
                overflow: hidden;
                background: #ECECEC !important;
                color: #333 !important;
                a{
                    color: #333 !important;
                    border-bottom: 1px solid #333;
                    &:hover{
                        border-bottom: 2px solid #333;
                    }
                }
                &.active {
                    text-align: left;
                    span.dollar, span.copy{
                        opacity: 1
                    }
                    span.copy{
                        right: 0;
                        &:hover{
                            i{
                                color: #1AAF5D;
                            }
                        }
                    }
                }
                span.dollar, span.copy{
                    transition: all .25s;
                    opacity: 0;
                }
                span.dollar{
                    color: #c66c66;
                }
                span.copy{
                    cursor: pointer;
                    background: rgb(236, 240, 241);
                    color: #333;
                    position: absolute;
                    right: -2.6rem;
                    top: 0;
                    padding: 0.8rem;
                }
                span{
                    font-weight: 700
                }
            }
        }

        a {
            color: #ECF0F1;
            font-weight: 700;
            transition: border-bottom .25s;
            border-bottom: 1px solid rgba(236, 240, 241, .5);

            &:hover {
                border-bottom: 1px solid rgba(236, 240, 241, 1);
            }

        }
    }

    .get-started-panel{
        .column{
            max-width: 100%;
        }

        @media screen and (max-width:768px) and (min-width:0px) {
            padding: 0;
            .get-started-content{
                padding: 0 !important;
                p.title:first-child{
                    display: none;
                }
                .small-title{
                    font-size: 2.5rem !important;
                    text-align: center;
                }
                p.content{
                    font-size: 1.3rem !important;
                }
                p.typer-content{
                    max-width: 100%;
                    span.copy{
                        display: none;
                    }
                }
                .language-buttons .column{
                    margin-right: 0;
                    border-bottom: 1px solid #333;
                    border-radius: 0;
                    &:first-child{
                        border-top: 1px solid #333;
                    }
                }
            }
            .white-text{
                font-size: 1.5rem;
                padding: 1.5rem 2.5rem;
            }
            .mobile-only-disclaimer{
                display: block;
            }
        }

        padding-top: 100px;

        .language-buttons{
            max-width: 100%;
            margin: 25px auto 20px;
            .column{
                background: rgba(47, 49, 51, .8);
                transition: all .5s;
                color: #ecf0f1;
                font-weight: 700;
                font-size: 1.125rem;
                margin-right: 30px;
                display: flex;
                justify-content: center;
                align-items: center;
                flex-direction: row;
                text-align: center;
                position: relative;
                border-radius: 4px;

                &:last-child{
                    margin-right: 0;
                }
                i{
                    font-size: 2rem;
                    padding-right: 1rem;
                    transition: color .5s;
                    &:not(.colored){
                        color: #ecf0f1;
                    }
                }
                &.active{
                    background: rgba(47, 49, 51, 1);
                }
                &.go i.colored{
                    color: #7FC6E8;
                }
            }
        }

        p.title{
            padding-bottom: 60px;
        }
        .get-started-content{
            padding: 0 140px;
            .content{
                padding: 13px 20px;
                background: #2E3032;
                border-radius: 2px;
            }
        }
    }

    .demo-panel {
        @media screen and (max-width:768px) and (min-width:0px) {
            display: none;
        }
        background: #D7E7D4;
        display: flex;
        justify-content: center;
        flex-direction: column;
        align-items: center;
        padding-top: 90px;
        padding-bottom: 45px;

        .call-to-action {
            font-size: 1.5rem;
            color: #555555;
            font-weight: 700;
            p{
                letter-spacing: 2px;
            }
        }

        .connect-button{
            margin-top: -5px;
            margin-bottom: 40px;

            a.button {
                width: auto;
                height: auto;
                padding: 20px 42px;
                background: #1E82C8;
                border-radius: 4px;
                font-size: 1rem;
                color: #ECF0F1;
                font-weight: 700;
            }
        }
    }

    .slow {
        animation-duration: 3s;
    }

    .delayed {
        animation-delay: 1s;
    }

</style>
