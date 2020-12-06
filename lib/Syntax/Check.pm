package Syntax::Check;

use warnings;
use strict;
use feature 'say';

use Carp qw(croak);
use Exporter qw(import);
use File::Path qw(make_path);
use File::Temp qw(tempdir);
use PPI;

our $VERSION = '1.00';

sub new {
    my ($class, %p) = @_;

    if (! exists $p{file} || ! -f $p{file}) {
        croak "new() requires a file name as its first parameter";
    }

    my $self = bless {%p}, $class;

    return $self;
}
sub check {
    my ($self) = @_;

    my $doc = PPI::Document->new($self->{file});

    my $includes = $doc->find('PPI::Statement::Include');

    for my $include (@$includes) {

        my $module = $include->module;
        my $package = $module;

        if ($module eq lc $module) {
            # Skip pragmas
            say "Skipping assumed pragma '$module'" if $self->{verbose};
            next;
        }

        $module =~ s|::|/|g;
        if (my ($dir, $file) = $module =~ m|^(.*)/(.*)$|) {
            $file .= '.pm';
            my $path = "$dir/$file";

            if (exists $INC{$path}) {
                # Skip includes that are actually available
                say "Skipping available module '$package'" if $self->{verbose};
                next;
            }
            else {
                $self->_create_lib_dir;

                if (! -d "$self->{lib}/$dir") {
                    # Create the module directory structure
                    make_path("$self->{lib}/$dir") or die $!;
                }

                if (! -f "$self->{lib}/$path") {
                    # Create the module file
                    open my $wfh, '>', "$self->{lib}/$path" or die $!;
                    print $wfh '1;';
                    close $wfh or die $!;
                }
            }
        }
        else {
            # Single-word module, ie. no directory structure
            $self->_create_lib_dir;

            my $module_file = "$module.pm";
            if (! -f "$self->{lib}/$module_file") {
                # Create the module file
                open my $wfh, '>', "$self->{lib}/$module_file" or die $!;
                print $wfh '1;';
                close $wfh or die $!;
            }
        }
    }

    `perl -I$self->{lib} -c $self->{file}`;
}
sub _create_lib_dir {
    my ($self) = @_;
    if (! exists $self->{lib} || ! -d $self->{lib}) {
        $self->{cleanup} = exists $self->{keep} ? ! $self->{keep} : 1;
        $self->{lib} = tempdir(CLEANUP => $self->{cleanup});
        say "Created temp lib dir '$self->{lib}'" if $self->{verbose};
    }
}
sub __placeholder {}

1;
__END__

=head1 NAME

Syntax::Check - Wraps 'perl -c' so it works even if modules are unavailable

=for html
<a href="http://travis-ci.org/stevieb9/mock-sub"><img src="https://secure.travis-ci.org/stevieb9/syntax-check.png"/>
<a href='https://coveralls.io/github/stevieb9/syntax-check?branch=master'><img src='https://coveralls.io/repos/stevieb9/syntax-check/badge.svg?branch=master&service=github' alt='Coverage Status' /></a>


=head1 DESCRIPTION

This module is a wrapper around C<perl -c> for situations where you're trying
to do a syntax check on a Perl file, but the libraries that are C<use>d by the
file are not available to the file.

=head1 SYNOPSIS

Binary:

    ./syncheck [--verbose] [--keep] perl_filename.ext

Library:

    use Syntax::Check;

    Syntax::Check->new(%opts, $filename)->check;

=head1 BINARY PROGRAM syncheck

Installed with this library is a binary application that uses the library.

Usage:

    ./syncheck [-k] [-v] perl_file_name.ext

=head2 --keep|-k

If supplied, we will keep the temporary library directory structure in your
temp dir. By default we delete this directory upon program completion.

=head2 --verbose|-v

Supply this argument to get verbose output.


=head1 METHODS

=head2 new(%p, $file)

Instantiates and returns a new C<Syntax::Check> object.

Parameters:

    keep => Bool

Optional, Bool. Delete the temporary library directory structure after the run
finishes.

Default: False

    verbose => Bool

Optional, Bool: Enable verbose output.

Default: False

    $file

Mandatory, String: The name of the Perl file to operate on.

=head2 check()

Performs the introspection of the Perl file we're operating on, hides away the
fact that we have library includes that aren't available, and performs a
C<perl -c> on the file.

=head1 AUTHOR

Steve Bertrand, C<< <steveb at cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright 2020 Steve Bertrand.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>
