use Mix.Config

config :ctwatcher,
    log_list: "https://www.gstatic.com/ct/log_list/all_logs_list.json",
    bad_ct_servers: [
    "alpha.ctlogs.org/", "clicky.ct.letsencrypt.org/", "ct.akamai.com/", "ct.filippo.io/behindthesofa/",
    "ct.gdca.com.cn/", "ct.izenpe.com/", "ct.izenpe.eus/", "ct.sheca.com/", "ct.startssl.com/", "ct.wosign.com/",
    "ctserver.cnnic.cn/", "ctlog.api.venafi.com/", "ctlog.gdca.com.cn/", "ctlog.sheca.com/", "ctlog.wosign.com/",
    "ctlog2.wosign.com/", "flimsy.ct.nordu.net:8080/", "log.certly.io/", "nessie2021.ct.digicert.com/log/",
    "plausible.ct.nordu.net/", "www.certificatetransparency.cn/ct/", "ct.googleapis.com/testtube/",
    "ct.googleapis.com/daedalus/"
  ]

config :logger, level: :info, backends: [:console]
