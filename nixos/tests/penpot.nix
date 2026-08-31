{ lib, pkgs, ... }:

{
  name = "penpot";
  meta.maintainers = [ ];

  nodes.machine =
    { pkgs, ... }:
    {
      virtualisation.memorySize = 4096;
      virtualisation.cores = 2;
      virtualisation.diskSize = 4096;

      services.penpot = {
        enable = true;
        domain = "localhost";
        # test-only secret; use a proper secret manager in production
        secretKeyFile = pkgs.writeText "penpot-test-secret" ''
          PENPOT_SECRET_KEY=nixos-test-insecure-secret-key
        '';
      };

      environment.systemPackages = [ pkgs.penpot ];
    };

  testScript = ''
    machine.wait_for_unit("penpot-backend.service")
    machine.wait_for_unit("penpot-exporter.service")
    machine.wait_for_unit("nginx.service")

    # the backend needs a while for database migrations
    machine.wait_for_open_port(6060, timeout=600)
    machine.wait_until_succeeds("curl -sf http://localhost/readyz", timeout=300)

    machine.wait_for_open_port(6061)

    with subtest("frontend is served"):
        index = machine.succeed("curl -sf http://localhost/")
        assert "penpot" in index.lower(), "index.html does not look like penpot"

        config_js = machine.succeed("curl -sf http://localhost/js/config.js")
        assert "penpotFlags" in config_js, "config.js is not the generated runtime config"

        machine.succeed("curl -sfo /dev/null http://localhost/js/main.js")
        machine.succeed("curl -sfo /dev/null http://localhost/js/render-wasm.wasm")

    with subtest("profile can be created with penpot-manage"):
        machine.succeed(
            "penpot-manage create-profile "
            "-e test@example.com -n testuser -p secretpassword"
        )

    with subtest("login works"):
        # the response is transit+json encoded
        response = machine.succeed(
            "curl -sf -X POST http://localhost/api/rpc/command/login-with-password "
            "-H 'Content-Type: application/json' "
            "-d '{\"~:email\": \"test@example.com\", \"~:password\": \"secretpassword\"}' "
            "-D /tmp/login-headers"
        )
        assert "test@example.com" in response, f"unexpected login response: {response}"
        headers = machine.succeed("cat /tmp/login-headers")
        assert "auth-token" in headers, "login did not set an auth cookie"
  '';
}
