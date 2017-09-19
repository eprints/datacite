=head1 NAME
EPrints::Plugin::Export::DataCiteXML
=cut

package EPrints::Plugin::Export::DataCiteXML;
use EPrints::Plugin::Export::Feed;

@ISA = ('EPrints::Plugin::Export::Feed');

use strict;

use Data::Dumper;
sub new
{
        my ($class, %opts) = @_;

        my $self = $class->SUPER::new(%opts);

        $self->{name} = 'Data Cite XML';
        $self->{accept} = [ 'dataobj/eprint'];
        $self->{visible} = 'all';
        $self->{suffix} = '.xml';
        $self->{mimetype} = 'application/xml; charset=utf-8';
        $self->{arguments}->{doi} = undef;

      return $self;
}

sub output_dataobj
{
    my ($self, $dataobj, %opts) = @_;

    my $repo = $self->{repository};
    my $xml = $repo->xml;

    #reference the datacite schema from config
    our $entry = $xml->create_element( "resource",
                    xmlns=> $repo->get_conf( "datacitedoi", "xmlns"),
                    "xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance",
                    "xsi:schemaLocation" => $repo->get_conf( "datacitedoi", "schemaLocation"));

    #RM We pass in the DOI from Event::DataCite... or from --args on the cmd line

    # AH my $thisdoi = $opts{doi}; always returns undefined, even when DOI exists
    # Ideally coining should NOT happen in this script but opts{doi} should have it
    # but is always blank
    my $thisdoi = $dataobj->get_value("id_number");
    #RM coin a DOI if either
            # - not come via event or
            # - no doi arg passed in via cmd_line
    # ie when someone exports DataCiteXML from the Action tab
    if(!defined $thisdoi){
            #nick the coining sub from event plugin
            my $event = $repo->plugin("Event::DataCiteEvent");
            $thisdoi = $event->coin_doi($repo, $dataobj);
            #coin_doi may return an event error code if no prefix present assume this is the case
            my $prefix = $repo->get_conf( "datacitedoi", "prefix");
            return $thisdoi if($thisdoi !~ /^$prefix/);
    }
    $entry->appendChild( $xml->create_data_element( "identifier", $thisdoi , identifierType=>"DOI" ) );

       foreach my $field ( $dataobj->{dataset}->get_fields )
        {
            my $mapping_fn = "datacite_mapping_".$field->get_name;
            if($repo->can_call($mapping_fn) && $dataobj->exists_and_set($field->get_name)){
                    my $mapped_element = $repo->call( $mapping_fn, $xml, $dataobj, $repo, $dataobj->value($field->get_name) );
                    print STDERR "MAPPED E: ".$mapped_element."\n";
                    $entry->appendChild( $mapped_element ) if(defined $mapped_element);
            }
        }

    #RM extract licens from documents by some means:
    # my $license = undef;
    # if( $repo->can_call( "datacite_license" ) ){
    #         $license = $repo->call( "datacite_license", $xml, $entry, $dataobj, $repo );
    # }


    ##########################################################################################################################################################################
    ################################# From here on in you can redefine datacite_ampping_[fieldname] sub routines in lib/cfg.d/zzz_datacite_mapping.pl  #######################




    # AH 03/11/2016: mapping the data in the EPrints keywords field to a <subjects> tag.
    # If the keywords field is a multiple - and therefore, an array ref - then
    # iterate through array and make each array element its own <subject> element.
    # Otherwise, if the keywords field is a single block of text, take the string
    # and make it a single <subject> element


    # AH 16/12/2016: commenting out the creation of the <contributors> element. This is because the
    # DataCite 4.0 Schema requires a contributorType attribute, which needs to be mapped. According to
    # https://schema.datacite.org/meta/kernel-4.0/doc/DataCite-MetadataKernel_v4.0.pdf (page 16), there
    # is a controlled list of contributorType options and it would be advisable to alter the
    # Recollect workflow to make use of this controlled list (e.g. a namedset of approved values)
    # and then map the values from this field to the XML found below.
    # Note: if you do not supply a contributorType, the coin DOI process will fail
    # because the contributorType attribute is mandatory. As such, and because the parent <contributor>
    # element is not mandatory, it will be commented out and not sent to DataCite pending further work from ULCC.








    if ($dataobj->exists_and_set( "repo_link" )) {



    }



    # #BF this is a can call which checks and calls for a sub inside the z_datacitedoi called laaanguages
    # if( $repo->can_call( "datacite_custom_language" ) ){
    #     unless( defined( $repo->call( "datacite_custom_language", $xml, $entry, $dataobj ) ) ){
    #         if ($dataobj->exists_and_set( "language" )) {
    #             my $lan = $dataobj->get_value( "language" );
    #             $entry->appendChild( $xml->create_data_element( "language", $lan) );
    #         }
    #     }
    # }

    # AH 16/11/2016: rendering the geoLocations XML elements
    # Note: the initial conditional checks to see if the geographic_cover
    # metadata field exists and is set. This was done because geographic_cover
    # is part of the z_recollect_metadata_profile.pl file within the Recollect
    # plugin and many repositories make it a mandatory field in the workflow.



            return '<?xml version="1.0" encoding="UTF-8"?>'."\n".$xml->to_string($entry);
}


1;
