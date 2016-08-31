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

		#RM otherwise we'll leave this alone for now

    # my $creators = $xml->create_element( "creators" );
    if( $dataobj->exists_and_set( "creators" ) )
          {
              my $creators = $xml->create_element( "creators" );
      my $names = $dataobj->get_value( "creators" );
      ;

      foreach my $name ( @$names )
      {
        my $author = $xml->create_element( "creator" );

        my $name_str = EPrints::Utils::make_name_string( $name->{name});
        # my $family = EPrints::Utils::make_family_name_string( $name->{family}->{name});
        # my $orcid = $name->get_value("orcid");

          # my $orc= $dataobj->get_value( "creator_orcid" );
        my $family = $name->{name}->{family};
        my $given = $name->{name}->{given};
        my $orcid = $name->{orcid};
        $author->appendChild( $xml->create_data_element(
              "creatorName",
              $name_str ) );
              $author->appendChild( $xml->create_data_element("givenName",$given ) );
              $author->appendChild( $xml->create_data_element("familyName", $family ) );

                if ($dataobj->exists_and_set( "creators_orcid" )) {
                  print STDERR Dumper $orcid;
        $author->appendChild( $xml->create_data_element("nameIdentifier", $orcid, schemeURI=>"http://orcid.org/", nameIdentifierScheme=>"ORCID" ) );
        # $author->appendChild( $xml->create_data_element("affillation", $name_str) );
}
# print STDERR Dumper $orcid;
        $creators->appendChild( $author );
      }

    $entry->appendChild( $creators );
  }


    if ($dataobj->exists_and_set( "title" )) {
			my $titles = $xml->create_element( "titles" );
		 	$titles->appendChild(  $xml->create_data_element( "title",  $dataobj->render_value( "title" ), "xml:lang"=>"en-us" ) );
      # $titles->appendChild(  $xml->create_data_element( "title",  $dataobj->render_value( "title" ), "xml:lang"=>"en-us", titleType=>"Subtitle" ) );
      $entry->appendChild( $titles );
		}

$entry->appendChild( $xml->create_data_element( "publisher", $repo->get_conf( "datacitedoi", "publisher") ) );

if ($dataobj->exists_and_set( "date" )) {
    $dataobj->get_value( "date" ) =~ /^([0-9]{4})/;
  $entry->appendChild( $xml->create_data_element( "publicationYear", $1 ) ) if $1;

}


# my $sub = $dataobj->get_value( "keywords" );
    if ($dataobj->exists_and_set( "keywords" )) {
      my $sub = $dataobj->get_value( "keywords" );
      my $subjects = $xml->create_element( "subjects" );

      $subjects->appendChild(  $xml->create_data_element( "subject", $sub, "xml:lang"=>"en-us") );
      $entry->appendChild( $subjects );
    }


      # my $author = $xml->create_element( "contributors" );
    # my $contributors = $xml->create_element( "contributors" );
    if( $dataobj->exists_and_set( "contributors" ) )
          {
            my $contributors = $xml->create_element( "contributors" );

      my $names = $dataobj->get_value( "contributors" );
      ;

      foreach my $name ( @$names )
      {
        my $author = $xml->create_element( "contributor" );

        my $name_str = EPrints::Utils::make_name_string( $name->{name});
        # my $family = EPrints::Utils::make_family_name_string( $name->{family}->{name});
        # my $orcid = $name->get_value("orcid");
        my $orcid = $name->{orcid};
        #print out the phrase too
        # my $type = $name->{type};
        # print STDERR Dumper $name;
        my $typee = $name->{type};
        my $family = $name->{name}->{family};
        my $given = $name->{name}->{given};
        # $author->appendChild( $xml->create_data_element("contributor") );
        $author->appendChild( $xml->create_data_element("contributorName", $name_str ) );
        $author->appendChild( $xml->create_data_element("givenName",$given ) );
        $author->appendChild( $xml->create_data_element("familyName", $family ) );


        # print STDERR Dumper $typee;

        if ($dataobj->exists_and_set( "contributors_orcid" )) {
      my $orcid = $name->{orcid};
    $author->appendChild( $xml->create_data_element("nameIdentifier", $orcid, schemeURI=>"http://orcid.org/", nameIdentifierScheme=>"ORCID" ) );
    # $author->appendChild( $xml->create_data_element("affillation", $name_str) );
    }
    if ($dataobj->exists_and_set( "creator_affiliation" )) {
    my $affiliation = $dataobj->get_value("creator_affiliation");
    $author->appendChild( $xml->create_data_element("affillation", $affiliation) );
    }


    # my $rights = $dataobj->get_value( "copyright_holders" );
    # if ($dataobj->exists_and_set( "copyright_holders" )) {
    #   my $rights = $dataobj->get_value( "copyright_holders" );
    # foreach my $right ( @$rights )
    # {
    # $author->appendChild( $xml->create_data_element("contributor", $right, contributorType=>"RightsHolder" ) );
    # # $author->appendChild( $xml->create_data_element("affillation", $name_str) );
    # }
    # }
    $contributors->appendChild( $author );
      }

    $entry->appendChild( $contributors );
  }

		# my $thisresourceType = $repo->get_conf( "datacitedoi", "typemap", $dataobj->get_value("type") );
		# if(defined $thisresourceType ){
		# 	$entry->appendChild( $xml->create_data_element( "resourceType", $thisresourceType->{'v'},  resourceTypeGeneral=>$thisresourceType->{'a'}) );
		# }

    # my $type = $dataobj->get_value( "data_type" );
        # if ($dataobj->exists_and_set( "data_type" )) {
        #   my $type = $dataobj->get_value( "data_type" );
        # $entry->appendChild(  $xml->create_data_element( "resourceType", $type, resourceTypeGeneral=>"Software") );
        #
        # }











      if( $repo->can_call( "funderrr" ) )
      {
        if( defined( $repo->call( "funderrr", $xml, $entry, $dataobj ) ) )
                               {}
                                 else {

        my $funders = $dataobj->get_value( "funders" );
        my $grant = $dataobj->get_value( "grant" );
        my $projects = $dataobj->get_value( "projects" );
          if ($dataobj->exists_and_set( "funders" )) {
            my $thefunders = $xml->create_element( "funders" );
            foreach my $funder ( @$funders )
            {
              #  my $fun = $funder->{funders};

              foreach my $project ( @$projects )
              {
            $thefunders->appendChild(  $xml->create_data_element( "funderName", $funder) );
            $thefunders->appendChild(  $xml->create_data_element( "awardNumber", $grant) );
            # $thefunders->appendChild(  $xml->create_data_element( "awardTitle", $project) );
            # print STDERR Dumper $funder;
          }
        }
            $entry->appendChild( $thefunders );
          }
          }
        }


      # my $alternateIdentifiers = $xml->create_element( "alternateIdentifiers" );
      # $alternateIdentifiers->appendChild(  $xml->create_data_element( "alternateIdentifier",  $dataobj->get_url() , alternateIdentifierType=>"URL" ) );
      # $entry->appendChild( $alternateIdentifiers );
      #
      #

      if ($dataobj->exists_and_set( "repo_link" )) {
      # my $relatedResources = $dataobj->get_value( "related_resources_url" );
      # foreach my $relatedResource ( @$relatedResources )
      # {

      my $relatedIdentifiers = $xml->create_element( "relatedIdentifiers" );
      $relatedIdentifiers->appendChild(  $xml->create_data_element( "relatedIdentifier",  $dataobj->get_url() , relatedIdentifierType=>"URL", relationType=>"IsReferencedBy" ) );
      # $relatedIdentifiers->appendChild( $xml->create_data_element("relatedIdentifier", ));
      # $relatedIdentifiers->appendChild(  $xml->create_data_element("relatedIdentifier", $relatedResource, relatedIdentifierType=>"DOI", relationType=>"IsReferencedBy"));
      $entry->appendChild( $relatedIdentifiers );
    }
  # }

      # my $abstract = $dataobj->get_value( "abstract" );
          if ($dataobj->exists_and_set( "abstract" )) {
            my $abstract = $dataobj->get_value( "abstract" );
            my $discription = $xml->create_element( "descriptions" );



            $discription->appendChild(  $xml->create_data_element( "description", $abstract, "xml:lang"=>"en-us", descriptionType=>"Abstract" ) );


            # if ($dataobj->exists_and_set( "legal_ethical" )) {
            #    my $legal = $dataobj->get_value( "legal_ethical" );
            #
            # $discription->appendChild(  $xml->create_data_element( "description", $legal, descriptionType=>"other" ) );
            # }
            if ($dataobj->exists_and_set( "collection_method" )) {
            my $collection = $dataobj->get_value("collection_method");
            $discription->appendChild( $xml->create_data_element("discrpition", $collection, descriptionType=>"Methods"));
          }

            if ($dataobj->exists_and_set( "provenance" )) {
            my $processing = $dataobj->get_value("provenance");
            $discription->appendChild( $xml->create_data_element("discrpition", $processing, descriptionType=>"Methods"));
          }
            $entry->appendChild( $discription );
          }


          if( $repo->can_call( "laaanguages" ) )
          {
            if( defined( $repo->call( "laaanguages", $xml, $entry, $dataobj ) ) )
                                   {}
                                     else {
                      # my $lan = $dataobj->get_value( "language" );
                  		  if ($dataobj->exists_and_set( "language" )) {
                          my $lan = $dataobj->get_value( "language" );
                  	 $entry->appendChild( $xml->create_data_element( "language", $lan) );
                    	}
                    }
                  }


          # # my ( $xml, $entry, $dataobj ) = @_;
          # #
          # 	my $lan = $dataobj->get_value( "language" );
          # 		if ($dataobj->exists_and_set( "language" )) {
          # 			foreach my $la ( @$lan )
          # 			{
          # 				my $thelanguage = $la->{l};
          #  $entry->appendChild( $xml->create_data_element( "language", $thelanguage) );
          # 	}
          # }


        if( $dataobj->exists_and_set( "geographic_cover" ) )
              {
                my $geo = $xml->create_element( "geoLocations" );
                # my $geo = $xml->create_element( "geoLocations" );
          my $names = $dataobj->get_value( "geographic_cover" );



            my $author = $xml->create_element( "geoLocation" );
            my $bbox = $dataobj->get_value( "bounding_box" );
            print STDERR Dumper $bbox;
            # my $name_str = EPrints::Utils::make_name_string( $name->{name});
            # my $family = EPrints::Utils::make_family_name_string( $name->{family}->{name});
            # my $orcid = $name->get_value("orcid");
            # my $orcid = $name->{orcid};
            #
            # my $north = $bbox->{north}->{edge};
            my $west = $dataobj->get_value( "bounding_box_west_edge" );
            my $east = $dataobj->get_value( "bounding_box_east_edge" );
            my $south = $dataobj->get_value( "bounding_box_south_edge" );
            my $north = $dataobj->get_value( "bounding_box_north_edge" );
            # my $given = $name->{name}->{given};
            $author->appendChild( $xml->create_data_element("geoLocationPlace", $names ) );
            # $author->appendChild( $xml->create_data_element("geoLocationPoint" ) );
              my $bobox = $xml->create_element( "geoLocationBox" );
              #line below is not finished make sure to take a look back at it




              $bobox->appendChild(  $xml->create_data_element( "westBoundLongitude", $west) );
             $bobox->appendChild(  $xml->create_data_element( "westBoundLongitude", $east) );
             $bobox->appendChild(  $xml->create_data_element( "westBoundLongitude", $south) );
             $bobox->appendChild(  $xml->create_data_element( "westBoundLongitude", $north) );
            print STDERR Dumper $north;


            #       $author->appendChild( $xml->create_data_element("givenName",$given ) );
            #       $author->appendChild( $xml->create_data_element("familyName", $family ) );
            # $author->appendChild( $xml->create_data_element("nameIdentifier", $orcid, schemeURI=>"http://orcid.org/", nameIdentifierScheme=>"ORCID" ) );
            # $author->appendChild( $xml->create_data_element("affillation", $name_str) );
            $author->appendChild( $bobox);


            $geo->appendChild( $author );


        $entry->appendChild( $geo );
}


		# my $relatedIdentifiers = $xml->create_element( "alternateIdentifiers" );
		# $alternateIdentifiers->appendChild(  $xml->create_data_element( "alternateIdentifier",  $dataobj->get_url() , alternateIdentifierType=>"URL" ) );
		# $entry->appendChild( $alternateIdentifiers );


		#TODO Seek, identify and include for registration the optional datacite fields
	       return '<?xml version="1.0" encoding="UTF-8"?>'."\n".$xml->to_string($entry);
}


1;
