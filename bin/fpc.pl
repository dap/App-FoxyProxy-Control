#!/usr/bin/perl

use strict;
use warnings;

use XML::Simple;
use Perl6::Say;
use Proc::ProcessTable;

my $conf_path
	= $ENV{'FP_CONF_PATH'};
my $command_re
	= qr/^(ssh.*)/;

my %commands = (
	'help'    => sub { usage() },
	'start'   => sub {
		# Check that params were passed, or exit with usage message
		params_or_usage();

		# Start proxies
		my @unprocessed_params = proxy_do(sub {
			my ($p, $x) = @_;

			if ( $ARGV[0] eq 'all' || grep {$_ eq $p} @ARGV ) {
				say "Starting [$p]: $x";
				system(split /\s/, $x);
				return 1;
			}

			return 0;
		});

		say 'Warning: No proxy definition found for ', join(' ', @unprocessed_params)
			if @unprocessed_params;
	},
	'stop'    => sub {
		params_or_usage();

		my $pt = (new Proc::ProcessTable)->table();

		# Find proxies in process table and stop them
		my @unprocessed_params = proxy_do(sub {
			my ($p, $x) = @_;

			if ( $ARGV[0] eq 'all' || grep {$_ eq $p} @ARGV ) {
				foreach my $proc ( @{$pt} ) {
					if ( $proc->cmndline =~ m/^$x\s*$/ ) {
						say "Stopping [$p]: $x";
						$proc->kill('TERM');
					}
				}
				return 1;
			}

			return 0;
		});

		say 'Warning: No proxy definition found for ', join(' ', @unprocessed_params)
			if @unprocessed_params;
	},
	'restart_broken' => sub {
		params_or_usage();

		my $pt = (new Proc::ProcessTable)->table();

		# Find proxies in process table and stop them
		my @unprocessed_params = proxy_do(sub {
			my ($p, $x) = @_;

			if ( $ARGV[0] eq 'all' || grep {$_ eq $p} @ARGV ) {
				foreach my $proc ( @{$pt} ) {
					if ( $proc->cmndline =~ m/^$x\s*$/ ) {
						say "Stopping [$p]: $x";
						$proc->kill('TERM');
						say "Starting [$p]: $x";
						system(split /\s/, $x);
					}
				}
				return 1;
			}

			return 0;
		});

		say 'Warning: No proxy definition found for ', join(' ', @unprocessed_params)
			if @unprocessed_params;
	},
	'restart' => sub { # handled elsewhere
	},
	'list'    => sub {
		say "Configured Proxies:";

		proxy_do(sub {
			say "\t$_[0]";
		});
	},
	'status'  => sub {
		params_or_usage();

		my $pt = (new Proc::ProcessTable)->table();

		say "Proxy Status:";

		# Find proxies in process table and stop them
		my @unprocessed_params = proxy_do(sub {
			my ($p, $x) = @_;

			my $p_found = 0;

			if ( $ARGV[0] eq 'all' || grep {$_ eq $p} @ARGV ) {
				PROC: foreach my $proc ( @{$pt} ) {
					if ( $proc->cmndline =~ m/^$x\s*$/ ) {
						$p_found = 1;
						last PROC;
					}
				}
				say "\t${p} ", $p_found ? 'UP' : 'DOWN';
				return 1;
			}

			return 0;
		});

		say 'Warning: No proxy definition found for ', join(' ', @unprocessed_params)
			if @unprocessed_params;
	},
);

usage()
	unless ( $ARGV[0] && grep {$_ eq $ARGV[0]} keys(%commands) );

if ( $ARGV[0] eq 'restart' ) {
	$commands{'stop'}->();
	unshift(@ARGV, 'start');
	$commands{'start'}->();
}
else
{
	$commands{$ARGV[0]}->();
}

sub proxy_do {
	my $func = shift;
	my $fp = get_fp_cfg();
	my @processed;

	foreach my $p ( keys( %{$fp->{'proxies'}{'proxy'}} ) ) {
		if ( $fp->{'proxies'}{'proxy'}{$p}{'notes'} =~ $command_re ) {
			push @processed, $p
				if $func->($p, $1);
		}
	}

	# From http://www.perlmonks.org/?node_id=153402
	my @unknown;
	OUTER:
	for ( @ARGV ) {
		last OUTER
			if $_ eq 'all';
		for my $p ( @processed ) {
			if ( $p eq $_ ) {
				next OUTER;
			}
		}
		push @unknown, $_;
	}

	return @unknown;
}

sub get_fp_cfg {
	my $fp;
	( sub { $fp ? $fp : $fp = XMLin($conf_path); } )->();
}

sub params_or_usage {
	# Remove command name
	shift @ARGV;

	# Error if no proxies specified
	usage()
		if !@ARGV;
}

# From Garick
# TODO add this to notes as example of removing element from array by value
#sub remove_param {
#	my $p = shift;
#	for my $i ( 0..$#ARGV ) {
#		next unless $ARGV[$i] eq $p;
#		splice @ARGV, $i, 1, ();
#		last;
#	}
#}

sub usage {
	say "Usage: $0 {",
		( join '|', keys(%commands) ),
		'} [all|[proxy_name|proxy_name|...]]';
	exit;
}

