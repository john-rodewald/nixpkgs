# Tests the tornado-based real time push system by receiving a sent message
# through an event queue.
{ pkgs, lib, ... }:
let
  common = import ./common.nix { inherit pkgs; };
  inherit (common) domain;
in
{
  name = "zulip-tornado";
  meta.maintainers = with lib.maintainers; [ john-rodewald ];

  nodes = {
    zulip = {
      imports = [ common.module ];
      environment.systemPackages = [
        (pkgs.writers.writePython3Bin "zulip_async_send_receive"
          {
            libraries = [
              pkgs.python3.pkgs.zulip
            ];
          }
          ''
            import sys
            import threading
            import zulip
            from time import sleep
            from queue import Queue


            client = zulip.Client(
                site="https://${domain}",
                email=sys.argv[1],
                api_key=sys.argv[2],
                cert_bundle="/etc/ssl/certs/ca-bundle.crt",
            )

            q = Queue()


            def run_event():

                def handle(msg):
                    q.put(msg, block=False)

                client.call_on_each_message(handle)


            threading.Thread(target=run_event, daemon=True).start()

            sleep(5)

            request = {
                "type": "stream",
                "to": "Denmark",
                "topic": "Castle",
                "content": "I come not, friends, to steal away your hearts.",
            }
            result = client.send_message(request)
            if q.get(timeout=5)["id"] != result["id"]:
                print("received wrong message")
                sys.exit(1)
          ''
        )
      ];
    };
  };

  testScript = ''
    ${common.scriptPreamble}

    # Create channel
    parse_response(zulip.succeed(
      f"""
      curl -sSX POST https://${domain}/api/v1/channels/create \
        -u admin@example.org:{api_key} \
        --data-urlencode 'name=Denmark' \
        --data-urlencode 'subscribers=[{user_id}]'
      """
    ))

    print(zulip.succeed(f"zulip_async_send_receive admin@example.org {api_key}"))
  '';
}
