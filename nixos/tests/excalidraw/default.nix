{ runTest }:

{
  caddy = runTest ./caddy.nix;
  nginx = runTest ./nginx.nix;
}
