#
# Ensembl module for Bio::EnsEMBL::Funcgen::RegulatoryFeature
#
# You may distribute this module under the same terms as Perl itself

=head1 NAME

Bio::EnsEMBL::RegulatoryFeature - A module to represent a regulatory feature 
mapping as generated by the eFG regulatory build pipeline.

=head1 SYNOPSIS

use Bio::EnsEMBL::Funcgen::RegulatoryFeature;

my $feature = Bio::EnsEMBL::Funcgen::RegulatoryFeature->new(
	-SLICE         => $chr_1_slice,
	-START         => 1_000_000,
	-END           => 1_000_024,
	-STRAND        => -1,
    -DISPLAY_LABEL => $text,
    -FEATURE_SET   => $fset,
    -FEATURE_TYPE  => $reg_feat_type,
); 



=head1 DESCRIPTION

A RegulatoryFeature object represents the genomic placement of a combined regulatory
feature generated by the eFG analysis pipeline, which may have originated from one or 
many separate annotated or supporting features.

=head1 AUTHOR

This module was created by Nathan Johnson.

This module is part of the Ensembl project: http://www.ensembl.org/

=head1 CONTACT

Post comments or questions to the Ensembl development list: ensembl-dev@ebi.ac.uk

=head1 METHODS

=cut

use strict;
use warnings;

package Bio::EnsEMBL::Funcgen::RegulatoryFeature;

use Bio::EnsEMBL::Utils::Argument qw( rearrange );
use Bio::EnsEMBL::Utils::Exception qw( throw );
use Bio::EnsEMBL::Funcgen::SetFeature;

use vars qw(@ISA);
@ISA = qw(Bio::EnsEMBL::Funcgen::SetFeature);


=head2 new

 
  Arg [-SCORE]: (optional) int - Score assigned by analysis pipeline
  Arg [-ANALYSIS] : Bio::EnsEMBL::Analysis 
  Arg [-SLICE] : Bio::EnsEMBL::Slice - The slice on which this feature is.
  Arg [-START] : int - The start coordinate of this feature relative to the start of the slice
		 it is sitting on. Coordinates start at 1 and are inclusive.
  Arg [-END] : int -The end coordinate of this feature relative to the start of the slice
	       it is sitting on. Coordinates start at 1 and are inclusive.
  Arg [-DISPLAY_LABEL]: string - Display label for this feature
  Arg [-STRAND]       : int - The orientation of this feature. Valid values are 1, -1 and 0.
  Arg [-FEATURE_SET]  : Bio::EnsEMBL::Funcgen::FeatureSet - Regulatory Feature set
  Arg [-FEATURE_TYPE] : Bio::EnsEMBL::Funcgen::FeatureType - Regulatory Feature sub type
  Arg [-ATTRIBUTES]   : ARRAYREF of attribute features e.g. Annotated or ? Features
  Arg [-dbID]         : (optional) int - Internal database ID.
  Arg [-ADAPTOR]      : (optional) Bio::EnsEMBL::DBSQL::BaseAdaptor - Database adaptor.
  Example    : my $feature = Bio::EnsEMBL::Funcgen::RegulatoryFeature->new(
										                                  -SLICE         => $chr_1_slice,
									                                      -START         => 1_000_000,
									                                      -END           => 1_000_024,
									                                      -STRAND        => -1,
									                                      -DISPLAY_LABEL => $text,
									                                      -FEATURE_SET   => $fset,
                                                                          -FEATURE_TYPE  => $reg_ftype,
                                                                          -REGULATORY_ATTRIBUTES    => \@features,
                                                                          -_ATTRIBUTE_CACHE => \%attr_cache,
                                                                         );


  Description: Constructor for RegulatoryFeature objects.
  Returntype : Bio::EnsEMBL::Funcgen::RegulatoryFeature
  Exceptions : None
  Caller     : General
  Status     : At Risk

=cut

sub new {
  my $caller = shift;
	
  my $class = ref($caller) || $caller;
  
  my $self = $class->SUPER::new(@_);
  
  my ($stable_id, $reg_attrs, $attr_cache)
    = rearrange(['STABLE_ID', 'REGULATORY_ATTRIBUTES', '_ATTRIBUTE_CACHE'], @_);
  
  #moved to set feature, but not mandatory?
  #throw("Must provide a FeatureType") if ! $reg_type;


  $self->stable_id($stable_id) if $stable_id;
  $self->regulatory_attributes($reg_attrs) if $reg_attrs;
  $self->_attribute_cache($attr_cache) if $attr_cache;
  	
  return $self;
}


=head2 display_label

  Arg [1]    : string - display label
  Example    : my $label = $feature->display_label();
  Description: Getter and setter for the display label of this feature.
  Returntype : String
  Exceptions : None
  Caller     : General
  Status     : Medium Risk

=cut

#this will over ride individual display_label for annotated features.
#set label could be used as track name and feature label used in zmenu?
#These should therefore be called track_label and display_label


sub display_label {
    my $self = shift;
	
    $self->{'display_label'} = shift if @_;


    #auto generate here if not set in table
    #need to go with one or other, or can we have both, split into diplay_name and display_label?
    
	#HACK to hide binary string and siplay something more meaningful

    #if(! $self->{'display_label'}  && $self->adaptor()){
	  #hardcoded for RegulatoryF Feature here instead of accessing feature_set 
	#$self->{'display_label'} = $self->feature_type->name()." Regulatory Feature";
	#$self->{'display_label'} .= " - ".$self->cell_type->name() if $self->cell_type->display_name();#?
    #}
	
	my $tmp = $self->feature_type->name()." Regulatory Feature";
	$tmp .= " - ".$self->cell_type->name() if defined $self->cell_type();#?
    return $tmp;
}


=head2 stable_id

  Arg [1]    : (optional) string - stable_id e.g ENSR00000000001
  Example    : my $stable_id = $feature->stable_id();
  Description: Getter and setter for the stable_id attribute for this feature. 
  Returntype : string
  Exceptions : None
  Caller     : General
  Status     : At Risk

=cut

sub stable_id {
  my $self = shift;
	
  $self->{'stable_id'} = shift if @_;
  
  return  (defined $self->{'stable_id'}) ? sprintf("ENSR%011d", $self->{'stable_id'}) : undef;
}


=head2 regulatory_attributes

  Arg [1]    : (optional) list of constituent features
  Example    : print "Regulatory Attributes:\n\t".join("\n\t", @{$feature->regulatory_attributes()})."\n";
  Description: Getter and setter for the regulatory_attributes for this feature. 
  Returntype : ARRAYREF
  Exceptions : None
  Caller     : General
  Status     : At Risk

=cut


#change to store attrs in type hash?

sub regulatory_attributes {
  my ($self, $attrs) = @_;
  

  my $table;

  #This is causing errors when we have not yet set the adaptor
  my %adaptors = (
				  'annotated_feature' => $self->adaptor->db->get_AnnotatedFeatureAdaptor(),
#				  #'external_feature' => $self->adaptor->db->get_ExternalFeatureAdaptor(),
				 );

  #my %attr_class_tables = (
  #'Bio::EnsEMBL::Funcgen::AnnotatedFeature' => 'annotated',
  #					   'Bio::EnsEMBL::Funcgen::CuratedFeature' => 'curated',
  #mm, get from adaptor instead? attrs should always have an adaptor set as they should be stored by now
  

  #change this to a dbID key'd hash to allow storage of only dbIDs during reg build

  #deref here for safety??
  #$self->{'regulatory_attributes'} =  [@$attrs] if $attrs;

  if(defined $attrs){# && @$attrs){

	my @attrs = @$attrs;
	
	foreach my $attr(@attrs){

	  $table = $attr->adaptor->_main_table->[0];
	  #check for isa Feature here?
	  $self->{'regulatory_attributes'}{$table}{$attr->dbID()} = $attr; 
	}
  }
  else{

	#do we need this block if we are not using the id approach outside of the reg_build script?
	#temporarily yes!!
	#Until we pass the actual features in the attr cache from build_regulatory_features.pl
	


	foreach my $table(keys %{$self->{'regulatory_attributes'}}){

	  foreach my $dbID(values %{$self->{'regulatory_attributes'}{$table}}){
		
		if(! defined $self->{'regulatory_attributes'}{$table}{$dbID}){
		  $self->{'regulatory_attributes'}{$table}{$dbID} = $adaptors{$table}->fetch_by_dbID($dbID);
		}
	  }
	}
  }

  return [ map values %{$self->{'regulatory_attributes'}{$_}}, keys %{$self->{'regulatory_attributes'}} ];
}

=head2 _attribute_cache

  Arg [1]    : (optional) hash of attribute table keys with dbID list vakues for regulatory attributes
  Example    : $feature->_attribute_cache(%attribute_table_ids);
  Description: Setter for the regulatory_attributes dbIDs for this feature. This is a short cut method used by the 
               regulatory build and the webcode to avoid having to query the DB for the underlying attribute features
  Returntype : Hasref of table keys and hash values with dbID keys
  Exceptions : None?? check for enum'd types?
  Caller     : RegulatoryFeatureAdaptor.pm and build_regulatory_features.pl
  Status     : At Risk

=cut


sub _attribute_cache{
  my ($self, $attr_table_ids) = @_;
	
  foreach my $table(keys %{$attr_table_ids}){

	foreach my $dbID(keys %{$attr_table_ids->{$table}}){

	  if(exists $self->{'regulatory_attributes'}{$table}{$dbID}){
		warn "You are trying to overwrite a pre-existing regulatory atribute cache entry for $table dbID $dbID\n";
	  }
	  else{
		#why are we setting this to undef?
		$self->{'regulatory_attributes'}{$table}{$dbID} = undef;
	  }
	}
  }

  return $self->{'regulatory_attributes'};
}




=head2 bound_start

  Example    : my $bound_start = $feature->bound_start();
  Description: Getter for the bound_start attribute for this feature.
               Gives the 5' most start value of the underlying attribute
               features.
  Returntype : string
  Exceptions : None
  Caller     : General
  Status     : At Risk

=cut

sub bound_start {
  my $self = shift;

  $self->_generate_underlying_structure() if(! defined $self->{'bound_start'});
  
  return $self->{'bound_start'};
}

=head2 bound_end

  Example    : my $bound_end = $feature->bound_start();
  Description: Getter for the bound_end attribute for this feature.
               Gives the 3' most end value of the underlying attribute
               features.
  Returntype : string
  Exceptions : None
  Caller     : General
  Status     : At Risk

=cut

sub bound_end {
  my $self = shift;
	
  $self->_generate_underlying_structure() if(! defined $self->{'bound_end'});
  
  #This should return the attr name to?

  return $self->{'bound_end'};
}

=head2 _generate_underlying_structure

  Example    :  $self->_generate_underlying_structure() if(! exists $self->{'bound_end'});
  Description: Getter for the bound_end attribute for this feature.
               Gives the 3' most end value of the underlying attribute
               features.
  Returntype : string
  Exceptions : None
  Caller     : General
  Status     : At Risk

=cut

sub _generate_underlying_structure{
  my $self = shift;


  my @attrs = @{$self->regulatory_attributes()};

  if(! @attrs){
	warn "No underlying regulatory_attribute features to generate comples structure from";
	#This should never happen
	
	#set to undef so we don't cause too many errors
	#set these to start and end instead?
	$self->{'bound_end'} = undef;
	$self->{'bound_end'} = undef;
  }
  else{
	my (@start_ends);

	throw('arg');

	map {push @start_ends, ($_->start, $_->end)} @attrs;

	@start_ends = sort { $a <=> $b } @start_ends;

	$self->{'bound_end'} = pop @start_ends;
	$self->{'bound_start'} = shift @start_ends;
  }

  return;
}
#other methods
#type!! Add to BaseFeature?  Hard code val in oligo_feature
#analysis? Use AnalsisAdapter here, or leave to caller?
#sources/experiments
#target, tar



1;

