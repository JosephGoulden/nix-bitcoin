# netns IP addresses
bitcoind_ip = "169.254.1.12"
clightning_ip = "169.254.1.13"
lnd_ip = "169.254.1.14"
liquidd_ip = "169.254.1.15"
electrs_ip = "169.254.1.16"
sparkwallet_ip = "169.254.1.17"
lightningcharge_ip = "169.254.1.18"
nanopos_ip = "169.254.1.19"
recurringdonations_ip = "169.254.1.20"
nginx_ip = "169.254.1.21"
lightningloop_ip = "169.254.1.22"
nbxplorer_ip = "169.254.1.23"
btcpayserver_ip = "169.254.1.24"


def electrs():
    machine.wait_until_succeeds(
        "ip netns exec nb-electrs nc -z localhost 4224"
    )  # prometeus metrics provider


def nbxplorer():
    machine.wait_until_succeeds("ip netns exec nb-nbxplorer nc -z %s 24444" % nbxplorer_ip)


def btcpayserver():
    machine.wait_until_succeeds("ip netns exec nb-btcpayserver nc -z %s 23000" % btcpayserver_ip)
    # test lnd custom macaroon
    assert_matches(
        'ip netns exec nb-btcpayserver sudo -u btcpayserver curl -s --cacert /secrets/lnd-cert --header "Grpc-Metadata-macaroon: $(xxd -ps -u -c 1000 /run/lnd/btcpayserver.macaroon)" -X GET https://%s:8080/v1/getinfo | jq'
        % lnd_ip,
        '"version"',
    )


def spark_wallet():
    machine.wait_until_succeeds("ip netns exec nb-spark-wallet nc -z %s 9737" % sparkwallet_ip)
    spark_auth = re.search("login=(.*)", succeed("cat /secrets/spark-wallet-login"))[1]
    assert_matches(
        f"ip netns exec nb-spark-wallet curl -s {spark_auth}@%s:9737" % sparkwallet_ip, "Spark"
    )


def lightning_charge():
    machine.wait_until_succeeds("ip netns exec nb-nanopos nc -z %s 9112" % lightningcharge_ip)
    charge_auth = re.search("API_TOKEN=(.*)", succeed("cat /secrets/lightning-charge-env"))[1]
    assert_matches(
        f"ip netns exec nb-nanopos curl -s api-token:{charge_auth}@%s:9112/info | jq"
        % lightningcharge_ip,
        '"id"',
    )


def nanopos():
    machine.wait_until_succeeds("ip netns exec nb-lightning-charge nc -z %s 9116" % nanopos_ip)
    assert_matches("ip netns exec nb-lightning-charge curl %s:9116" % nanopos_ip, "tshirt")


def web_index():
    machine.wait_until_succeeds("ip netns exec nb-nginx nc -z localhost 80")
    assert_matches("ip netns exec nb-nginx curl localhost", "nix-bitcoin")
    assert_matches("ip netns exec nb-nginx curl -L localhost/store", "tshirt")


def prestop():
    ping_bitcoind = "ip netns exec nb-bitcoind ping -c 1 -w 1"
    ping_nanopos = "ip netns exec nb-nanopos ping -c 1 -w 1"
    ping_nbxplorer = "ip netns exec nb-nbxplorer ping -c 1 -w 1"

    # Positive ping tests (non-exhaustive)
    machine.succeed(
        "%s %s &&" % (ping_bitcoind, bitcoind_ip)
        + "%s %s &&" % (ping_bitcoind, clightning_ip)
        + "%s %s &&" % (ping_bitcoind, lnd_ip)
        + "%s %s &&" % (ping_bitcoind, liquidd_ip)
        + "%s %s &&" % (ping_bitcoind, nbxplorer_ip)
        + "%s %s &&" % (ping_nbxplorer, btcpayserver_ip)
        + "%s %s &&" % (ping_nanopos, lightningcharge_ip)
        + "%s %s &&" % (ping_nanopos, nanopos_ip)
        + "%s %s" % (ping_nanopos, nginx_ip)
    )

    # Negative ping tests (non-exhaustive)
    machine.fail(
        "%s %s ||" % (ping_bitcoind, sparkwallet_ip)
        + "%s %s ||" % (ping_bitcoind, lightningloop_ip)
        + "%s %s ||" % (ping_bitcoind, lightningcharge_ip)
        + "%s %s ||" % (ping_bitcoind, nanopos_ip)
        + "%s %s ||" % (ping_bitcoind, recurringdonations_ip)
        + "%s %s ||" % (ping_bitcoind, nginx_ip)
        + "%s %s ||" % (ping_nanopos, bitcoind_ip)
        + "%s %s ||" % (ping_nanopos, clightning_ip)
        + "%s %s ||" % (ping_nanopos, lnd_ip)
        + "%s %s ||" % (ping_nanopos, lightningloop_ip)
        + "%s %s ||" % (ping_nanopos, liquidd_ip)
        + "%s %s ||" % (ping_nanopos, electrs_ip)
        + "%s %s ||" % (ping_nanopos, sparkwallet_ip)
        + "%s %s ||" % (ping_nanopos, recurringdonations_ip)
        + "%s %s" % (ping_nanopos, btcpayserver_ip)
    )

    # test that netns-exec can't be run for unauthorized namespace
    machine.fail("netns-exec nb-electrs ip a")

    # test that netns-exec drops capabilities
    assert_full_match(
        "su operator -c 'netns-exec nb-bitcoind capsh --print | grep Current '", "Current: =\n"
    )

    # test that netns-exec can not be executed by users that are not operator
    machine.fail("sudo -u clightning netns-exec nb-bitcoind ip a")


extra_tests = {
    "electrs": electrs,
    "nbxplorer": nbxplorer,
    "btcpayserver": btcpayserver,
    "spark-wallet": spark_wallet,
    "lightning-charge": lightning_charge,
    "nanopos": nanopos,
    "web-index": web_index,
    "prestop": prestop,
}

run_tests(extra_tests)
