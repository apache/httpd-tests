
use strict;
use warnings FATAL => 'all';

use Apache::Test;
use Apache::TestUtil;
use Apache::TestRequest;

# Unified test array
# Each test is a hash with:
#   type: 'content' (status + content-type + content), 'url_rewrite' (status + content),
#         'meta' (status + content-type + header), 'comment' (status + content with optional negation)
#   path: URL path to fetch
#   desc: test description
#   Other fields depend on type
my @tests = (
    # Basic content tests
    { type => 'content', path => 'equiv.html', content_type => 'text/html.*',
      content => '<meta content="X" http-equiv="999">', desc => 'fetching equiv.html' },

    # Meta tag extraction tests (metafix() function)
    { type => 'meta', path => 'meta_simple.html', header => 'X-Custom-Header',
      value => 'SimpleValue', desc => 'simple meta tag' },
    { type => 'meta', path => 'meta_quotes.html', header => 'X-Double-Quote',
      value => 'Value with double quotes', desc => 'double quotes' },
    { type => 'meta', path => 'meta_quotes.html', header => 'X-Single-Quote',
      value => 'Value with single quotes', desc => 'single quotes' },
    { type => 'meta', path => 'meta_quotes.html', header => 'X-No-Quote',
      value => 'ValueNoQuotes', desc => 'no quotes' },
    { type => 'meta', path => 'meta_whitespace.html', header => 'X-Extra-Space',
      value => 'Value with spaces', desc => 'extra whitespace' },
    { type => 'meta', path => 'meta_whitespace.html', header => 'X-Tabs',
      value => 'Tabs and spaces', desc => 'tabs and spaces' },
    { type => 'meta', path => 'meta_multiple.html', header => 'X-First',
      value => 'First', desc => 'first of multiple' },
    { type => 'meta', path => 'meta_multiple.html', header => 'X-Second',
      value => 'Second', desc => 'second of multiple' },
    { type => 'meta', path => 'meta_multiple.html', header => 'X-Third',
      value => 'Third', desc => 'third of multiple' },
    { type => 'meta', path => 'meta_multiple.html', header => 'X-Fourth',
      value => 'Fourth', desc => 'fourth of multiple' },
    { type => 'meta', path => 'meta_malformed.html', header => 'X-Valid',
      value => 'ValidValue', desc => 'valid meta with malformed neighbors' },
    { type => 'meta', path => 'meta_malformed.html', header => 'X-After-Bad',
      value => 'AfterBad', desc => 'valid meta after malformed tags' },
    { type => 'meta', path => 'meta_special_chars.html', header => 'X-Special',
      value => 'Value-with-dashes', desc => 'dashes in content' },
    { type => 'meta', path => 'meta_special_chars.html', header => 'X-Numbers123',
      value => '123', desc => 'numbers in header name' },
    { type => 'meta', path => 'meta_special_chars.html', header => 'X-Mixed',
      value => 'text/html; charset=utf-8', desc => 'complex content value' },
    { type => 'meta', path => 'meta_contenttype.html', header => 'X-Other',
      value => 'OtherValue', desc => 'other header with Content-Type present' },
    { type => 'meta', path => 'meta_edge_cases.html', header => 'X-Empty-Content',
      value => '', desc => 'empty content value' },
    { type => 'meta', path => 'meta_edge_cases.html', header => 'X-Very-Long-Name-With-Many-Characters',
      value => 'LongNameTest', desc => 'long header name' },
    { type => 'meta', path => 'meta_edge_cases.html', header => 'X-End',
      value => 'LastValue', desc => 'meta at end of head' },

    # Basic URL rewriting tests
    { type => 'url_rewrite', path => 'url_rewrite/url_rewrite.html',
      pattern => 'http://b\.example\.com/page1\.html', desc => 'basic URL rewrite in href' },
    { type => 'url_rewrite', path => 'url_rewrite/url_rewrite.html',
      pattern => 'http://b\.example\.com/dir/page2\.html', desc => 'basic URL rewrite in href with path' },
    { type => 'url_rewrite', path => 'url_rewrite/url_rewrite.html',
      pattern => 'http://b\.example\.com/image\.png', desc => 'basic URL rewrite in img src' },
    { type => 'url_rewrite', path => 'url_rewrite/url_rewrite.html',
      pattern => 'http://b\.example\.com/submit', desc => 'basic URL rewrite in form action' },

    # Regex URL rewriting tests
    { type => 'url_rewrite', path => 'regex_rewrite/regex_rewrite.html',
      pattern => 'http://www\.example\.com/server1\.example\.com/path/page\.html', desc => 'regex URL rewrite server1' },
    { type => 'url_rewrite', path => 'regex_rewrite/regex_rewrite.html',
      pattern => 'http://www\.example\.com/server2\.example\.com/path/page\.html', desc => 'regex URL rewrite server2' },
    { type => 'url_rewrite', path => 'regex_rewrite/regex_rewrite.html',
      pattern => 'http://www\.example\.com/server3\.example\.com/path/page\.html', desc => 'regex URL rewrite server3' },

    # Multiple HTML elements tests
    { type => 'url_rewrite', path => 'links_elements/links_elements.html',
      pattern => 'http://rewritten\.example\.com/page\.html', desc => 'rewrite anchor href' },
    { type => 'url_rewrite', path => 'links_elements/links_elements.html',
      pattern => 'http://rewritten\.example\.com/img\.jpg', desc => 'rewrite img src' },
    { type => 'url_rewrite', path => 'links_elements/links_elements.html',
      pattern => 'http://rewritten\.example\.com/style\.css', desc => 'rewrite link href' },
    { type => 'url_rewrite', path => 'links_elements/links_elements.html',
      pattern => 'http://rewritten\.example\.com/script\.js', desc => 'rewrite script src' },
    { type => 'url_rewrite', path => 'links_elements/links_elements.html',
      pattern => 'http://rewritten\.example\.com/map\.html', desc => 'rewrite area href' },
    { type => 'url_rewrite', path => 'links_elements/links_elements.html',
      pattern => 'http://rewritten\.example\.com/form', desc => 'rewrite form action' },
    { type => 'url_rewrite', path => 'links_elements/links_elements.html',
      pattern => 'http://rewritten\.example\.com/object\.swf', desc => 'rewrite object data' },

    # Case-insensitive URL mapping tests
    { type => 'url_rewrite', path => 'case_insensitive/case_insensitive.html',
      pattern => 'http://b\.example\.com/page\.html', desc => 'case-insensitive rewrite uppercase' },

    # ProxyHTMLExtended tests (inline scripts/CSS)
    { type => 'url_rewrite', path => 'inline_script/inline_script.html',
      pattern => "url\\('http://b\\.example\\.com/bg\\.png'\\)", desc => 'CSS URL rewrite in style block' },
    { type => 'url_rewrite', path => 'inline_script/inline_script.html',
      pattern => 'http://b\\.example\\.com/data\\.json', desc => 'JS URL rewrite in script block' },
    { type => 'url_rewrite', path => 'inline_script/inline_script.html',
      pattern => 'http://b\\.example\\.com/redirect\\.html', desc => 'JS URL rewrite in window.location' },
    { type => 'url_rewrite', path => 'inline_script/inline_script.html',
      pattern => 'http://b\\.example\\.com/api', desc => 'JS URL rewrite in onload event' },
    { type => 'url_rewrite', path => 'inline_script/inline_script.html',
      pattern => 'http://b\\.example\\.com/popup\\.html', desc => 'JS URL rewrite in onclick event' },

    # ProxyHTMLStripComments tests
    { type => 'comment', path => 'comments_strip/comments.html',
      pattern => '<!-- This is a comment that should be stripped -->', negate => 1, desc => 'comment is stripped' },
    { type => 'comment', path => 'comments_strip/comments.html',
      pattern => 'Visible content', desc => 'visible content preserved' },
    { type => 'comment', path => 'comments_strip/comments.html',
      pattern => 'More content', desc => 'more visible content preserved' },
    { type => 'comment', path => 'comments_keep/comments.html',
      pattern => 'Visible content', desc => 'visible content still there' },

    # ProxyHTMLFixups tests
    { type => 'url_rewrite', path => 'fixups_case/fixups_case.html',
      pattern => 'http://b\\.example\\.com/path/with/caps\\.html', desc => 'lowercase fixup mixed case' },
    { type => 'url_rewrite', path => 'fixups_case/fixups_case.html',
      pattern => 'http://b\\.example\\.com/all/uppercase\\.html', desc => 'lowercase fixup all caps' },
    { type => 'url_rewrite', path => 'fixups_dospath/fixups_dospath.html',
      pattern => 'http://a\\.example\\.com/path/with/backslashes\\.html', desc => 'dospath fixup href' },
    { type => 'url_rewrite', path => 'fixups_dospath/fixups_dospath.html',
      pattern => 'http://a\\.example\\.com/images/photo\\.jpg', desc => 'dospath fixup img src' },

    # ProxyHTMLDocType test
    { type => 'url_rewrite', path => 'doctype/doctype.html',
      pattern => '<!DOCTYPE html', desc => 'DOCTYPE declaration added' },

    # Multiple URL maps tests
    { type => 'url_rewrite', path => 'multiple_maps/multiple_maps.html',
      pattern => 'http://new-a\\.example\\.com/page1\\.html', desc => 'first URL map' },
    { type => 'url_rewrite', path => 'multiple_maps/multiple_maps.html',
      pattern => 'http://new-c\\.example\\.com/page2\\.html', desc => 'second URL map' },
    { type => 'url_rewrite', path => 'multiple_maps/multiple_maps.html',
      pattern => 'http://new-d\\.example\\.com/page3\\.html', desc => 'third URL map' },
);

# Calculate total number of tests
my $total_tests = 0;
foreach my $t (@tests) {
    if ($t->{type} eq 'content' || $t->{type} eq 'meta') {
        $total_tests += 3;  # status + content-type + (content or header)
    } else {
        $total_tests += 2;  # status + content
    }
}

plan tests => $total_tests, need [qw(proxy_html proxy)];

# Run all tests
foreach my $t (@tests) {
    my $r = GET("/modules/html_proxy/".$t->{path});

    if ($t->{type} eq 'content') {
        # Basic content tests: status + content-type + content
        ok t_cmp($r->code, 200, "fetching ".$t->{path});
        ok t_cmp($r->header('Content-Type'), qr/$t->{content_type}/, "content-type header test for ".$t->{path});
        ok t_cmp($r->content, qr/$t->{content}/, "content test for ".$t->{path});

    } elsif ($t->{type} eq 'meta') {
        # Meta tag extraction tests: status + content-type + header value
        ok t_cmp($r->code, 200, "fetching ".$t->{path}." for ".$t->{desc});
        ok t_cmp($r->header('Content-Type'), qr/text\/html/, "content-type for ".$t->{path});
        ok t_cmp($r->header($t->{header}), $t->{value}, "meta header ".$t->{header}." = '".$t->{value}."' (".$t->{desc}.")");

    } elsif ($t->{type} eq 'url_rewrite') {
        # URL rewrite tests: status + content pattern
        ok t_cmp($r->code, 200, "fetching ".$t->{path}." for ".$t->{desc});
        ok t_cmp($r->content, qr/$t->{pattern}/i, $t->{desc});

    } elsif ($t->{type} eq 'comment') {
        # Comment handling tests: status + content pattern (with optional negation)
        ok t_cmp($r->code, 200, "fetching ".$t->{path}." for ".$t->{desc});

        if ($t->{negate}) {
            # Pattern should NOT be in content
            ok !t_cmp($r->content, qr/$t->{pattern}/, $t->{desc});
        } else {
            # Pattern should be in content
            ok t_cmp($r->content, qr/$t->{pattern}/, $t->{desc});
        }
    }
}
