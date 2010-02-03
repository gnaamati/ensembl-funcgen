#
# Ensembl module for Bio::EnsEMBL::DBSQL::ProbeAdaptor
#
# You may distribute this module under the same terms as Perl itself

=head1 NAME

Bio::EnsEMBL::DBSQL::ProbeAdaptor - A database adaptor for fetching and
storing Probe objects.

=head1 SYNOPSIS

my $opa = $db->get_ProbeAdaptor();

my $probe = $opa->fetch_by_array_probe_probeset('Array-1', 'Probe-1', undef);

=head1 DESCRIPTION

The ProbeAdaptor is a database adaptor for storing and retrieving
Probe objects.

This module is part of the Ensembl project: http://www.ensembl.org/

=head1 CONTACT

Post comments or questions to the Ensembl development list: ensembl-dev@ebi.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;

package Bio::EnsEMBL::Funcgen::DBSQL::ProbeAdaptor;

use Bio::EnsEMBL::Utils::Exception qw( throw warning );
use Bio::EnsEMBL::Funcgen::Probe;
use Bio::EnsEMBL::Funcgen::DBSQL::BaseAdaptor;
use Tie::File;

use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::Funcgen::DBSQL::BaseAdaptor);
my @true_tables = (['probe', 'p']);
my @tables = @true_tables;


=head2 fetch_by_array_probe_probeset_name

  Arg [1]    : string - name of array
  Arg [2]    : string - name of probe
  Arg [3]    : (optional) string - name of probeset
  Example    : my $probe = $opa->fetch_by_array_probeset_probe('Array-1', 'Probe-1', 'ProbeSet-1');
  Description: Returns a probe given a combination of array name, probeset and
               probe name. This will uniquely define an Affy probe. Only one
			   probe is ever returned.
  Returntype : Bio::EnsEMBL::Funcgen::Probe
  Exceptions : throws if array or probe name not defined
  Caller     : General
  Status     : At Risk - rename to fetch_by_probe_array_probeset_name?

=cut

sub fetch_by_array_probe_probeset_name {
	my ($self, $array_name, $probe_name, $probeset_name) = @_;
	
	if(! (defined $array_name && defined $probe_name)){
	  throw('You must provide at least and array and probe name');
	}

	#Extend query
	push @tables, (['array', 'a'], ['array_chip', 'ac']);
	my $constraint = 'a.name = ? AND a.array_id=ac.array_id AND ac.array_chip_id=p.array_chip_id AND p.name= ?' ;
	$self->bind_param_generic_fetch($array_name,SQL_VARCHAR);
	$self->bind_param_generic_fetch($probe_name,SQL_VARCHAR);

	#Add probeset clause
	if(defined $probeset_name){
	  $constraint .= ' AND p.probe_set_id = ps.probe_set_id AND ps.name = ?';
	  push @tables, ['probe_set', 'ps'];
	  $self->bind_param_generic_fetch($probeset_name,SQL_VARCHAR);
	}

	#Have to group by primary key!
	$constraint .= ' GROUP by p.probe_id, p.name, p.array_chip_id';	
	my $probe =  eval{$self->generic_fetch($constraint)->[0]};
	my $error = $@;
	#Reset tables
	@tables = @true_tables;
	throw("Cannot continue due to error: $error") if $error; 
	return $probe;
}


=head2 fetch_probe_cache_by_Experiment

  Arg [1]    : Bio::EnsEMBL::Funcgen::Experiment
  Example    : my $probe_cache = $opa->fetch_probe_cache_by_Experiment($exp);
  Description: Returns a hashref with key value pairs as probe name and id respectively.
               This is intended as a quick and dirty method for experimental data import
  Returntype : Hashref
  Exceptions : Throws if arg is not valid and stored
  Caller     : General
  Status     : At Risk - move to Importer

=cut


sub fetch_probe_cache_by_Experiment{
  my ($self, $exp) = @_;

  my @tie_cache;
  throw('Need to fetch the probe cache by Array not Experiment');

  #where are we going to get the file path from?
  my $cache_file = $ENV{'EFG_DATA'}.'/output/'.$exp->name().'/'.$exp->name().'.probe_cache';


  #do we want to use a previously generated cache?
  #could validate length versus count of probes in DB.
  #cache could be corrupt, i.e. missing X Y vals?
  #should be okay, but we may encounter problem if we try and overwrite the cache with new vals
  

  if(! ($exp && $exp->isa("Bio::EnsEMBL::Funcgen::Experiment") && $exp->dbID())){
    throw("Must proved a valid stored Bio::EnsEMBL::Funcgen::Experiment");
  }

  my @achip_ids;
  
  foreach my $echip(@{$exp->get_ExperimentalChips()}){
    push @achip_ids, $echip->array_chip_id();
  }


  #need to validate probe_cache here by check keys against probe count ;)

  if(@achip_ids){

    my $sql = 'SELECT name, probe_id from probe where array_chip_id IN ('.join(',', @achip_ids).');';

    warn 'fetch_probe_cache will break if we have duplicated names within the Experimental set';
	#Will this handle multiple name probes?

	my $cmd = 'mysql '.$self->db->connect_string()." -e \"$sql\" >".$cache_file;


    #%cache = @{$self->db->dbc->db_handle->selectcol_arrayref($sql, { Columns =>[1, 2]})};
  }
  

  tie @tie_cache, 'Tie::File', $cache_file or throw('Failed to tie probe_cache file');

  return \@tie_cache;
}




=head2 fetch_all_by_name

  Arg [1]    : string - probe name
  Example    : my @probes = @{$opa->fetch_all_by_name('Probe1')};
  Description: Returns an arrayref of all probes with this name. 
               These may exist on different ArrayChips from different vendors.
  Returntype : Arrayref
  Exceptions : Throws if name not passed
  Caller     : General
  Status     : At Risk

=cut


sub fetch_all_by_name{
  my ($self, $name) = @_;


  throw('Must provide a probe name argument') if ! defined $name;

  my $constraint = "p.name='$name'";

  return $self->generic_fetch($constraint);
}




=head2 fetch_all_by_ProbeSet

  Arg [1]    : Bio::EnsEMBL::ProbeSet
  Example    : my @probes = @{$opa->fetch_all_by_ProbeSet($pset)};
  Description: Fetch all probes in a particular ProbeSet.
  Returntype : Listref of Bio::EnsEMBL::Probe objects
  Exceptions : None
  Caller     : General
  Status     : At Risk

=cut

sub fetch_all_by_ProbeSet {
	my ($self, $probeset) = @_;
	
	$self->db->is_stored_and_valid('Bio::EnsEMBL::Funcgen::ProbeSet', $probeset);
	return $self->generic_fetch('p.probe_set_id = '.$probeset->dbID);
}



=head2 fetch_all_by_Array

  Arg [1]    : Bio::EnsEMBL::Funcgen::Array
  Example    : my @probes = @{$opa->fetch_all_by_Array($array)};
  Description: Fetch all probes on a particular array.
  Returntype : Listref of Bio::EnsEMBL::Probe objects.
  Exceptions : throws if arg is not valid or stored
  Caller     : General
  Status     : At Risk

=cut

sub fetch_all_by_Array {
  my $self  = shift;
  my $array = shift;
  
   if(! (ref($array) && $array->isa('Bio::EnsEMBL::Funcgen::Array') && $array->dbID())){
     throw('Need to pass a valid stored Bio::EnsEMBL::Funcgen::Array');
   }

  #get all array_chip_ids, for array and do a multiple OR statement with generic fetch
  
  return $self->generic_fetch("p.array_chip_id IN (".join(",", @{$array->get_array_chip_ids()}).")");
}

=head2 fetch_all_by_ArrayChip

  Arg [1]    : Bio::EnsEMBL::Funcgen::ArrayChip
  Example    : my @probes = @{$opa->fetch_all_by_ArrayChip($array_chip)};
  Description: Fetch all probes on a particular ArrayChip.
  Returntype : Listref of Bio::EnsEMBL::Probe objects.
  Exceptions : throw is arg is not valid or stored
  Caller     : General
  Status     : At Risk

=cut

sub fetch_all_by_ArrayChip {
  my $self  = shift;
  my $array_chip = shift;
  
  if(! (ref($array_chip) && $array_chip->isa('Bio::EnsEMBL::Funcgen::ArrayChip') && $array_chip->dbID())){
    throw('Need to pass a valid stored Bio::EnsEMBL::Funcgen::ArrayChip');
  }
  
  return $self->generic_fetch("p.array_chip_id =".$array_chip->dbID());
}



=head2 fetch_by_ProbeFeature

  Arg [1]    : Bio::EnsEMBL::Funcgen::ProbeFeature
  Example    : my $probe = $opa->fetch_by_ProbeFeature($feature);
  Description: Returns the probe that created a particular feature.
  Returntype : Bio::EnsEMBL::Probe
  Exceptions : Throws if argument is not a Bio::EnsEMBL::Funcgen::ProbeFeature object
  Caller     : General
  Status     : At Risk

=cut

sub fetch_by_ProbeFeature {
  my $self    = shift;
  my $feature = shift;
  
  if (
      !ref($feature)
      || !$feature->isa('Bio::EnsEMBL::Funcgen::ProbeFeature')
      || !$feature->{'probe_id'}
     ) {
    throw('fetch_by_ProbeFeature requires a stored Bio::EnsEMBL::Funcgen::ProbeFeature object');
  }
  
  return $self->fetch_by_dbID($feature->{'probe_id'});
}

=head2 _tables

  Args       : None
  Example    : None
  Description: PROTECTED implementation of superclass abstract method.
               Returns the names and aliases of the tables to use for queries.
  Returntype : List of listrefs of strings
  Exceptions : None
  Caller     : Internal
  Status     : At Risk

=cut

sub _tables {
	my $self = shift;

  	return @tables;
}

=head2 _columns

  Args       : None
  Example    : None
  Description: PROTECTED implementation of superclass abstract method.
               Returns a list of columns to use for queries.
  Returntype : List of strings
  Exceptions : None
  Caller     : Internal
  Status     : At Risk

=cut

sub _columns {
  my $self = shift;

  return qw( p.probe_id p.probe_set_id p.name p.length p.array_chip_id p.class);

}

=head2 _objs_from_sth

  Arg [1]    : DBI statement handle object
  Example    : None
  Description: PROTECTED implementation of superclass abstract method.
               Creates Probe objects from an executed DBI statement
			   handle.
  Returntype : Listref of Bio::EnsEMBL::Funcgen::Probe objects
  Exceptions : None
  Caller     : Internal
  Status     : At Risk

=cut

sub _objs_from_sth {
	my ($self, $sth) = @_;
	
	my (@result, $current_dbid, $arraychip_id, $probe_id, $array_id, $probe_set_id, $name, $class, $probelength);
	my ($array, %array_cache, %probe_set_cache);
	
	$sth->bind_columns(\$probe_id, \$probe_set_id, \$name, \$probelength, \$arraychip_id, \$class);


	#Complex query extension
	#We want the arrays, array_chip and probeset information setting
	#So the probe feature zmenu can just do one query to populate the zmenu unstead of 4
	#Let's just do this with probset to start with as this is more simple
	#The object creation for the linked adaptors need to be commodotised
	#So we can say something like $probeset_adaptor->create_obj_from_sth_args
	#Caches will need to be built in the calling adaptor rather than the true object adaptor
	
	#No group required as we will always want intermediate data
	#Therefore cannot use this in combined with simple extension???
	#Unless we explicitly state group by primary keys.

	#Need to build array of adaptor column hashes(order important)
	#Need to build and array of bound columns dependant 
	#Then we need to parse output dependant on primary keys of each table
	#So we would need bolumns bound to hash values
	
	#We need a way to define the extended tables
	#Pass param hash to caller which uses BaseAdaptor method to add tables and columns
	#This would have to take into account anything added by the caller
	
	#Maybe the better way of doing this test would be to include all probes in a probeset?
	#Or maybe all probe_features for a probe?
	



	my $probe;
	
	while ( $sth->fetch() ) {

		#warn("Need to sort array cacheing, have redundant cache!!");
		#This is nesting array and probeset objects in probe!
		

		#Is this required? or should we lazy load this?
		#Should we also do the same for probe i.e. nest or lazy load probeset
		#Setting here prevents, multiple queries, but if we store the array cache in the adaptor we can overcome this
		#danger of eating memory here, but it's onld the same as would be used for generating all the probesets
		#what about clearing the cache?
		#also as multiple array_chips map to same array, cache would be redundant
		#need to store only once and reference.
		#have array_cache and arraychip_map
		#arraychip_map would give array_id which would be key in array cache
		#This is kinda reinventing the wheel, but reducing queries and redundancy of global cache
		#cache would never be populated if method not called
		#there for reducing calls and memory, increasing speed of generation/initation
		#if method were called
		#would slightly slow down processing, and would slightly increase memory as cache(small as non-redundant)
		#and map hashes would persist

	
	  ####MAKE THIS LAZY LOADED!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
	  #Can we even do this given we won't then have the array context?
	  #We should just force this for efficiency and make people keep the array if they ever want to use that info?
	  #Will this affect any other methods?
	  


	  #Can we not change this to an ArrayChip cache and just reimplement the array method?

		$array = $array_cache{$arraychip_id} || $self->db->get_ArrayAdaptor()->fetch_by_array_chip_dbID($arraychip_id);
	
		
		#I don't think we need this?  Certainly not for storing

		#$probe_set = $probe_set_cache{$probe_set_id} || $self->db->get_ArrayAdaptor()->fetch_by_array_chip_dbID($arraychip_id);
		#probe_set cache would be substantially bigger!!
		#potentially as many as the probes

		#Just build cache and nest for now,may want to just return ID and lazy load

		#This is a prime target for compound query extension
		#Either extend query by default and nest probe_set
		#Or lazy load probeset using cache somehow?
		#Use persistant probeset cache in ProbeSetAdaptor for dbID/Probe style queries

		my ($probeset);

		if($probe_set_id){
			$probeset = $probe_set_cache{$probe_set_id} || $self->db->get_ProbeSetAdaptor()->fetch_by_dbID($probe_set_id);
		}

		if (!$current_dbid || $current_dbid != $probe_id) {
			# New probe

			#UC??? or does rearrange handle this?

			$probe = Bio::EnsEMBL::Funcgen::Probe->new
			  (
			   -dbID          => $probe_id,
			   -name          => $name,
			   -array_chip_id => $arraychip_id,
			   -array         => $array,
			   -probe_set     => $probeset,
			   -length        => $probelength,
			   -class         => $class,
			   -adaptor       => $self,
			);
			push @result, $probe;
			$current_dbid = $probe_id;
		} else {
		  # Extend existing probe
		  # Probe methods depend on preloading of Array objects
		  $probe->add_array_chip_probename($arraychip_id, $name, $array);
		}
	}
	return \@result;
}

=head2 store

  Arg [1]    : List of Bio::EnsEMBL::Funcgen::Probe objects
  Example    : $opa->store($probe1, $probe2, $probe3);
  Description: Stores given Probe objects in the database. Should only be
               called once per probe because no checks are made for duplicates
			   Sets dbID and adaptor on the objects that it stores.
  Returntype : ARRAYREF
  Exceptions : Throws if arguments are not Probe objects
  Caller     : General
  Status     : At Risk

=cut

sub store {
  my ($self, @probes) = @_;
  
  my ($ac_id, $sth, $dbID, @panals, $pd_sth);
  my $pd_sql = "INSERT IGNORE into probe_design(probe_id, analysis_id, score, coord_system_id) values(?, ?, ?, ?)";
  my $db = $self->db();
  throw('Must call store with a list of Probe objects') if (scalar @probes == 0);

  #mv all prep statements here?
  #or at least main probe insert


 PROBE: foreach my $probe (@probes) {
    undef $dbID;

	if ( !ref $probe || ! $probe->isa('Bio::EnsEMBL::Funcgen::Probe') ) {
      throw("Probe must be an Probe object ($probe)");
    }
    
    if ( $probe->is_stored($db) ) {
      warning('Probe [' . $probe->dbID() . '] is already stored in the database');
      next PROBE;
    }
    
    # Get all the arrays this probe is on and check they're all in the database
    my %array_hashes;
    
    foreach $ac_id (keys %{$probe->{'arrays'}}) {
            
      if (defined ${$probe->{'arrays'}}{$ac_id}->dbID()) {
      #Will this ever work as generally we're creating from scratch and direct access to keys above by passes DB fetch
        $array_hashes{$ac_id} = $probe->{'arrays'}{$ac_id};
      }
    }

    throw('Probes need attached arrays to be stored in the database') if ( ! %array_hashes );
	
    # Insert separate entry (with same oligo_probe_id) in oligo_probe
    # for each array/array_chip the probe is on
    foreach $ac_id (keys %array_hashes) {			
      my $ps_id = (defined $probe->probeset()) ? $probe->probeset()->dbID() : undef;
      
	  foreach my $name(@{$probe->get_all_probenames($array_hashes{$ac_id}->name)}){

		if (defined $dbID) {  # Already stored
		  #we want to import design attrs bsed on ac_id..and cs id or design attr?
		
		
		  $sth = $self->prepare
			("INSERT INTO probe( probe_id, probe_set_id, name, length, array_chip_id, class )
			  VALUES (?, ?, ?, ?, ?, ?)");
		  $sth->bind_param(1, $dbID,            SQL_INTEGER);
		  $sth->bind_param(2, $ps_id,           SQL_INTEGER);
		  $sth->bind_param(3, $name,            SQL_VARCHAR);
		  $sth->bind_param(4, $probe->length(), SQL_INTEGER);
		  $sth->bind_param(5, $ac_id,           SQL_INTEGER);
		  $sth->bind_param(6, $probe->class(),  SQL_VARCHAR);
		  $sth->execute();
		}
		else {
		  # New probe
		  $sth = $self->prepare
			("INSERT INTO probe( probe_set_id, name, length, array_chip_id, class )
			VALUES (?, ?, ?, ?, ?)");
		  $sth->bind_param(1, $ps_id,           SQL_INTEGER);
		  $sth->bind_param(2, $name,            SQL_VARCHAR);
		  $sth->bind_param(3, $probe->length(), SQL_INTEGER);
		  $sth->bind_param(4, $ac_id,           SQL_INTEGER);
		  $sth->bind_param(5, $probe->class(),  SQL_VARCHAR);
		  $sth->execute();
		  $dbID = $sth->{'mysql_insertid'};
		  $probe->dbID($dbID);
		  $probe->adaptor($self);
		}
	  }
	}
  
	if(@panals = @{$probe->get_all_design_scores(1)}){#1 is no fetch flag
	  #we need to check for duplicates here, or can we just ignore them in the insert statement?
	  #ignoring would be convenient but may lose info about incorrect duplicates
	  #also not good general practise
	  #solution would be nest them with a dbid value aswell as score
	  #use ignore for now and update implementation when we create BaseProbeDesign?
	  
	  $pd_sth ||= $self->prepare($pd_sql);
	  
	  foreach my $probe_analysis(@panals){
		my ($analysis_id, $score, $cs_id) = @$probe_analysis;
		$cs_id ||=0;#NULL
		
		$pd_sth->bind_param(1, $probe->dbID(),  SQL_INTEGER);
		$pd_sth->bind_param(2, $analysis_id,    SQL_INTEGER);
		$pd_sth->bind_param(3, $score,          SQL_VARCHAR);
		$pd_sth->bind_param(4, $cs_id,          SQL_INTEGER);
		$pd_sth->execute();
		
	  }
	}
  }

  return \@probes;
}



=head2 fetch_all_design_scores

  Arg [1]    : Bio::EnsEMBL::Funcgen::Probe
  Example    : my @probe_analyses = @{$pa->fetch_all_design_scores($probe)};
  Description: Fetchs all probe design analysis records as analysis_id, score and coord_system_id
  Returntype : ARRAYREF
  Exceptions : throws if not passed a valid stored Probe
  Caller     : General
  Status     : at risk

=cut

sub fetch_all_design_scores{
  my ($self, $probe) = @_;

  if(! ($probe && $probe->isa('Bio::EnsEMBL::Funcgen::Probe') && $probe->dbID())){
    throw('Must pass a valid stored Bio::EnsEMBL::Funcgen::Probe');
  }

  my $sql = 'SELECT analysis_id, score, coord_system_id from probe_design WHERE probe_id='.$probe->dbID.';';
  return @{$self->db->dbc->db_hanle->selectall_arrayref($sql)};
}



=head2 list_dbIDs

  Arg [1]    : none
  Example    : my @feature_ids = @{$opa->list_dbIDs()};
  Description: Gets an array of internal IDs for all Probe objects in the
               current database.
  Returntype : List of ints
  Exceptions : None
  Caller     : ?
  Status     : At Risk

=cut

sub list_dbIDs {
	my ($self) = @_;

	return $self->_list_dbIDs('probe');
}



1;

