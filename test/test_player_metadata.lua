-- P2.6 host-independent metadata and empty-state normalization.

---@diagnostic disable: undefined-field, inject-field, need-check-nil, preferred-local-alias, unused

local F = require 'framework'
local metadata = require 'widget.player.metadata'
local PlayerSnapshot = require('widget.player_context').PlayerSnapshot

F.section('player metadata')

F.test('title and URL detection distinguish local and loading media', function()
    local local_snapshot = PlayerSnapshot({
        media_title = 'Episode 7',
        path = 'C:/media/episode.mkv',
    })
    F.eq(metadata.title(local_snapshot, 'elxosc'), 'Episode 7', 'media title wins')
    F.ok(not metadata.is_url(local_snapshot), 'local path is not a URL')

    local url_snapshot = PlayerSnapshot({ path = 'https://example.test/video' })
    F.ok(metadata.is_url(url_snapshot), 'HTTP path is detected as a URL')
    F.eq(metadata.title(url_snapshot, 'elxosc'), 'Loading...', 'URL without title is loading')
    F.eq(metadata.description(url_snapshot), 'Loading description...',
        'URL without description is loading')
end)

F.test('metadata composes artist album date and file size', function()
    local snapshot = PlayerSnapshot({
        metadata = {
            album_artist = 'Artist',
            album = 'Album',
            upload_date = '20240102',
        },
        file_size = 1536,
    })
    F.eq(metadata.description(snapshot), 'Artist · Album · 2024-01-02 · 1.5 KiB',
        'metadata fallback description')
end)

F.test('explicit description and live metadata take precedence', function()
    local snapshot = PlayerSnapshot({
        description = 'A long-form description',
        metadata = { ytdl_is_live = 'yes' },
    })
    F.eq(metadata.description(snapshot), 'A long-form description', 'explicit description wins')
    F.ok(metadata.is_live(snapshot), 'live metadata is normalized')
    F.eq(metadata.preview(string.rep('x', 10), 5), 'xx...', 'preview is bounded')
end)

F.test('description links are unique and punctuation is trimmed', function()
    local links = metadata.links('See https://example.test/a, then https://example.test/a and http://x.test/path.')
    F.eq(#links, 2, 'duplicate links are removed')
    F.eq(links[1], 'https://example.test/a', 'first link is normalized')
    F.eq(links[2], 'http://x.test/path', 'trailing punctuation is removed')
end)

F.test('metadata stats format optional counts without requiring them', function()
    local snapshot = PlayerSnapshot({ metadata = {
        view_count = 1234567,
        like_count = 42,
    } })
    F.eq(metadata.stats(snapshot), 'Views: 1,234,567 · Likes: 42',
        'optional stats are formatted')
    F.eq(metadata.stats(PlayerSnapshot()), '', 'missing stats are empty')
end)
