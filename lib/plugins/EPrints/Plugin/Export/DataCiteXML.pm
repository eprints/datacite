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
##       $self->{mimetype} = 'text/plain; charset=utf-8';
        $self->{mimetype} = 'application/xml; charset=utf-8';
  
      return $self;
}

sub output_dataobj
{
        my ($self, $dataobj, %opts) = @_;

 		my $repo = $self->{repository};
 		my $xml = $repo->xml;


		my $thisdoi = $repo->get_conf( "datacitedoi", "prefix")."/". $repo->get_conf( "datacitedoi", "repoid")."/".$dataobj->id;

		my $entry = $xml->create_element( "resource", xmlns=>"http://datacite.org/schema/kernel-2.2", "xmlns:xsi"=>"http://www.w3.org/2001/XMLSchema-instance", "xsi:schemaLocation"=>"http://datacite.org/schema/kernel-2.2 http://schema.datacite.org/meta/kernel-2.2/metadata.xsd" );
		
	    $entry->appendChild( $xml->create_data_element( "identifier", $thisdoi, identifierType=>"DOI" ) );
		

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

                        #$author->appendChild( $xml->create_data_element(
                         #                       "email",
                          #                      $name->{id} ) );

                        $creators->appendChild( $author );
                }
        }
		$entry->appendChild( $creators );

		if ($dataobj->exists_and_set( "title" )) {
			my $titles = $xml->create_element( "titles" );
		 	$titles->appendChild(  $xml->create_data_element( "title",  $dataobj->render_value( "title" )  ) );
			$entry->appendChild( $titles );
		}
		
		$entry->appendChild( $xml->create_data_element( "publisher", $repo->get_conf( "datacitedoi", "repoid") ) );
	
		if ($dataobj->exists_and_set( "datestamp" )) {
		    $dataobj->get_value( "datestamp" ) =~ /^([0-9]{4})/;
			$entry->appendChild( $xml->create_data_element( "publicationYear", $1 ) ) if $1;
		
		}


		if ($dataobj->exists_and_set( "datestamp" )) {
			my $subjects = $dataobj->get_value("subjects");
			if( EPrints::Utils::is_set( $subjects ) ){
				my $subjects_tag = $xml->create_element( "subjects" );
				foreach my $val (@$subjects){
		                my $subject = EPrints::DataObj::Subject->new( $repo, $val );
				           next unless defined $subject;
				       	$subjects_tag->appendChild(  $xml->create_data_element( "title",  $subject->render_description  ) );
				
				}
				$entry->appendChild( $subjects_tag );
			}
		}
	  
	
		my $thisresourceType = $repo->get_conf( "datacitedoi", "typemap", $dataobj->get_value("type") ); 
		if($thisresourceType!= undef ){
			$entry->appendChild( $xml->create_data_element( "resourceType", $thisresourceType->{'v'},  resourceTypeGeneral=>$thisresourceType->{'a'}) );
		}
		
	
		my $alternateIdentifiers = $xml->create_element( "alternateIdentifiers" );
		$alternateIdentifiers->appendChild(  $xml->create_data_element( "alternateIdentifier",  $dataobj->get_url() , alternateIdentifierType=>"URL" ) );
		$entry->appendChild( $alternateIdentifiers );
	
       return '<?xml version="1.0" encoding="UTF-8"?>'."\n".$xml->to_string($entry);
}

1;