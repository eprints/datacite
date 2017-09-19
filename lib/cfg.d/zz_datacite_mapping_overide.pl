$c->{datacite_mapping_funders} = sub {

    my($xml, $dataobj) = @_;

    if ($dataobj->exists_and_set("funders")) {
        my $funders = $dataobj->get_value("funders");
        my $thefunders = $xml->create_element("fundingReferences");
        foreach my $funder(@$funders) {
            my $author = $xml->create_element("fundingReference");
            my $fund = $funder->{funders};
            my $grant = $funder->{grant};
            my $others = $dataobj->get_value("funders_other_funder");
            if ($fund eq "other") {
                foreach my $other(@$others) {
                    $author->appendChild($xml->create_data_element("funderName", $other));
                }
            } else {
                $author->appendChild($xml->create_data_element("funderName", $fund));
            }

            $author->appendChild($xml->create_data_element("awardNumber", $grant));

            $thefunders->appendChild($author);
        }
        return $thefunders;
    }
    return undef;
};
