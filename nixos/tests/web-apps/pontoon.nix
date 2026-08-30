{ pkgs, ... }:

let
  certs = import ../common/acme/server/snakeoil-certs.nix;

  serverDomain = certs.domain;

  admin = {
    username = "admin";
    password = "snakeoilpass";
    email = "pontoon@example.org";
  };
in
{
  name = "pontoon";
  meta.maintainers = [ ];

  nodes.server =
    { pkgs, lib, ... }:
    {
      virtualisation.memorySize = 2048;

      services.pontoon = {
        enable = true;
        localDomain = "${serverDomain}";
        secretKeyFile = pkgs.writeText "pontoon-django-secret" "thisissnakeoilsecretwithmorethan50characterscorrecthorsebatterystaple";
      };

      services.nginx.virtualHosts."${serverDomain}" = {
        enableACME = lib.mkForce false;
        sslCertificate = certs."${serverDomain}".cert;
        sslCertificateKey = certs."${serverDomain}".key;
      };

      security.pki.certificateFiles = [ certs.ca.cert ];

      networking.hosts."::1" = [ "${serverDomain}" ];
      networking.firewall.allowedTCPPorts = [
        80
        443
      ];

      users.users.pontoon.shell = pkgs.bashInteractive;
    };

  nodes.client =
    { pkgs, nodes, ... }:
    {
      networking.hosts."${nodes.server.networking.primaryIPAddress}" = [ "${serverDomain}" ];

      security.pki.certificateFiles = [ certs.ca.cert ];
    };

  testScript = ''
    import json

    start_all()
    server.wait_for_unit("pontoon.socket")
    server.wait_until_succeeds("curl -fL https://${serverDomain}/")

    # The Django admin of a fresh instance is only reachable after login
    server.succeed(
        "sudo -iu pontoon -- env DJANGO_SUPERUSER_PASSWORD='${admin.password}' "
        + "pontoon-manage createsuperuser --no-input --username ${admin.username} --email ${admin.email}"
    )

    client.wait_for_unit("multi-user.target")

    # The unauthenticated read-only API should respond with valid JSON
    result = json.loads(
        client.succeed("curl -f https://${serverDomain}/api/v2/locales/")
    )
    assert "results" in result, f"unexpected API response: {result}"

    # The static files built into the package should be served with the
    # hashed names from the whitenoise manifest.
    client.succeed("curl -f https://${serverDomain}/static/translate.html")

    server.succeed("sudo -iu pontoon -- pontoon-manage check")
  '';
}
