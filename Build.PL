use Module::Build;
my $build = Module::Build->new(
	module_name       => 'App::FoxyProxy::Control',
	dist_version_from => 'bin/fpc.pl',
	license           => 'perl',
	requires => {
		'perl'               => '>= 5.10.0',
		'Modern::Perl'       => '>= 1.03',
		'XML::Simple'        => '>= 2.18',
		'Proc::ProcessTable' => '>= 0.42',
	},
);
$build->create_build_script();

