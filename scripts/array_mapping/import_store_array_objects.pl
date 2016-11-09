#!/usr/bin/env perl

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Funcgen::DBSQL::DBAdaptor;
use Getopt::Long;

=head1

perl /nfs/users/nfs_m/mn1/various_scripts/probemapping/test_store_array_objects.pl \
  --url 'mysql://ensadmin:ensembl@ens-genomics2:3306/mn1_tracking_homo_sapiens_funcgen_87_38?group=funcgen&species=homo_sapiens' \
  --species homo_sapiens \
  --array_objects_file /lustre/scratch109/ensembl/funcgen/array_mapping/array_objects.pl

=cut

my $registry;
# my $url;
my $species;
my $array_objects_file;

GetOptions (
   'registry=s'      => \$registry,
#    'url=s'      => \$url,
   'species=s'         => \$species,
   'array_objects_file=s' => \$array_objects_file,
);

Bio::EnsEMBL::Registry->load_all($registry);
# Bio::EnsEMBL::Registry->load_registry_from_url($url, 1);

my $array_adaptor      = Bio::EnsEMBL::Registry->get_adaptor($species, 'funcgen', 'array');
my $array_chip_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, 'funcgen', 'arraychip');
my $probe_adaptor      = Bio::EnsEMBL::Registry->get_adaptor($species, 'funcgen', 'probe');
my $probe_set_adaptor  = Bio::EnsEMBL::Registry->get_adaptor($species, 'funcgen', 'probeset');

=head2

truncate array;
truncate array_chip;
truncate probe;
truncate probe_feature;
truncate probe_alias;
truncate probe_seq;
truncate probe_set;

=cut

my %array_name_to_object;
my $fetch_array_from_db = sub {

  my $array = shift;

  if (exists $array_name_to_object{$array->name}) {
  
    # If we have an array object in the datatabase already and used this 
    # before, then reuse it.
    #
    $array = $array_name_to_object{$array->name};
    
  } else {
  
    # Otherwise try to fetch it from the database
    my $array_from_db = $array_adaptor->fetch_by_name($array->name);
    
    if (defined $array_from_db) {
      
      # If there is an instance of this array in the database already, then 
      # use this.
      #
      $array = $array_from_db;
      
    } else {
    
      # Otherwise store the array.
      $array_adaptor->store($array);
    }
    # Finally store in the cache for reuse with other probes of that array.
    $array_name_to_object{$array->name} = $array;
  }

  return $array;
};

my %array_chip_name_to_object;
my $fetch_array_chip_from_db = sub {

  my $array      = shift;
  my $array_chip = shift;
  
  if (exists $array_chip_name_to_object{$array_chip->name}) {
    $array_chip = $array_chip_name_to_object{$array_chip->name};
  } else {
  
    my $array_chip_from_db = $array_chip_adaptor->fetch_by_name($array_chip->name);
    
    if (defined $array_chip_from_db) {
      $array_chip = $array_chip_from_db;
    } else {
      $array_chip->array_id($array->dbID);
      $array_chip_adaptor->store($array_chip);
    }
    $array_chip_name_to_object{$array_chip->name} = $array_chip;
  }
  
  return $array_chip;
};

my %probe_set_name_to_object;
my $fetch_probe_set_from_db = sub {

  my $array_name = shift;
  my $probe_set  = shift;
  
  if (exists $probe_set_name_to_object{$probe_set->name}) {
    $probe_set = $probe_set_name_to_object{$probe_set->name};
  } else {
  
    my $probe_set_from_db = $probe_set_adaptor->fetch_by_array_probeset_name($array_name, $probe_set->name);
    
    if (defined $probe_set_from_db) {
      $probe_set = $probe_set_from_db;
    } else {
      $probe_set->size(1);
      $probe_set_adaptor->store($probe_set);
    }
    $probe_set_name_to_object{$probe_set->name} = $probe_set;
  }
  
  return $probe_set;
};

my $process_array_objects = sub {

  my $probe = shift;

  my $arrays = $probe->get_all_Arrays;
  die if (@$arrays!=1);
  my $array = $arrays->[0];
  
  my $array_from_db = $fetch_array_from_db->($array);
  
  # HACK, but the api doesn't support this otherwise
  $probe->{'arrays'} = {
    $array->name => $array_from_db,
  };

  my $array_chip = $probe->array_chip;
  my $array_chip_from_db = $fetch_array_chip_from_db->($array, $array_chip);
  $probe->array_chip($array_chip_from_db);
  
  if ($probe->probeset) {
    my $probeset_from_db = $fetch_probe_set_from_db->($array->name, $probe->probeset);
    $probe->probeset($probeset_from_db);
  }
  
#   print Dumper($probe);
  $probe_adaptor->store($probe);
};

use Bio::EnsEMBL::Funcgen::Parsers::DataDumper;
my $parser = Bio::EnsEMBL::Funcgen::Parsers::DataDumper->new;

$parser->parse({
  data_dumper_file => $array_objects_file,
  call_back        => $process_array_objects,
});
