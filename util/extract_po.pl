#!/usr/bin/env perl

use 5.14.2;
use warnings;

use Zonemaster::Engine::Translator;

my $data = Zonemaster::Engine::Translator->new->data;

print<<'PRELUDE';
msgid ""
msgstr ""
"Language: en\n"
"Content-Type: text/plain; charset=utf-8\n"
"Content-Transfer-Encoding: 8bit\n"
"Project-Id-Version: 0.0.4\n"
"PO-Revision-Date: 2014-08-28\n"
"Last-Translator: calle@init.se\n"
"Language-Team: Zonemaster Team\n"
"MIME-Version: 1.0\n"

PRELUDE

my %uniq;

foreach my $m (sort keys %{$data}) {
    next if ref($data->{$m}) ne 'HASH';
    foreach my $t (sort keys %{$data->{$m}}) {
        printf qq[#: %s:%s\n], $m, $t;
        my $str = $data->{$m}{$t};
        $str =~ s/\"/\\"/g;
        next if exists $uniq{$str};
        printf qq[msgid  "%s"\n], $str;
        printf qq[msgstr "%s"\n\n], $str;
        $uniq{$str} = 1;
    }
}
