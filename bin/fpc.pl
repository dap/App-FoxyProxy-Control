#!/usr/bin/perl

=head1 NAME

fpc.pl - Utility to start/stop tunnels parsed from FoxyProxy config

=head1 SYNOPSIS

  # List available proxies
  $ fpc.pl list

  # Start a given proxy
  $ fpc.pl start footun

  # Restart a given proxy
  $ fpc.pl restart footun

  # Stop a given proxy
  $ fpc.pl stop footun

  # Show status of a given proxy
  $ fpc.pl status footun

  # Show usage assistance
  $ fpc.pl help

=head1 DESCRIPTION

WARNING: this program contains a bunch of stuff that I once thought
         was really cool and interesting, but now I mostly just find
         hard to understand and maintain.  This will be addressed
         after I complete the test suite.
=cut

use Modern::Perl;

use XML::Simple;
use Proc::ProcessTable;

my $conf_path
	= $ENV{'FPC_CONF_PATH'};
my $command_re
	= qr/^(ssh.*)/;

my %commands = (
	'help'	=> sub {
		usage()
	},
	'start'	=> sub {
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
	'stop'	=> sub {
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
	'restart' => sub { # handled elsewhere, but here for inclusion in usage()
	},
	'list'	=> sub {
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

=begin private
=head1 PRIVATE METHODS

=head2 proxy_do

  my @unprocessed_params = proxy_do(sub {
  	my ($proxy, $cmd) = @_;
  	say "$proxy, $cmd";
  });

Invokes the supplied method, passing in the name of the proxy and the
command as parsed from the FoxyProxy configuration.
=cut
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
	# TODO: relearn what this does and document it
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

=head2 get_fp_cfg

  my $fp = get_fp_cfg();

Reads and parses FoxyProxy config, returning hashref.
=cut
sub get_fp_cfg {
	my $fp;
	# TODO I don't know why the fuck I did this; seems kind of showy
	( sub { $fp ? $fp : $fp = XMLin($conf_path); } )->();
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

=head2 params_or_usage

  params_or_usage();

Checks that proxies have been specified in addition to a command, or dies
displaying a usage message to stdout.
=cut
sub params_or_usage {
	# Remove command name
	shift @ARGV;

	# Error if no proxies specified
	usage() if !@ARGV;
}

=head3 usage

  usage();

Displays program usage information to stdout.
=cut
sub usage {
	say "Usage: $0 {",
		( join '|', keys(%commands) ),
		'} [all|[proxy_name|proxy_name|...]]';
	exit;
}

=head2 main

  main();

Invokes main program logic.
=cut
sub main {
	usage()
		unless ( $ARGV[0] && grep {$_ eq $ARGV[0]} keys(%commands) );

	# restart is the only command handled
	# outside of the %commands hash
	if ( $ARGV[0] eq 'restart' ) {
		$commands{'stop'}->();
		unshift(@ARGV, 'start');
		$commands{'start'}->();
	}
	else {
		$commands{$ARGV[0]}->();
	}
}

main() if $0 eq __FILE__;

=end private
=cut
