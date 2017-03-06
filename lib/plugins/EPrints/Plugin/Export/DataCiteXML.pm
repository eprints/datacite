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

        #Existing DOI?
        my $thisdoi = $dataobj->get_value($repo->get_conf("datacitedoi","eprintdoifield"));
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

    # AH 04/11/2016: adding <resourceType> element as it is required for the
    # DataCite 4.0 XML Metadata Schema. For publications repositories, it uses the
    # eprint_type value. For data repositories, it uses the eprint_data_type value.
    my $resourceType_element;
    my $pub_resourceType = $repo->get_conf( "datacitedoi", "typemap", $dataobj->get_value("type") );
    if(defined $pub_resourceType){
       $resourceType_element = $xml->create_data_element( "resourceType", $pub_resourceType->{'v'}, resourceTypeGeneral=>$pub_resourceType->{'a'});
    }
    if( $dataobj->exists_and_set( "data_type" ) ) {
      my $data_type = $dataobj->get_value( "data_type" );
      $resourceType_element = $xml->create_data_element( "resourceType", $data_type, resourceTypeGeneral=>$data_type);
    }
    $entry->appendChild( $resourceType_element );

    if( $dataobj->exists_and_set( "creators" ) ){
        my $creators = $xml->create_element( "creators" );
        my $names = $dataobj->get_value( "creators" );
        foreach my $name ( @$names ){
            my $author = $xml->create_element( "creator" );
            my $name_str = EPrints::Utils::make_name_string( $name->{name} );

            my $family = $name->{name}->{family};
            my $given = $name->{name}->{given};
            my $orcid = $name->{orcid}; #world of assumptions here!

            if (defined $name_str && $name_str ne ''){
                $author->appendChild( $xml->create_data_element("creatorName", $name_str ) );
            }
            if (defined $given && $given ne ''){
                $author->appendChild( $xml->create_data_element("givenName",$given ) );
            }
            if (defined $family && $family ne ''){
                $author->appendChild( $xml->create_data_element("familyName", $family ) );
            }
            if(defined $orcid && $orcid ne '') {
                $author->appendChild( $xml->create_data_element("nameIdentifier", $orcid, schemeURI=>"http://orcid.org/", nameIdentifierScheme=>"ORCID" ) );
            }
            $creators->appendChild( $author );
        }
        $entry->appendChild( $creators );
    }

    if ($dataobj->exists_and_set( "title" )) {
        my $titles = $xml->create_element( "titles" );
		$titles->appendChild(  $xml->create_data_element( "title",  $dataobj->render_value( "title" ), "xml:lang"=>"en-us" ) );
        $entry->appendChild( $titles );
	}
    $entry->appendChild( $xml->create_data_element( "publisher", $repo->get_conf( "datacitedoi", "publisher") ) );

    if ($dataobj->exists_and_set( "date" )) {
        $dataobj->get_value( "date" ) =~ /^([0-9]{4})/;
        $entry->appendChild( $xml->create_data_element( "publicationYear", $1 ) ) if $1;
    }

    # AH 03/11/2016: mapping the data in the EPrints keywords field to a <subjects> tag.
    # If the keywords field is a multiple - and therefore, an array ref - then
    # iterate through array and make each array element its own <subject> element.
    # Otherwise, if the keywords field is a single block of text, take the string
    # and make it a single <subject> element
    if ($dataobj->exists_and_set( "keywords" )) {
        my $subjects = $xml->create_element( "subjects" );
        my $keywords = $dataobj->get_value("keywords");
        if(ref($keywords) eq "ARRAY") {
            foreach my $keyword ( @$keywords ) {
                $subjects->appendChild(  $xml->create_data_element( "subject", $keyword, "xml:lang"=>"en-us") );
            }
            $entry->appendChild( $subjects );
        } else {
            $subjects->appendChild(  $xml->create_data_element( "subject", $keywords, "xml:lang"=>"en-us") );
            $entry->appendChild( $subjects );
        }
    }

    # AH 16/12/2016: commenting out the creation of the <contributors> element. This is because the
    # DataCite 4.0 Schema requires a contributorType attribute, which needs to be mapped. According to
    # https://schema.datacite.org/meta/kernel-4.0/doc/DataCite-MetadataKernel_v4.0.pdf (page 16), there
    # is a controlled list of contributorType options and it would be advisable to alter the
    # Recollect workflow to make use of this controlled list (e.g. a namedset of approved values)
    # and then map the values from this field to the XML found below.
    # Note: if you do not supply a contributorType, the coin DOI process will fail
    # because the contributorType attribute is mandatory. As such, and because the parent <contributor>
    # element is not mandatory, it will be commented out and not sent to DataCite pending further work from ULCC.

    # if( $dataobj->exists_and_set( "contributors" ) )
    # {
    #
    #   my $contributors = $xml->create_element( "contributors" );
    #
    #   my $names = $dataobj->get_value( "contributors" );
    #
    #   foreach my $name ( @$names )
    #   {
    #     my $author = $xml->create_element( "contributor" );
    #
    #     my $name_str = EPrints::Utils::make_name_string( $name->{name});
    #
    #     my $orcid = $name->{orcid};
    #
    #     my $typee = $name->{type};
    #     my $family = $name->{name}->{family};
    #     my $given = $name->{name}->{given};
    #
    #     if ($family eq '' && $given eq ''){
    #       $contributors->appendChild( $author );
    #     } else {
    #       $author->appendChild( $xml->create_data_element("contributorName", $name_str ) );
    #     }
    #     if ($given eq '') {
    #       $contributors->appendChild( $author );
    #     } else {
    #       $author->appendChild( $xml->create_data_element("givenName",$given ) );
    #     }
    #     if ($family eq ''){
    #       $contributors->appendChild( $author );
    #     } else {
    #       $author->appendChild( $xml->create_data_element("familyName", $family ) );
    #     }
    #
    #     if ($dataobj->exists_and_set( "contributors_orcid" )) {
    #       my $orcid = $name->{orcid};
    #       if ($orcid eq '') {
    #         $contributors->appendChild( $author );
    #       } else {
    #         $author->appendChild( $xml->create_data_element("nameIdentifier", $orcid, schemeURI=>"http://orcid.org/", nameIdentifierScheme=>"ORCID" ) );
    #       }
    #     }
    #     if ($dataobj->exists_and_set( "contributors_affiliation" )) {
    #       my $affiliation = $dataobj->get_value("contributors_affiliation");
    #       $author->appendChild( $xml->create_data_element("affillation", $affiliation) );
    #     }
    #     $contributors->appendChild( $author );
    #   }
    #   $entry->appendChild( $contributors );
    # }

    #BF this is a can call which checks and calls for a sub inside the z_datacitedoi called funderrr
    if( $repo->can_call( "datacite_custom_funder" ) ){
        unless( defined( $repo->call( "datacite_custom_funder", $xml, $entry, $dataobj ) ) ){

            my $funders = $dataobj->get_value( "funders" );
            my $grant = $dataobj->get_value( "grant" );
            my $projects = $dataobj->get_value( "projects" );
            if ($dataobj->exists_and_set( "funders" )) {
                my $thefunders = $xml->create_element( "funders" );
                foreach my $funder ( @$funders ){
                    foreach my $project ( @$projects ){
                        $thefunders->appendChild(  $xml->create_data_element( "funderName", $funder) );
                        $thefunders->appendChild(  $xml->create_data_element( "awardNumber", $grant) );
                    }
                }
                $entry->appendChild( $thefunders );
            }
        }
    }

    if ($dataobj->exists_and_set( "repo_link" )) {
        my $theurls = $dataobj->get_value( "repo_link" );
        my $relatedIdentifiers = $xml->create_element( "relatedIdentifiers" );
        foreach my $theurl ( @$theurls ){
            my $linkk = $theurl->{link};
            if (!$linkk eq ''){
                $relatedIdentifiers->appendChild(  $xml->create_data_element( "relatedIdentifier", $linkk, relatedIdentifierType=>"URL", relationType=>"IsReferencedBy" ) );
            }
            $entry->appendChild( $relatedIdentifiers );
        }
    }

    if ($dataobj->exists_and_set( "abstract" )) {

        my $abstract = $dataobj->get_value( "abstract" );
        my $description = $xml->create_element( "descriptions" );

        $description->appendChild(  $xml->create_data_element( "description", $abstract, "xml:lang"=>"en-us", descriptionType=>"Abstract" ) );

        if ($dataobj->exists_and_set( "collection_method" )) {
            my $collection = $dataobj->get_value("collection_method");
            $description->appendChild( $xml->create_data_element("description", $collection, descriptionType=>"Methods"));
        }

        if ($dataobj->exists_and_set( "provenance" )) {
            my $processing = $dataobj->get_value("provenance");
            $description->appendChild( $xml->create_data_element("description", $processing, descriptionType=>"Methods"));
        }
        $entry->appendChild( $description );
    }

    #BF this is a can call which checks and calls for a sub inside the z_datacitedoi called laaanguages
    if( $repo->can_call( "datacite_custom_language" ) ){
        unless( defined( $repo->call( "datacite_custom_language", $xml, $entry, $dataobj ) ) ){
            if ($dataobj->exists_and_set( "language" )) {
                my $lan = $dataobj->get_value( "language" );
                $entry->appendChild( $xml->create_data_element( "language", $lan) );
            }
        }
    }

    # AH 16/11/2016: rendering the geoLocations XML elements
    # Note: the initial conditional checks to see if the geographic_cover
    # metadata field exists and is set. This was done because geographic_cover
    # is part of the z_recollect_metadata_profile.pl file within the Recollect
    # plugin and many repositories make it a mandatory field in the workflow.

    if( $dataobj->exists_and_set( "geographic_cover" ) ) {

        #Create XML elements
        my $geo_locations = $xml->create_element( "geoLocations" );
        my $geo_location = $xml->create_element( "geoLocation" );

        # Get value of geographic_cover field and append to $geo_location XML element
        my $geographic_cover = $dataobj->get_value( "geographic_cover" );
        $geo_location->appendChild( $xml->create_data_element("geoLocationPlace", $geographic_cover ) );

        # Get values of bounding box
        my $west = $dataobj->get_value( "bounding_box_west_edge" );
        my $east = $dataobj->get_value( "bounding_box_east_edge" );
        my $south = $dataobj->get_value( "bounding_box_south_edge" );
        my $north = $dataobj->get_value( "bounding_box_north_edge" );

        # Check to see if $north, $south, $east, or $west values are defined
        if ($north || $south || $east || $west ) {
            # Created $geo_location_box XML element
            my $geo_location_box = $xml->create_element( "geoLocationBox" );
            # If $west is defined, created XML element with the appropriate value
            if ($west) {
                $geo_location_box->appendChild(  $xml->create_data_element( "westBoundLongitude", $west) );
            }
            # If $east is defined, created XML element with the appropriate value
            if ($east) {
                $geo_location_box->appendChild(  $xml->create_data_element( "eastBoundLongitude", $east) );
            }
            # If $south is defined, created XML element with the appropriate value
            if ($south) {
                $geo_location_box->appendChild(  $xml->create_data_element( "southBoundLongitude", $south) );
            }
            # If $north is defined, created XML element with the appropriate value
            if ($north) {
                $geo_location_box->appendChild(  $xml->create_data_element( "northBoundLongitude", $north) );
            }
            # Append child $geo_location_box XML element to parent $geo_location XML element
            $geo_location->appendChild( $geo_location_box );
        }
        # Append child $geo_location XML element to parent $geo_locations XML element
        $geo_locations->appendChild( $geo_location );
        # Append $geo_locations XML element to XML document
        $entry->appendChild( $geo_locations );
    }

    return '<?xml version="1.0" encoding="UTF-8"?>'."\n".$xml->to_string($entry);
}

1;
