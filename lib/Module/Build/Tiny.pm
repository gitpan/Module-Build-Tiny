package Module::Build::Tiny;
{
  $Module::Build::Tiny::VERSION = '0.011';
}
use strict;
use warnings;
use Exporter 5.57 'import';
our @EXPORT = qw/Build Build_PL/;

use CPAN::Meta;
use ExtUtils::BuildRC 0.003 qw/read_config/;
use ExtUtils::Config 0.003;
use ExtUtils::Helpers 0.010 qw/make_executable split_like_shell build_script manify man1_pagename man3_pagename/;
use ExtUtils::Install qw/pm_to_blib install/;
use ExtUtils::InstallPaths 0.002;
use File::Find::Rule qw/find/;
use File::Slurp qw/read_file write_file/;
use File::Spec::Functions qw/catfile catdir rel2abs/;
use Getopt::Long qw/GetOptions/;
use JSON 2 qw/encode_json decode_json/;
use TAP::Harness;

my ($metafile) = grep { -e $_ } qw/META.json META.yml/ or die "No META information provided\n";
my $meta = CPAN::Meta->load_file($metafile);

my %actions = (
	build => sub {
		my %opt = @_;
		system $^X, $_ and die "$_ returned $?\n" for find(file => name => '*.PL', in => 'lib');
		my %modules = map { $_ => catfile('blib', $_) } find(file => name => [qw/*.pm *.pod/], in => 'lib');
		my %scripts = map { $_ => catfile('blib', $_) } find(file => name => '*', in => 'script');
		pm_to_blib({ %modules, %scripts }, catdir(qw/blib lib auto/));
		make_executable($_) for values %scripts;

		if ($opt{config}->exists('installman3dir')) {
			manify($_, catfile('blib', 'bindoc', man1_pagename($_)), 1, \%opt) for keys %scripts;
			manify($_, catfile('blib', 'libdoc', man3_pagename($_)), 3, \%opt) for keys %modules;
		}
	},
	test => sub {
		my %opt = @_;
		die "Must run `./Build build` first\n" if not -d 'blib';
		my $tester = TAP::Harness->new({verbosity => $opt{verbose}, lib => rel2abs(catdir(qw/blib lib/)), color => -t STDOUT});
		$tester->runtests(sort +find(file => name => '*.t', in => 't'))->has_errors and exit 1;
	},
	install => sub {
		my %opt = @_;
		die "Must run `./Build build` first\n" if not -d 'blib';
		my $paths = ExtUtils::InstallPaths->new(%opt, dist_name => $meta->name);
		install($paths->install_map, @opt{qw/verbose dry_run uninst/});
	},
);

sub Build {
	my $bpl = decode_json(read_file('_build_params'));
	my $action = @ARGV && $ARGV[0] =~ /\A\w+\z/ ? shift @ARGV : 'build';
	die "No such action '$action'\n" if not $actions{$action};
	my $rc_opts = read_config();
	my @env = defined $ENV{PERL_MB_OPT} ? split_like_shell($ENV{PERL_MB_OPT}) : ();
	unshift @ARGV, map { @{$_} } grep { defined } $rc_opts->{'*'}, $bpl, $rc_opts->{$action}, \@env;
	GetOptions(\my %opt, qw/install_base=s install_path=s% installdirs=s destdir=s prefix=s config=s% uninst:1 verbose:1 dry_run:1/);
	$opt{config} = ExtUtils::Config->new($opt{config});
	$actions{$action}->(%opt);
}

sub Build_PL {
	printf "Creating new 'Build' script for '%s' version '%s'\n", $meta->name, $meta->version;
	my $dir = $meta->name eq 'Module-Build-Tiny' ? 'lib' : 'inc';
	write_file(build_script(), "#!perl\nuse lib '$dir';\nuse Module::Build::Tiny;\nBuild();\n");
	make_executable(build_script());
	write_file(qw/_build_params/, encode_json(\@ARGV));
	write_file("MY$_", read_file($_)) for grep { -f } qw/META.json META.yml/;
}

1;



=pod

=head1 NAME

Module::Build::Tiny - A tiny replacement for Module::Build

=head1 VERSION

version 0.011

=head1 SYNOPSIS

 use Module::Build::Tiny;
 BuildPL();

=head1 DESCRIPTION

Many Perl distributions use a Build.PL file instead of a Makefile.PL file
to drive distribution configuration, build, test and installation.
Traditionally, Build.PL uses Module::Build as the underlying build system.
This module provides a simple, lightweight, drop-in replacement.

Whereas Module::Build has over 6,700 lines of code; this module has less
than 70, yet supports the features needed by most pure-Perl distributions.

=head2 Supported

=over 4

=item * Pure Perl distributions

=item * Recursive test files

=item * MYMETA

=item * Man page generation

=item * Generated code from PL files

=back

=head2 Not Supported

=over 4

=item * Dynamic prerequisites

=item * Building XS or C

=item * HTML documentation generation

=item * Extending Module::Build::Tiny

=back

=head2 Directory structure

Your .pm and .pod files must be in F<lib/>.  Any executables must be in
F<script/>.  Test files must be in F<t/>.

=head1 USAGE

These all work pretty much like their Module::Build equivalents.

=head2 perl Build.PL

=head2 Build [ build ] 

=head2 Build test

=head2 Build install

This supports the following options:

=over

=item * install_base

=item * installdirs

=item * prefix

=item * install_path

=item * destdir

=item * uninst

=back

=head1 AUTHORING

This module doesn't support authoring. To develop modules using Module::Build::Tiny, usage of L<Dist::Zilla::Plugin::ModuleBuildTiny> is recommended.

=head1 CONFIG FILE AND ENVIRONMENT

Options can be provided in a F<.modulebuildrc> file or in the C<PERL_MB_OPT>
environment variable the same way they can with Module::Build.

=head1 SEE ALSO

L<Module::Build>

=head1 AUTHOR

  David Golden <dagolden@cpan.org>
  Leon Timmermans <leont@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 - 2011 by David A. Golden, Leon Timmermans

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.

=for Pod::Coverage Build_PL
=end

=head1 AUTHORS

=over 4

=item *

Leon Timmermans <leont@cpan.org>

=item *

David Golden <dagolden@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Leon Timmermans.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


__END__

#ABSTRACT: A tiny replacement for Module::Build



# vi:et:sts=2:sw=2:ts=2
