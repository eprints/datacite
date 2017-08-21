####################################################
# New architecture for print => datacite mapping
####################################################

#These first two both map to resourceType (and resourceTypeGeneral) the first is for pubs repos the second for data (but either can be used for ether f the eprint field is there)
$c->{datacite_mapping_type} = sub {

    my ( $xml, $dataobj, $repo, $value ) = @_;
   
    my $pub_resourceType = $repo->get_conf( "datacitedoi", "typemap", $value );
    if(defined $pub_resourceType){
       return $xml->create_data_element( "resourceType", $pub_resourceType->{'v'}, resourceTypeGeneral=>$pub_resourceType->{'a'});
    }

    return undef;
};

$c->{datacite_mapping_data_type} = sub {

	 my ( $xml, $dataobj, $repo, $value ) = @_;

     return $xml->create_data_element( "resourceType", $value, resourceTypeGeneral=>$value);
};

$c->{datacite_mapping_creators} = sub {

	my ( $xml, $dataobj, $repo, $value ) = @_;

        my $creators = $xml->create_element( "creators" );

        foreach my $name ( @$value ){
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
                } else {
                  $author->appendChild( $xml->create_data_element("nameIdentifier", $orcid, schemeURI=>"http://orcid.org/", nameIdentifierScheme=>"ORCID" ) );
                }
            }
            
            $creators->appendChild( $author );
        }
        return $creators
};

=comment

$c->{datacite_mapping_somefield} = sub {


	my ( $xml, $dataobj, $repo, $value ) = @_;

    #Do the mapping/validation here....

    return $xml #of somedescription


}

=cut
