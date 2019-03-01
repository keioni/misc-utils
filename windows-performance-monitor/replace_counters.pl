#!/usr/bin/perl

use strict;
use warnings;
use utf8;
use Encode;
use Encode::Guess qw/utf8 utf16 shiftjis/;


open(my $f_new, "<$ARGV[0]");
my @raw_new_list = <$f_new>;
close($f_new);
my $new_list_str = join('', @raw_new_list);
my $enc = guess_encoding($new_list_str);
ref($enc) or die "Can't guess: $enc";
my @new_list;
foreach (@raw_new_list) {
	push(@new_list, $enc->decode($_));
}

my $fname_xml = $ARGV[1] || '-';
open(my $f_xml, "<$fname_xml");
my @xml = <$f_xml>;
close($f_xml);

my $xml_str = join('', @xml);
$enc = guess_encoding($xml_str);
ref($enc) or die "Can't guess: $enc";
$xml_str = $enc->decode($xml_str);
$xml_str =~ s|(\t*)<Counter>.*</CounterDisplayName>(\r\n)?|&replace($1, $2)|se;
print encode('UTF-8', $xml_str);


sub replace {
	my $tabs = shift;
	my $crlf = shift;
	my @repl_c;
	my @repl_cdn;
	$crlf = '' if (!$crlf);
	foreach (@new_list) {
		s/\r?\n|\s+$//;
		s/(\s*)#.*$/$1/;
		next if (/^[^\\]?$/ );
		my ($c, $cdn) = split(/\t+/);
		push( @repl_c, "$tabs<Counter>$c</Counter>$crlf");
		$cdn = $c if (!$cdn);
		push( @repl_cdn, "$tabs<CounterDisplayName>$cdn</CounterDisplayName>$crlf");
	}
	return join('', @repl_c) . join('', @repl_cdn);
}

