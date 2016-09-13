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


    if( $dataobj->exists_and_set( "creators" ) )
          {
              my $creators = $xml->create_element( "creators" );
      my $names = $dataobj->get_value( "creators" );
      ;

      foreach my $name ( @$names )
      {
        my $author = $xml->create_element( "creator" );

        my $name_str = EPrints::Utils::make_name_string( $name->{name});



        my $family = $name->{name}->{family};
        my $given = $name->{name}->{given};
        my $orcid = $name->{orcid};

        if ($family eq '' && $given eq ''){
              $creators->appendChild( $author );
          } else {
            $author->appendChild( $xml->create_data_element("creatorName", $name_str ) );
          }
        if ($given eq ''){
                    $creators->appendChild( $author );
          } else {
            $author->appendChild( $xml->create_data_element("givenName",$given ) );
          }
        if ($family eq ''){
            $creators->appendChild( $author );
          } else {
            $author->appendChild( $xml->create_data_element("familyName", $family ) );
          }
        if ($dataobj->exists_and_set( "creators_orcid" )) {
        if ($orcid eq '') {
            $creators->appendChild( $author );
          }
            else {
          $author->appendChild( $xml->create_data_element("nameIdentifier", $orcid, schemeURI=>"http://orcid.org/", nameIdentifierScheme=>"ORCID" ) );
          }
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



    if ($dataobj->exists_and_set( "keywords" )) {
      my $sub = $dataobj->get_value( "keywords" );
      my $subjects = $xml->create_element( "subjects" );

      $subjects->appendChild(  $xml->create_data_element( "subject", $sub, "xml:lang"=>"en-us") );
      $entry->appendChild( $subjects );
    }



    if( $dataobj->exists_and_set( "contributors" ) )
          {
            my $contributors = $xml->create_element( "contributors" );

      my $names = $dataobj->get_value( "contributors" );
      ;

      foreach my $name ( @$names )
      {
        my $author = $xml->create_element( "contributor" );

        my $name_str = EPrints::Utils::make_name_string( $name->{name});

        my $orcid = $name->{orcid};

        my $typee = $name->{type};
        my $family = $name->{name}->{family};
        my $given = $name->{name}->{given};

        if ($family eq '' && $given eq ''){
            $contributors->appendChild( $author );
          } else {
            $author->appendChild( $xml->create_data_element("contributorName", $name_str ) );
          }
        if ($given eq '') {
            $contributors->appendChild( $author );
          } else {
            $author->appendChild( $xml->create_data_element("givenName",$given ) );
          }
        if ($family eq ''){
            $contributors->appendChild( $author );
          } else {
            $author->appendChild( $xml->create_data_element("familyName", $family ) );
          }

        if ($dataobj->exists_and_set( "contributors_orcid" )) {
            my $orcid = $name->{orcid};
        if ($orcid eq '') {
            $contributors->appendChild( $author );
          } else {
            $author->appendChild( $xml->create_data_element("nameIdentifier", $orcid, schemeURI=>"http://orcid.org/", nameIdentifierScheme=>"ORCID" ) );
          }
        }
      if ($dataobj->exists_and_set( "contributors_affiliation" )) {
            my $affiliation = $dataobj->get_value("contributors_affiliation");
            $author->appendChild( $xml->create_data_element("affillation", $affiliation) );
          }
            $contributors->appendChild( $author );
          }
            $entry->appendChild( $contributors );
          }












  #BF this is a can call which checks and calls for a sub inside the z_datacitedoi called funderrr
      if( $repo->can_call( "datacite_custom_funder" ) )
      {
        if( defined( $repo->call( "datacite_custom_funder", $xml, $entry, $dataobj ) ) )
                               {}
                                 else {

        my $funders = $dataobj->get_value( "funders" );
        my $grant = $dataobj->get_value( "grant" );
        my $projects = $dataobj->get_value( "projects" );
          if ($dataobj->exists_and_set( "funders" )) {
            my $thefunders = $xml->create_element( "funders" );
            foreach my $funder ( @$funders )
            {


              foreach my $project ( @$projects )
              {
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
        foreach my $theurl ( @$theurls )
          {
            my $linkk = $theurl->{link};
        if (!$linkk eq ''){
                $relatedIdentifiers->appendChild(  $xml->create_data_element( "relatedIdentifier", $linkk, relatedIdentifierType=>"URL", relationType=>"IsReferencedBy" ) );
          }
                $entry->appendChild( $relatedIdentifiers );
          }
        }


          if ($dataobj->exists_and_set( "abstract" )) {
            my $abstract = $dataobj->get_value( "abstract" );
            my $discription = $xml->create_element( "descriptions" );



            $discription->appendChild(  $xml->create_data_element( "description", $abstract, "xml:lang"=>"en-us", descriptionType=>"Abstract" ) );



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

          #BF this is a can call which checks and calls for a sub inside the z_datacitedoi called laaanguages
          if( $repo->can_call( "datacite_custom_language" ) )
          {
            if( defined( $repo->call( "datacite_custom_language", $xml, $entry, $dataobj ) ) )
                                   {}
                                     else {

                  		  if ($dataobj->exists_and_set( "language" )) {
                          my $lan = $dataobj->get_value( "language" );
                  	 $entry->appendChild( $xml->create_data_element( "language", $lan) );
                    	}
                    }
                  }





        if( $dataobj->exists_and_set( "geographic_cover" ) )
              {
                my $geo = $xml->create_element( "geoLocations" );

          my $names = $dataobj->get_value( "geographic_cover" );



            my $author = $xml->create_element( "geoLocation" );
            my $bbox = $dataobj->get_value( "bounding_box" );


            my $west = $dataobj->get_value( "bounding_box_west_edge" );
            my $east = $dataobj->get_value( "bounding_box_east_edge" );
            my $south = $dataobj->get_value( "bounding_box_south_edge" );
            my $north = $dataobj->get_value( "bounding_box_north_edge" );

            $author->appendChild( $xml->create_data_element("geoLocationPlace", $names ) );

              my $bobox = $xml->create_element( "geoLocationBox" );





              $bobox->appendChild(  $xml->create_data_element( "westBoundLongitude", $west) );
             $bobox->appendChild(  $xml->create_data_element( "westBoundLongitude", $east) );
             $bobox->appendChild(  $xml->create_data_element( "westBoundLongitude", $south) );
             $bobox->appendChild(  $xml->create_data_element( "westBoundLongitude", $north) );




            $author->appendChild( $bobox);


            $geo->appendChild( $author );


        $entry->appendChild( $geo );
}





		#TODO Seek, identify and include for registration the optional datacite fields
	       return '<?xml version="1.0" encoding="UTF-8"?>'."\n".$xml->to_string($entry);
}


1;
