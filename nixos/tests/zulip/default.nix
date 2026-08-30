{ pkgs, lib, ... }:
let
  common = import ./common.nix { inherit pkgs; };
  inherit (common) domain;
in
{
  name = "zulip";
  meta.maintainers = with lib.maintainers; [ john-rodewald ];

  nodes = {
    zulip = common.module;
  };

  testScript =
    { nodes, ... }:
    let
      testCronJobs = builtins.map (k: "zulip.succeed(\"systemctl start ${k}.service\")") (
        builtins.filter (lib.hasPrefix "zulip-cron-") (builtins.attrNames nodes.zulip.systemd.services)
      );
    in
    ''
      ${common.scriptPreamble}

      # Create user

      regular_user_id = parse_response(zulip.succeed(
        f"""
        curl -sSX POST https://${domain}/api/v1/users \
          -u admin@example.org:{api_key} \
          --data-urlencode email=username@example.com \
          --data-urlencode password=lateteatoto1 \
          --data-urlencode 'full_name=New User'
        """
      ))["user_id"]

      # Create channel
      parse_response(zulip.succeed(
        f"""
        curl -sSX POST https://${domain}/api/v1/channels/create \
          -u admin@example.org:{api_key} \
          --data-urlencode 'name=Denmark' \
          --data-urlencode 'subscribers=[{user_id}, {regular_user_id}]'
        """
      ))

      # Send message
      msg_id = send_msg()

      # Read message
      read_msg = parse_response(zulip.succeed(
        f"""
        curl -sSX GET -G https://${domain}/api/v1/messages \
          -u admin@example.org:{api_key} \
          --data-urlencode anchor=newest \
          --data-urlencode num_before=1 \
          --data-urlencode num_after=1 \
          --data-urlencode 'narrow=[{{"operand": "Denmark", "operator": "channel"}}]' \
          --data-urlencode allow_empty_topic_name=true
        """
      ))

      # Check we read the right message
      if read_msg["messages"][0]["id"] != msg_id:
        sys.exit(1)

      # Test help
      zulip.succeed("curl -sSf https://${domain}/help/")

      # Test logrotate
      zulip.succeed("systemctl start logrotate.service")

      ${lib.concatLines testCronJobs}
    '';
}
