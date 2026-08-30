{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.zulip;
in
{
  config = lib.mkIf (cfg.enable && cfg.enablePostgresqlLocally) {
    services.postgresql = {
      enable = true;
      extensions = _: [
        (pkgs.runCommand "hunspell-pg-dict" { } ''
          mkdir -p $out/share/postgresql/tsearch_data
          ln -nsf ${pkgs.hunspellDicts.en_US}/share/hunspell/en_US.dic $out/share/postgresql/tsearch_data/en_us.dict
          ln -nsf ${pkgs.hunspellDicts.en_US}/share/hunspell/en_US.aff $out/share/postgresql/tsearch_data/en_us.affix
          cp ${cfg.package}/puppet/zulip/files/postgresql/zulip_english.stop $out/share/postgresql/tsearch_data/zulip_english.stop
        '')
      ];
      ensureDatabases = [
        "zulip"
      ];
      ensureUsers = [
        {
          name = "zulip";
          ensureDBOwnership = true;
        }
      ];
    };
  };
}
