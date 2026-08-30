/** @type {import('next').NextConfig} */
const nextConfig = {
  experimental: {
    // Webpack's production minifier renames classes (including `Long` from
    // the `long` package, a transitive dep of google-gax/protobufjs) unless
    // a package is excluded from bundling. google-gax's proto3-JSON encoder
    // identifies int64 values by checking `value.constructor.name === 'Long'`
    // at runtime — once minified, that name no longer matches, and every
    // GA4 report request fails with "toProto3JSON: don't know how to
    // convert value N". Only reproduces in production builds; `next dev`
    // doesn't minify, which is why this was invisible locally until now.
    serverComponentsExternalPackages: ["@google-analytics/data", "google-gax"],
  },
};

export default nextConfig;
