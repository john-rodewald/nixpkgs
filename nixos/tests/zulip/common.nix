# Common setup for the Zulip NixOS tests: a single node running a complete
# Zulip server behind nginx with snakeoil TLS certificates, plus python
# helpers to talk to the Zulip API from the test script.
{ pkgs }:
let
  dummySecret = pkgs.writeText "dummy-secret" "1c17f80d5c46d53254e72a9d6398597828900c6eb9d2871234f487ef7c3c";

  certs = import ../common/acme/server/snakeoil-certs.nix;

  inherit (certs) domain;
in
rec {
  inherit certs domain;

  module =
    { lib, ... }:
    {
      virtualisation.memorySize = 4096;

      security.pki.certificateFiles = [
        certs.ca.cert
      ];

      services.nginx.virtualHosts."${domain}" = {
        enableACME = lib.mkForce false;
        sslCertificate = certs."${domain}".cert;
        sslCertificateKey = certs."${domain}".key;
      };

      networking.extraHosts = ''
        127.0.0.1 ${domain}
        127.0.0.1 zulipinternal.${domain}
      '';

      services.zulip = {
        enable = true;
        enablePostgresqlLocally = true;

        host = domain;

        tornadoPort = 8994;

        zulipSettings = {
          EXTERNAL_HOST = domain;
          ZULIP_SERVICE_PUSH_NOTIFICATIONS = false;
          ZULIP_SERVICE_SUBMIT_USAGE_STATISTICS = false;
          ZULIP_ADMINISTRATOR = "admin@zulip.test";
        };

        camoKeyFile = dummySecret;
        sharedSecretKeyFile = dummySecret;
        secretKeyFile = dummySecret;
        avatarSaltKeyFile = dummySecret;
        rabbitmqPasswordFile = dummySecret;
      };
    };

  scriptPreamble = ''
    import json
    import sys

    def parse_response(response, must_succeed=True, must_fail=False):
      api_response = json.loads(response)

      if api_response["result"] == "success" and must_fail:
        sys.exit(1)

      if api_response["result"] != "success" and must_succeed:
        sys.exit(1)

      return api_response

    def send_msg():
      return parse_response(zulip.succeed(
        f"""
        curl -X POST https://${domain}/api/v1/messages \
          -u admin@example.org:{api_key} \
          --data-urlencode type=stream \
          --data-urlencode 'to="Denmark"' \
          --data-urlencode topic=Castle \
          --data-urlencode 'content=I come not, friends, to steal away your hearts.'
        """
      ))["id"]

    def get_message_by_id(msg_id, must_succeed = True, must_fail = False):
      # Read message
      return parse_response(zulip.succeed(
        f"""
        curl -sSX GET -G https://${domain}/api/v1/messages \
          -u admin@example.org:{api_key} \
          --data-urlencode message_ids=[{msg_id}] \
          --data-urlencode 'narrow=[{{"operand": "Denmark", "operator": "channel"}}]' \
          --data-urlencode allow_empty_topic_name=true
        """
      ), must_succeed, must_fail)

    start_all()
    zulip.wait_for_unit("nginx.service")
    zulip.wait_for_unit("zulip.target")
    zulip.wait_for_open_port(8994)
    zulip.succeed("zulip-manage create_realm ''' admin@example.org admin --password adminpassword")
    zulip.succeed("curl -k -f https://${domain}/")
    print(zulip.succeed("zulip-manage show_admins -r 2"))

    api_response = parse_response(zulip.succeed("curl -sSX POST https://${domain}/api/v1/fetch_api_key --data-urlencode username=admin@example.org --data-urlencode password=adminpassword"))
    api_key = api_response["api_key"]
    user_id = api_response["user_id"]

    zulip.succeed("zulip-manage change_user_role -r 2 admin@example.org can_create_users")
  '';
}
