# Openstage

Openstage is a Rails app for building in public with a shareable profile timeline.

## README Badge

Openstage provides a live SVG badge per user at:

`https://openstage.dev/badge/:username`

Rendered example:

[![openstage](https://openstage.dev/badge/tuxnotfound)](https://openstage.dev/tuxnotfound)

Use this markdown in your GitHub README:

```md
[![openstage](https://openstage.dev/badge/YOUR_USERNAME)](https://openstage.dev/YOUR_USERNAME)
```

Example:

```md
[![openstage](https://openstage.dev/badge/tuxnotfound)](https://openstage.dev/tuxnotfound)
```

The badge currently shows live public stats:
- GitHub commits synced to Openstage
- Total public entries

In the product, users can copy this snippet from the Dashboard under the `README badge` section.

## Development

Basic Rails commands:

```bash
bin/setup
bin/dev
bundle exec rspec
```
