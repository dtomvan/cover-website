{
  pkgs,
  lib,
  config,
  ...
}:

let
  php = pkgs.php83;
in
{
  env.APP_PHOTOS_SCALED_URL = 1;
  packages = builtins.attrValues {
    inherit (php.packages) composer;
    inherit (pkgs) symfony-cli;
  };
  dotenv.enable = true;

  languages.javascript = {
    enable = true;
    # NodeJS 18 is EOL
    package = pkgs.nodejs_24;
    nodejs.enable = true;
    npm.enable = true;
    npm.install.enable = true;
  };

  services.postgres = {
    enable = true;
    initialDatabases = lib.singleton {
      name = "webcie";
      user = "webcie";
      pass = "webcie"; # it's a devserver it's fine
      initialSQL = builtins.readFile ./data/webcie-minimal.sql;
    };
    listen_addresses = "localhost";
    settings = {
      bgwriter_flush_after = 0;
      backend_flush_after = 0;
      fsync = "off";
      wal_writer_flush_after = 0;
      checkpoint_flush_after = 0;
    };
  };

  languages.php = {
    enable = true;
    lsp.enable = true;
    packages = {
      inherit (php.packages) composer;
    };
    package = php.buildEnv {
      extensions =
        { all, enabled }:
        with all;
        enabled
        ++ [
          bcmath
          curl
          intl
          imagick
          mbstring
          pgsql
          xml
          zip
        ];
    };
  };

  tasks = {
    # the below are just to get the initial run working, updates to dependencies should be done manually afterwards
    "dev:composer_install" = {
      exec = "[ -d vendor/symfony ] || composer install";
      before = [ "devenv:enterShell" ];
    };
    "dev:npm_run_dev" = {
      exec = "[ -d public/build ] || npm run dev";
      after = [ "devenv:enterShell" ];
    };
  };

  processes.symfony = {
    exec = "symfony server:start --port=${toString config.processes.symfony.ports.http.value}";
    ports.http.allocate = 8000;
  };

  enterShell =
    #bash
    ''
      doFile() {
        if ! [ -f "$2" ]; then
          echo "Warning: $2 got initialized. Please adjust it as expected."
          cp "$1" "$2"
        fi
      }
      doFile .env .env.local
      doFile .env.test .env.test.local
      doFile config.js config.dev.js
      sed -i -e 's|^DB_PASSWORD=$|\0webcie|' .env.local

      if ! [ -f completion.sh ]; then
        php bin/console completion bash | sed '/^Warning:/d' > completion.sh
      fi
      source completion.sh
    '';
}
