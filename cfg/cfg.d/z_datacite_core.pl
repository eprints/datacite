# Adds the minting plugin to the EP_TRIGGER_STATUS_CHANGE
$c->add_dataset_trigger( "eprint", EP_TRIGGER_STATUS_CHANGE , sub {
	my ( %params ) = @_;

	my $repository = %params->{repository};

	return undef if (!defined $repository);

	if (defined %params->{dataobj})
	{
		my $dataobj = %params->{dataobj};
		my $eprint_id = $dataobj->id;

		$repository->dataset( "event_queue" )->create_dataobj({
			pluginid => "Event::DataCiteEvent",
			action => "datacite_doi",
			params => [$dataobj->internal_uri],
		});
	}
});

