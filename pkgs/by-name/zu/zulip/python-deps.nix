# The Python environment of the Zulip server, following upstream's
# pyproject.toml (the `prod` dependency group). Upstream comments are kept.
ps:
[
  # Used by our patched zproject/config.py to read secrets from systemd
  # credentials (see 0007-credentials-Use-loadcredentials.patch)
  ps.loadcredential

  # Django itself
  ps.django
  ps.asgiref

  # needed for NotRequired, ParamSpec
  ps.typing-extensions

  # Needed for rendering backend templates
  ps.jinja2

  # Needed for Markdown processing
  ps.markdown
  ps.pygments
  ps.jsx-lexer
  ps.uri-template
  ps.regex

  # Needed for manage.py
  ps.ipython

  # Needed for image processing and thumbnailing
  ps.pyvips

  # Needed for building complex DB queries
  ps.sqlalchemy_1_4
  ps.greenlet

  # Needed for S3 file uploads and other AWS tools
  ps.boto3

  # The runtime-relevant part of boto3-stubs (see mypy.in)
  ps.mypy-boto3-s3
  ps.mypy-boto3-ses
  ps.mypy-boto3-sns
  ps.mypy-boto3-sqs

  # Needed for integrations
  ps.defusedxml

  # Needed for LDAP support
  ps.python-ldap
  ps.django-auth-ldap

  # Django extension providing bitfield support
  ps.django-bitfield

  # Needed for Android push notifications
  ps.firebase-admin

  # Needed for the email mirror
  ps.html2text
  ps.talon-core

  # Needed for inlining the CSS in emails
  ps.css-inline

  # Needed for JWT-based auth
  ps.pyjwt

  # Needed to access RabbitMQ
  ps.pika

  # Needed to access our database
  ps.psycopg2

  # Needed for memcached usage
  ps.python-binary-memcached

  # Needed for compression support in memcached via python-binary-memcached
  ps.django-bmemcached

  # Needed for zerver/tests/test_timestamp.py
  ps.python-dateutil

  # Needed for Redis
  ps.redis

  # Tornado used for server->client push system
  ps.tornado

  # Fast JSON parser
  ps.orjson

  # Needed for iOS push notifications
  ps.aioapns

  # To parse po files
  ps.polib

  # Needed for link preview
  ps.beautifulsoup4
  ps.pyoembed
  ps.python-magic

  # The Zulip API bindings from its own repository.
  ps.zulip
  ps.zulip-bots

  # Used for Hesiod lookups etc.
  ps.dnspython

  # Install Python Social Auth
  ps.social-auth-app-django
  ps.social-auth-core
  ps.python3-saml

  # For encrypting a login token to the desktop app
  ps.cryptography

  # Needed for messages' rendered content parsing in push notifications.
  ps.lxml

  # Needed for 2-factor authentication
  ps.django-two-factor-auth

  # Needed for processing payments (in corporate)
  ps.stripe

  # For checking whether email of the user is from a disposable email provider.
  ps.disposable-email-domains

  # Needed for parsing YAML with JSON references from the REST API spec files
  ps.jsonref

  # Needed for string matching in AlertWordProcessor
  ps.pyahocorasick

  # Needed for function decorators that don't break introspection.
  # Used for rate limiting authentication.
  ps.decorator

  # For server-side enforcement of password strength
  ps.zxcvbn

  # Needed for sending HTTP requests
  ps.requests
  ps.requests-oauthlib

  # For OpenAPI schema validation.
  ps.openapi-core

  # For reporting errors to sentry.io
  ps.sentry-sdk

  # For detecting URLs to link
  ps.tlds

  # Unicode Collation Algorithm for sorting multilingual strings
  ps.pyuca

  # Handle connection retries with exponential backoff
  ps.tenacity

  # Needed for reading bson files in rocketchat import tool
  ps.pymongo
  ps.python-bsonstream

  # Non-backtracking regular expressions
  ps.google-re2

  # For querying recursive group membership
  ps.django-cte

  # SCIM integration
  ps.django-scim2

  # Circuit-breaking for outgoing services
  ps.pybreaker

  # Runtime monkeypatching of django-stubs generics
  ps.django-stubs-ext

  # Structured data representation with parsing.
  ps.pydantic
  ps.annotated-types

  # Used for monitoring memcached
  ps.prometheus-client

  # For captchas on unauth'd pages which can generate emails
  ps.altcha

  # SMTP server for accepting incoming email
  ps.aiosmtpd

  # For using Missing sentinel
  ps.pydantic-partials

  # For E2EE of push notifications
  ps.pynacl

  # Character set detection for text/plain
  ps.chardet

  # Better compression than zlib
  ps.zstd

  # Internationalization
  ps.pyicu

  # Used to parse User-Agent string for OS & browser names
  ps.ua-parser
]
++ ps.django.optional-dependencies.argon2
++ ps.social-auth-core.optional-dependencies.azuread
++ ps.social-auth-core.optional-dependencies.saml
++ ps.django-two-factor-auth.optional-dependencies.sms
++ ps.django-two-factor-auth.optional-dependencies.call
++ ps.django-two-factor-auth.optional-dependencies.phonenumbers
++ ps.requests.optional-dependencies.security
++ ps.ua-parser.optional-dependencies.regex
