#!/usr/bin/perl
use strict;
use warnings;

use feature qw/say/;
use Data::Printer;

use WWW::Mechanize;
use URI::Escape;
use Audio::Scan;
use LWP::Simple;
use File::Copy;

my %summary;
my @songs = ('roses the chainsmokers', 'hide away daya');
for (@songs) {
    my $t = download_song($_) ? 'ok' : 'fail';
    push @{ $summary{$t} }, $_;
}

my $ok = scalar @{ $summary{ok} || [] } || 0;
say "Successfully downloaded $ok/@{[scalar @songs]} song(s)";
say 'Failed downloading: ' . join( ', ', map { "\"$_\"" } @{ $summary{fail} || [qw/None/] } );

sub download_song {
    my $title = shift;
    my $url = "http://mp3skull.com/mp3/@{[uri_escape($title)]}.html";
    say "Downloading \"$title\"";

    my $mech = WWW::Mechanize->new;
    $mech->get($url);

    my @links = $mech->find_all_links(url_regex => qr/mp3$/i);
    unless (@links) {
        say "No download links available for \"$title\"\n";
        return;
    }

    my $g_duration = guess_duration($mech->text);
    unless ($g_duration) { # TODO: what to do if can't guess duration?
        say "Could not download \"$title\"\n";
        return;
    }

    my $ctr = 0;
    for (@links) {
        $ctr++;
        my $url = $_->url;
        my $file = "/tmp/$ctr.mp3";

        say "Trying link $ctr/@{[scalar @links]}";
        next unless getstore($url, $file) == 200;

        my $info = Audio::Scan->scan($file)->{info};
        next unless $info->{song_length_ms} || $info->{bitrate};

        my $duration = int ( ($info->{song_length_ms}/1000) + 0.5 ); # WANT: better round off
        my $dl_dir = '/home/pvsune/Desktop/MP3';

        if ($duration == $g_duration && $duration > 30 && $info->{bitrate} >= 128000) { # skip previews, >= 128 kbps
            copy($file, "$dl_dir/$title.mp3") or die "Copy failed: $!";
            say "Downloaded \"$title\"\n";
            return 1;
        }
    }

    say "Could not download \"$title\"\n";
    undef;
}

sub guess_duration { # based on most number of same duration on page
    my $str = shift;
    my @duration = $str =~ m/\d:\d{2}/g;
    return unless @duration;

    my %freq;
    $freq{$_}++ foreach @duration;
    my $dur = shift @{[ sort { $freq{$b} <=> $freq{$a} } keys %freq ]};

    my @time = split ':', $dur;
    my $min = int shift @time;
    my $sec = int shift @time;

    ($min * 60) + $sec;
}
