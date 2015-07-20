#!/usr/bin/env perl

use strict;
use warnings;
use Test::More;
use Test::Exception;
use Bio::EnsEMBL::Test::TestUtils;
use Bio::EnsEMBL::Funcgen::CellType;

# Module compiles
ok( 1, 'Bio::EnsEMBL::Funcgen::CellType compiles' );

#
# Test constructor
#

my $ct = Bio::EnsEMBL::Funcgen::CellType->new(
    -name          => 'H1-ESC',
    -display_label => 'H1-ESC',
    -description   => 'Human Embryonic Stem Cell',
    -gender        => 'female',
    -efo_id        => 'efo:EFO_0003042',
    -tissue        => 'embryonic stem cell',
);

isa_ok( $ct, 'Bio::EnsEMBL::Funcgen::CellType', 'CellType' );

throws_ok { Bio::EnsEMBL::Funcgen::CellType->new }
qr/Must supply a CellType name/, 'Check that name is supplied';

# my $invalid_gender_ct = Bio::EnsEMBL::Funcgen::CellType->new(
#     -name          => 'H1-ESC',
#     -display_label => 'H1-ESC',
#     -description   => 'Human Embryonic Stem Cell',
#     -gender        => 'femaler',
#     -efo_id        => 'efo:EFO_0003042',
#     -tissue        => 'embryonic stem cell',
# );

throws_ok {
    Bio::EnsEMBL::Funcgen::CellType->new(
        -name          => 'H1-ESC',
        -display_label => 'H1-ESC',
        -description   => 'Human Embryonic Stem Cell',
        -gender        => 'femaler',
        -efo_id        => 'efo:EFO_0003042',
        -tissue        => 'embryonic stem cell',
    );
}
qr/Gender not valid, must be one of/, 'tough';

# is( $ct->{name},          'H1-ESC', 'Retrieve cell type name' );
# is( $ct->{display_label}, 'H1-ESC', 'Retrieve cell type display name' );
# is( $ct->{description},
#     'Human Embryonic Stem Cell',
#     'Retrieve cell type description'
# );
# is( $ct->{gender}, 'female',              'Retrieve cell type gender' );
# is( $ct->{efo_id}, 'efo:EFO_0003042',     'Retrieve cell type efo_id' );
# is( $ct->{tissue}, 'embryonic stem cell', 'Retrieve cell type tissue' );

#
# Test getter subroutines
#

is( $ct->name,          'H1-ESC', 'Retrieve cell type name' );
is( $ct->display_label, 'H1-ESC', 'Retrieve cell type display name' );
is( $ct->description,
    'Human Embryonic Stem Cell',
    'Retrieve cell type description'
);
is( $ct->gender, 'female',              'Retrieve cell type gender' );
is( $ct->efo_id, 'efo:EFO_0003042',     'Retrieve cell type efo_id' );
is( $ct->tissue, 'embryonic stem cell', 'Retrieve cell type tissue' );

#
# Test gender definition
#

# $ct = Bio::EnsEMBL::Funcgen::CellType->new(

#     # -name          => 'H1-ESC',
#     -display_label => 'H1-ESC',
#     -description   => 'Human Embryonic Stem Cell',
#     -gender        => 'female',
#     -efo_id        => 'efo:EFO_0003042',
#     -tissue        => 'embryonic stem cell',
# );

done_testing();
