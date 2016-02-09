=pod 

=head1 NAME

    Bio::EnsEMBL::Funcgen::Hive::Config::QC_Fastqc

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 LICENSE

    Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

    Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

         http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software distributed under the License
    is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and limitations under the License.

=head1 CONTACT

=cut

package Bio::EnsEMBL::Funcgen::Hive::Config::QC_Fastqc;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf');  # All Hive databases configuration files should inherit from HiveGeneric, directly or indirectly


# sub pipeline_wide_parameters {
#     my ($self) = @_;
#     return {
#         %{$self->SUPER::pipeline_wide_parameters},          # here we inherit anything from the base class
#     };
# }

sub pipeline_analyses {
    my ($self) = @_;
    return [
#         {   -logic_name => 'FastQCJobDefinition',
#             -module     => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
#             -meadow_type=> 'LOCAL',
#             -input_ids => [
#             {
# 		tempdir               => '/lustre/scratch109/ensembl/funcgen/mn1/qc/3436/',
# 		input_subset_id       => 3436,
# 		
# 		tracking_db_user   => 'ensadmin',
# 		tracking_db_pass   => 'ensembl',
# 		tracking_db_host   => 'ens-genomics1',
# 		tracking_db_name   => 'mn1_faang2_tracking_homo_sapiens_funcgen_81_38',
#             }
#             ],
#             -flow_into => { 1 => 'MkFastQcTempDir', },
#         },
	{
	  -logic_name => 'IdentifyAlignInputSubsets',
	  -module     => 'Bio::EnsEMBL::Funcgen::Hive::IdentifySetInputs',
	  -flow_into => {
	    '2' => [ 'QcFastQcInputIdsFromInputSet' ],
	  },
	},
        {   -logic_name => 'QcFastQcInputIdsFromInputSet',
            -module     => 'Bio::EnsEMBL::Funcgen::Hive::QcFastQcInputIdsFromInputSet',
            -meadow_type=> 'LOCAL',
            -flow_into => { 
	      '2' => [ 'QcFastQcJobFactory' ],
            },
        },
        {   -logic_name => 'QcFastQcJobFactory',
            -module     => 'Bio::EnsEMBL::Funcgen::Hive::QcFastQcJobFactory',
            -meadow_type=> 'LOCAL',
            -flow_into => { 
	      '2' => [ 'MkFastQcTempDir' ],
            },
        },
        {   -logic_name => 'MkFastQcTempDir',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -meadow_type=> 'LOCAL',
            -parameters => { 
		  cmd => qq!mkdir -p #tempdir#!,
            },
            -flow_into => { 
	      '1' => [ 'JobFactoryFastQC' ],
            },
        },
        {   -logic_name => 'JobFactoryFastQC',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -parameters => { 
		  inputquery => qq(select local_url, "#tempdir#" as tempdir from input_subset_tracking where input_subset_id = #input_subset_id#),
		  db_conn    => "mysql://#tracking_db_user#:#tracking_db_pass#\@#tracking_db_host#/#tracking_db_name#"
            },
            -meadow_type=> 'LOCAL',
            -flow_into => {
                '2->A' => [ 'RunFastQC'        ],
                'A->1' => [ 'QcFastQcLoaderJobFactory' ],
            },
        },
        {   -logic_name => 'RunFastQC',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -meadow_type=> 'LSF',
            -parameters => { 
		  cmd => qq(fastqc -o #tempdir# #local_url#),
            },
            -rc_name => 'normal_2GB',
        },
        {   -logic_name => 'QcFastQcLoaderJobFactory',
            -module     => 'Bio::EnsEMBL::Funcgen::Hive::QcFastQcLoaderJobFactory',
            -flow_into => {
                '2' => [ 'QcLoadFastQcResults' ],
            },
        },
        {   -logic_name        => 'QcLoadFastQcResults',
            -module            => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -meadow_type       => 'LOCAL',
            -use_bash_pipefail => 1,
            -parameters => { 
		  cmd => qq!load_fastqc_summary_file.pl --input_subset_id #input_subset_id# --summary_file #fastqc_summary_file# | mysql --host #tracking_db_host# --port #tracking_db_port# --user #tracking_db_user# #tracking_db_name# -p#tracking_db_pass#!,
            },
#             -flow_into => { 
# 	      '1' => [ 'JobFactoryFastQC' ],
#             },
        },
    ];
}

1;



