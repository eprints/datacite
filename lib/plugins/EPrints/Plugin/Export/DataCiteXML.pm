=head1 NAME

EPrints::Plugin::Export::DataCiteXML

=cut

package EPrints::Plugin::Export::DataCiteXML;
use EPrints::Plugin::Export::Feed;

@ISA = ('EPrints::Plugin::Export::Feed');

use strict;

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
		my $entry = $xml->create_element( "resource",
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

		my $creators = $xml->create_element( "creators" );
		if( $dataobj->exists_and_set( "creators" ) )
        	{

			my $names = $dataobj->get_value( "creators" );
			foreach my $name ( @$names )
			{
				my $author = $xml->create_element( "creator" );

				my $name_str = EPrints::Utils::make_name_string( $name->{name});
				$author->appendChild( $xml->create_data_element(
							"creatorName",
							$name_str ) );

				$creators->appendChild( $author );
			}
        	}
		$entry->appendChild( $creators );

		if ($dataobj->exists_and_set( "title" )) {
			my $titles = $xml->create_element( "titles" );
		 	$titles->appendChild(  $xml->create_data_element( "title",  $dataobj->render_value( "title" )  ) );
			$entry->appendChild( $titles );
		}

		$entry->appendChild( $xml->create_data_element( "publisher", $repo->get_conf( "datacitedoi", "publisher") ) );

		if ($dataobj->exists_and_set( "datestamp" )) {
		    $dataobj->get_value( "datestamp" ) =~ /^([0-9]{4})/;
			$entry->appendChild( $xml->create_data_element( "publicationYear", $1 ) ) if $1;

		}


		if ($dataobj->exists_and_set( "subjects" )) {
			my $subjects = $dataobj->get_value("subjects");
			if( EPrints::Utils::is_set( $subjects ) ){
				my $subjects_tag = $xml->create_element( "subjects" );
				foreach my $val (@$subjects){
		                my $subject = EPrints::DataObj::Subject->new( $repo, $val );
				           next unless defined $subject;
				       	$subjects_tag->appendChild(  $xml->create_data_element( "subject",  $subject->render_description  ) );

				}
				$entry->appendChild( $subjects_tag );
			}
		}


		my $thisresourceType = $repo->get_conf( "datacitedoi", "typemap", $dataobj->get_value("type") );
		if(defined $thisresourceType ){
			$entry->appendChild( $xml->create_data_element( "resourceType", $thisresourceType->{'v'},  resourceTypeGeneral=>$thisresourceType->{'a'}) );
		}


		my $alternateIdentifiers = $xml->create_element( "alternateIdentifiers" );
		$alternateIdentifiers->appendChild(  $xml->create_data_element( "alternateIdentifier",  $dataobj->get_url() , alternateIdentifierType=>"URL" ) );
		$entry->appendChild( $alternateIdentifiers );


		#TODO Seek, identify and include for registration the optional datacite fields
	       return '<?xml version="1.0" encoding="UTF-8"?>'."\n".$xml->to_string($entry);
}

1;
