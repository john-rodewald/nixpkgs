{ zulip-package, LOCAL_UPLOADS_DIR }:
let
  includeHeaders = "include ${zulip-package}/puppet/zulip/files/nginx/zulip-include-common/headers;";
  includeImmutableHeaders = ''
    ${includeHeaders}
    add_header Cache-Control "public, max-age=31536000, immutable";
    add_header Access-Control-Allow-Origin *;
    add_header Timing-Allow-Origin *;
  '';

  # inlining puppet/zulip/nginx/zulip-include-common/proxy_longpolling because of include directive
  includeProxyLongpolling = ''
    ${includeProxy}
    proxy_buffering off;
    proxy_read_timeout 20m;
  '';

  includeProxy = "include ${zulip-package}/puppet/zulip/files/nginx/zulip-include-common/proxy;";

  # inlining puppet/zulip/files/nginx/zulip-include-common/tornado_cors_headers because of include directive
  includeTornadoCorsHeaders = ''
    ${includeHeaders}
    add_header Access-Control-Allow-Origin * always;
    add_header Access-Control-Allow-Headers Authorization always;
    add_header Access-Control-Allow-Methods 'OPTIONS, GET, DELETE' always;
  '';

  # inlining puppet/zulip/files/nginx/zulip-include-common/api_headers;
  includeApiHeaders = ''
    ${includeHeaders}
    add_header Access-Control-Allow-Origin * always;
    add_header Access-Control-Allow-Headers Authorization always;
    add_header Access-Control-Allow-Methods 'GET, POST, DELETE, PUT, PATCH, HEAD' always;
  '';

  includeUwsgi = "include ${zulip-package}/puppet/zulip/files/nginx/uwsgi_params;";

  # Shorthand
  apiUwsgiConfig = ''
    ${includeApiHeaders}
    ${includeUwsgi}
  '';
in
{
  # puppet/zulip/files/nginx/zulip-include-frontend/app
  # local-static is an unsupported feature FIXME: support the feature
  "/static/" = {
    alias = "${zulip-package.static}/";
    extraConfig = ''
      gzip_static on;
      ${includeHeaders}
      add_header Access-Control-Allow-Origin *;
      add_header Timing-Allow-Origin *;

      # Set a nonexistent path, so we just serve the nice Django 404 page.
      error_page 404 /django_static_404.html;

      # These files are hashed and thus immutable; cache them aggressively.
      # Django adds 12 hex digits; Webpack adds 20.
      location ~ '\.[0-9a-f]{12}\.|[./][0-9a-f]{20}\.' {
          ${includeImmutableHeaders}
      }
    '';
  };

  "= /help" = {
    return = "301 /help/";
  };
  # Redirect to links without the trailing slash except for root /help/.
  "~ ^(/help(?:/[^/\\s]+)+)/+$" = {
    return = "301 $1$is_args$args";
  };
  "/help/" = {
    alias = "${zulip-package}/starlight_help/dist/";
    extraConfig = ''
      gzip_static on;
      ${includeHeaders}
      add_header Access-Control-Allow-Origin *;
      add_header Timing-Allow-Origin *;

      error_page 404 /404.html;
      index /index.html;
      try_files $uri $uri/index.html =404;

      # These files are hashed and thus immutable; cache them aggressively.
      # https://github.com/Pagefind/pagefind/issues/747#issuecomment-2510564644
      # https://github.com/withastro/docs/blob/53603ad048e8aedbca1aed77bac8eb00dcada79d/src/content/docs/en/guides/integrations-guide/node.mdx?plain=1#L304
      location ~ ^/help/(pagefind/.*\.(?:pf_fragment|pf_index|pf_meta)|_astro/.*)$ {
          ${includeImmutableHeaders}
      }
    '';
  };

  "= /json/events" = {
    extraConfig = ''
      if ($request_method = 'OPTIONS') {
          # add_header does not propagate into/out of blocks, so this
          # include cannot be factored out
          ${includeHeaders}
          add_header Allow 'OPTIONS, GET, DELETE' always;
          return 204;
      }

      if ($request_method !~ ^(GET|DELETE)$ ) {
          # add_header does not propagate into/out of blocks, so this
          # include cannot be factored out
          ${includeHeaders}
          add_header Allow 'OPTIONS, GET, DELETE' always;
          return 405;
      }

      proxy_pass http://tornado;

      # inlining nginx/zulip-include-common/proxy_longpolling because of include directive
      ${includeProxyLongpolling}
    '';
  };
  "= /api/v1/events" = {
    extraConfig = ''
      if ($request_method = 'OPTIONS') {
          ${includeTornadoCorsHeaders}
          add_header Allow 'OPTIONS, GET, DELETE' always;
          return 204;
      }

      if ($request_method !~ ^(GET|DELETE)$ ) {
          ${includeHeaders}
          add_header Allow 'OPTIONS, GET, DELETE' always;
          return 405;
      }

      ${includeTornadoCorsHeaders}
      proxy_pass http://tornado;
      ${includeProxyLongpolling}
    '';
  };
  "~ ^/internal/tornado/(\\d+)(/.*)$" = {
    proxyPass = "http://tornado$1$2$is_args$args";
    extraConfig = ''
      internal;
      ${includeProxyLongpolling}
    '';
  };
  "/api/v1/tus" = {
    extraConfig = ''
      ${includeApiHeaders}
      ${includeProxy}
      # https://github.com/tus/tusd/blob/main/examples/nginx.conf
      # Disable request body size limits, and stream the request and
      # response from tusd directly.
      client_max_body_size    0;
      proxy_request_buffering off;
      proxy_buffering         off;
      proxy_pass              http://tusd;
    '';
  };

  "/" = {
    extraConfig = ''
      ${includeUwsgi}
    '';
  };

  "/thumbnail".extraConfig = apiUwsgiConfig;
  "/avatar".extraConfig = apiUwsgiConfig;
  "/user_uploads".extraConfig = apiUwsgiConfig;
  "/api/".extraConfig = apiUwsgiConfig;

  "/api/internal/" = {
    extraConfig = ''
      allow 127.0.0.1;
      allow ::1;
      deny all;

      ${includeApiHeaders}
      ${includeUwsgi}
    '';
  };
  # puppet/zulip/files/nginx/zulip-include-app.d/camo.conf
  "/external_content/metrics" = {
    return = "404";
  };
  "/external_content" = {
    extraConfig = ''
      rewrite /external_content/(.*) /$1 break;
      proxy_pass http://camo;
      ${includeProxy}
    '';
  };
  # puppet/zulip/files/nginx/zulip-include-frontend/uploads-internal.conf

  # FIXME: S3 is not supported for the moment

  "/internal/local/uploads/" = {
    alias = "${LOCAL_UPLOADS_DIR}/files/";
    extraConfig = ''
      internal;
      ${includeHeaders}
      add_header Content-Security-Policy "default-src 'none'; media-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self'; object-src 'self'; plugin-types application/pdf;";

      # Django handles setting Content-Type, Content-Disposition, and Cache-Control.
    '';
  };
  "/internal/local/user_avatars/" = {
    alias = "${LOCAL_UPLOADS_DIR}/avatars/";
    extraConfig = ''
      internal;
      ${includeHeaders}
      add_header Content-Security-Policy "default-src 'none'; img-src 'self'";
      include ${zulip-package}/puppet/zulip/files/nginx/zulip-include-frontend/uploads.types;
    '';
  };
  "/health" = {
    extraConfig = ''
      allow 127.0.0.1;
      allow ::1;
      deny all;

      ${includeUwsgi}
      uwsgi_param HTTP_HOST "127.0.0.1";
    '';
  };
}
