/// Client side of the redirect server: [RedirectClient] and
/// [RedirectClientFactory] send every request to the redirect server, the
/// real url in the `x-tekartik-redirect-url` header.
library;

export 'src/http_redirect_client.dart'
    show RedirectClient, RedirectClientFactory;
