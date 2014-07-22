#!/usr/bin/env perl
# Copyright 2014 Michal Špaček <tupinek@gmail.com>

# Pragmas.
use strict;
use warnings;

# Modules.
use Database::DumpTruck;
use Encode qw(decode_utf8 encode_utf8);
use English;
use HTML::TreeBuilder;
use LWP::UserAgent;
use POSIX qw(strftime);
use URI;
use Time::Local;

# URI of service.
my $base_uri = URI->new('http://dvr.gatema.cz/novinky/seznam.htm');

# Open a database handle.
my $dt = Database::DumpTruck->new({
	'dbname' => 'data.sqlite',
	'table' => 'data',
});

# Create a user agent object.
my $ua = LWP::UserAgent->new(
	'agent' => 'Mozilla/5.0',
);

# Get base root.
my $root = get_root($base_uri);

# Look for items.
my @news = $root->find_by_attribute('class', 'news-box');
foreach my $news (@news) {

	# Get data.
	my $db_date = get_db_date($news->find_by_attribute(
		'class', 'news-date'));
	my ($title, $href, $note) = get_db_info($news->find_by_attribute(
		'class', 'news-cont'));
	my $link = URI->new($base_uri->scheme.'://'.$base_uri->host.$href);

	# Check data in database.
	my $ret_ar = eval {
		$dt->execute('SELECT COUNT(*) FROM data WHERE date = ? AND link = ?', $db_date, $link->as_string);
	};
	
	# Insert data.
	if ($EVAL_ERROR || ! exists $ret_ar->[0]->{'count(*)'}
		|| ! defined $ret_ar->[0]->{'count(*)'}
		|| $ret_ar->[0]->{'count(*)'} == 0) {

		print encode_utf8("Added $db_date: $title\n");
		$dt->insert({
			'Date' => $db_date,
			'Link' => $link->as_string,
			'Note' => $note,
			'Title' => $title,
		});
	}
}

# Get root of HTML::TreeBuilder object.
sub get_root {
	my $uri = shift;
	my $get = $ua->get($uri->as_string);
	my $data;
	if ($get->is_success) {
		$data = $get->content;
	} else {
		die "Cannot GET '".$uri->as_string." page.";
	}
	my $tree = HTML::TreeBuilder->new;
	$tree->parse(decode_utf8($data));
	return $tree->elementify;
}

# Get database date from HTML code.
sub get_db_date {
	my $date_div = shift;
	my $year = $date_div->find_by_tag_name('b')->as_text;
	my ($day, $mon) = split m/\./ms,
		$date_div->find_by_tag_name('span')->as_text;
	my $time = timelocal(0, 0, 0, $day, $mon - 1, $year - 1900);
	return strftime('%Y-%m-%d', localtime($time));
}

# Get information for database from HTML code.
sub get_db_info {
	my $info_div = shift;
	my $a = $info_div->find_by_tag_name('a');
	my $href = $a->attr('href');
	my $title = $a->as_text;
	my $note = $info_div->find_by_attribute('class', 'desc')->as_text;
	return ($title, $href, $note);
}
