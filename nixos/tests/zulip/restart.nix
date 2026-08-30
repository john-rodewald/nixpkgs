{ pkgs, lib, ... }:
let
  common = import ./common.nix { inherit pkgs; };
  inherit (common) domain;
in
{
  name = "zulip-restart";
  meta.maintainers = with lib.maintainers; [ john-rodewald ];

  nodes = {
    zulip = common.module;
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

    # Send message
    msg_id = send_msg()

    # Restart Zulip using its own restart script
    zulip.succeed("zulip-nsenter /var/lib/zulip/source/scripts/restart-server")

    # Read message
    read_msg = get_message_by_id(msg_id)

    # Check we read the right message
    if read_msg["messages"][0]["id"] != msg_id:
      sys.exit(1)
  '';
}
