#!/usr/bin/perl

# queries Factory Jenkins JSON api to find latest good 
# query (tuqtng) build of master or release/1.0.0 branch.
#  
#  Call with these parameters:
#  
#  BRANCH          e.g. master, 100
#  
use warnings;
#use strict;
$|++;

use File::Basename;
use Cwd qw(abs_path);
BEGIN
    {
    $THIS_DIR = dirname( abs_path($0));    unshift( @INC, $THIS_DIR );
    }
my $installed_URL='http://factory.hq.couchbase.com/cgi/show_latest_query.cgi';

use jenkinsQuery     qw(:DEFAULT );
use jenkinsReports   qw(:DEFAULT );
use jenkinsReports   qw(:QUERY   );
use buildbotReports  qw(:DEFAULT );

use CGI qw(:standard);
my  $cgi_query = new CGI;

my $DEBUG = 0;

my $delay = 3 + int rand(3.3);    sleep $delay;

my ($good_color, $warn_color, $err_color, $note_color) = ('#CCFFDD', '#FFFFCC', '#FFAAAA', '#CCFFFF');

my %release = ( 'master'   => '0.0.0',
                '100'      => '1.0.0',
                '101'      => '1.0.1',
              );
my $builder;

my $timestamp = "";
sub get_timestamp
    {
    my $timestamp;
    my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
    my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
    $month =    1 + $month;
    $year  = 1900 + $yearOffset;
    $timestamp = "page generated $hour:$minute:$second  on $year-$month-$dayOfMonth";
    }

sub print_HTML_Page
    {
    my ($frag_left, $frag_right, $page_title, $color) = @_;
    
    print $cgi_query->header;
    print $cgi_query->start_html( -title   => $page_title,
                                  -BGCOLOR => $color,
                                );
    print "\n".'<div style="overflow-x: hidden">'."\n"
         .'<table border="0" cellpadding="0" cellspacing="0"><tr>'."\n".'<td valign="TOP">'.$frag_left.'</td><td valign="TOP">'.$frag_right.'</td></tr>'."\n".'</table>'
         .'</div>'."\n";
    print $cgi_query->end_html;
    }

my $usage = "ERROR: must specify 'branch', 'edition', and 'outcome'\n\n"
           ."<PRE>"
           ."For example:\n\n"
           ."    $installed_URL?branch=master&edition=enterprise&outcome=good\n"
           ."    $installed_URL?branch=100&edition=enterprise&outcome=done\n"
           ."</PRE><BR>"
           ."\n"
           ."\n";

my  $platform = 'default';
my ($branch, $edition, $job_type);

if ( $cgi_query->param('branch') && $cgi_query->param('edition') && $cgi_query->param('outcome') )
    {
    $branch   = $cgi_query->param('branch');
    $outcome  = $cgi_query->param('outcome');
    $edition  = $cgi_query->param('edition');
    if ($edition eq 'EE' )  { $edition = 'enterprise'; }
    if ($edition eq 'CE' )  { $edition = 'community';  }
    }
else
    {
    print_HTML_Page( buildbotQuery::html_ERROR_msg($usage), '&nbsp;', 'invalid call to show_latest_query.cgi', $err_color );
    exit;
    }

my ($bldstatus, $bldnum, $jobnum, $rev_numb, $bld_date, $is_running);
my $JRDEBUG;


#### S T A R T  H E R E 

if ($outcome =~ 'good')
    {
    ($builder, $bldnum, $is_running, $bld_date, $bldstatus) = jenkinsReports::last_good_query_bld($platform, $branch, $edition);
    $JRDEBUG = 'last_good_query_bld';
    }
if ($outcome =~ 'done')
    {
    ($builder, $bldnum, $is_running, $bld_date, $bldstatus) = jenkinsReports::last_done_query_bld($platform, $branch, $edition);
    $JRDEBUG = 'last_done_query_bld';
    }
$rev_numb = $release{$branch}.'-'.$bldnum;

if ($DEBUG)  { print STDERR "\nready to start with ($builder, $edition, $outcome)\n"; }
if ($DEBUG)  { print STDERR "according to last_done_build, is_running = $is_running\n"; }
if ($DEBUG)  { print STDERR $JRDEBUG." returns ( $builder, $bldnum, $is_running, $bld_date, $bldstatus )\n"; }

if ($bldnum < 0)
    {
    if ($DEBUG)  { print STDERR "blndum < 0, no build yet\n"; }
    print_HTML_Page( $bld_date,
                     buildbotReports::is_running($is_running),
                     $builder,
                     $note_color );
    }
elsif ($bldstatus)
    {
    my $made_color;    $made_color = $good_color;
    
    print_HTML_Page( jenkinsQuery::html_OK_link( $builder,  $bldnum,   $rev_numb, $bld_date),
                     buildbotReports::is_running($is_running),
                     $builder,
                     $made_color );
    }
else
    {
    $made_color = $err_color;
    if ( $is_running == 1 )
        {
        $bldnum += 1;
        $made_color = $warn_color;
        }
    print_HTML_Page( buildbotReports::is_running($is_running),
                     jenkinsQuery::html_FAIL_link( $builder, $bldnum, $is_running, $bld_date),
                     $builder,
                     $made_color );
    }
    


# print "\n---------------------------\n";
__END__

