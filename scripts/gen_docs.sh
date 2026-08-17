#!/usr/bin/env bash
# Generates the DocC static documentation site.
# Used by both `bundle exec fastlane gen_docs` and .github/workflows/docs.yml.
#
# Part of the public API lives in extensions on URL/String, so the
# symbol graphs must be extracted with -emit-extension-block-symbols;
# without it those symbols would be missing from the generated site.
set -euo pipefail

output_dir="${1:-docc-site}"
version=$(grep -m1 'MARKETING_VERSION' TLDExtractSwift.xcodeproj/project.pbxproj | sed 's/.*= //;s/;//')
arch=$(uname -m)
### Target the host OS version; the bare triple would default to macOS 10.4,
### below the module's minimum deployment target.
target="${arch}-apple-macosx$(sw_vers -productVersion | cut -d. -f1)"

swift build

rm -rf .build/symbol-graphs
mkdir -p .build/symbol-graphs
swift symbolgraph-extract \
  -module-name TLDExtractSwift \
  -target "${target}" \
  -sdk "$(xcrun --show-sdk-path)" \
  -I .build/debug/Modules \
  -output-dir .build/symbol-graphs \
  -emit-extension-block-symbols

xcrun docc convert \
  --fallback-display-name TLDExtractSwift \
  --fallback-bundle-identifier dev.futamura.TLDExtractSwift \
  --fallback-bundle-version "${version}" \
  --additional-symbol-graph-dir .build/symbol-graphs \
  --transform-for-static-hosting \
  --hosting-base-path TLDExtractSwift \
  --output-path "${output_dir}"

### The DocC site has no landing page at its root; redirect to the module page.
cat > "${output_dir}/index.html" <<'EOF'
<!DOCTYPE html>
<html>
<head><meta http-equiv="refresh" content="0; url=documentation/tldextractswift/"></head>
<body><a href="documentation/tldextractswift/">Redirecting to documentation&hellip;</a></body>
</html>
EOF

echo "Documentation generated in ${output_dir}/ (version ${version})"
