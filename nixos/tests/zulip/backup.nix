{ pkgs, lib, ... }:
let
  common = import ./common.nix { inherit pkgs; };
  inherit (common) domain;
in
{
  name = "zulip-backup";
  meta.maintainers = with lib.maintainers; [ john-rodewald ];

  nodes = {
    zulip = {
      imports = [ common.module ];
      virtualisation.cores = 4;
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

    # Send message
    msg_id_backed = send_msg()

    zulip.succeed("zulip-manage backup --output /var/lib/zulip/backup.tar.gz")

    # Send a second message that should not be in the backup
    msg_id_not_backed = send_msg()

    # Restore backup

    zulip.succeed("zulip-restore /var/lib/zulip/backup.tar.gz")

    if len(get_message_by_id(msg_id_backed)["messages"]) != 1:
        sys.exit(2)
    if len(get_message_by_id(msg_id_not_backed)["messages"]) != 0:
        sys.exit(2)
  '';
}
