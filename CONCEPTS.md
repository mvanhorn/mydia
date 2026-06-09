# Concepts

Shared domain vocabulary for this project — entities, named processes, and status concepts with project-specific meaning. Seeded with core domain vocabulary, then accretes as ce-compound and ce-compound-refresh process learnings; direct edits are fine. Glossary only, not a spec or catch-all.

## Metadata

### Metadata Relay
A developer-owned proxy service, deployed separately from Mydia, that fronts the upstream metadata providers (TVDB, TMDB). Mydia instances talk to the relay instead of calling TVDB/TMDB directly, which keeps provider API keys out of self-hosted installs and centralizes rate limiting.

The relay does not necessarily expose every upstream endpoint — it proxies the subset Mydia needs. Provider responses pass through in roughly their native shape, so provider quirks (e.g. how each provider encodes translation languages) reach Mydia unchanged.

### Metadata Source
The upstream provider a given title's metadata was fetched from — TVDB or TMDB. Tracked per title and chosen per library, so two libraries can resolve the same show through different providers.

Source matters because the two providers behave differently for the same data: TMDB selects localized text server-side from a requested language, while TVDB returns all translations and Mydia selects one client-side. Code that fetches or parses metadata must branch on the source rather than assuming one provider's conventions.

### Metadata Language
The configured locale used when fetching metadata text (titles, overviews). A single value (an ISO 639-1 / BCP-47 tag such as `en-US` or `de`) applied across providers and media types.

Selection falls back when the exact language is unavailable: configured language, then the title's original language, then English, then the provider's raw default field. The language also participates in metadata cache keys, so entries do not collide or leak across languages.
