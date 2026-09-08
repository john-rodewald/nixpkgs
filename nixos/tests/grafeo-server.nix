{ lib, ... }:
{
  name = "grafeo-server";
  meta.maintainers = with lib.maintainers; [ ];

  nodes.machine = {
    services.grafeo-server = {
      enable = true;
      ensureDatabases = [ "analytics" ];
      settings.port = 7474;
    };
  };

  testScript = ''
    machine.start()
    machine.wait_for_unit("grafeo-server.service")
    machine.wait_for_open_port(7474)

    machine.succeed("curl -sf http://127.0.0.1:7474/health")

    machine.wait_until_succeeds(
        "curl -sf http://127.0.0.1:7474/db | grep -q analytics"
    )

    machine.succeed(
        "curl -sf -X POST http://127.0.0.1:7474/query "
        + "-H 'Content-Type: application/json' "
        + """-d '{"query": "INSERT (:Person {name: \\"Alice\\"})", "database": "analytics"}'"""
    )
    machine.succeed(
        "curl -sf -X POST http://127.0.0.1:7474/query "
        + "-H 'Content-Type: application/json' "
        + """-d '{"query": "MATCH (p:Person) RETURN p.name", "database": "analytics"}' """
        + "| grep -q Alice"
    )
  '';
}
