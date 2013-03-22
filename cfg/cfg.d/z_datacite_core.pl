$c->add_dataset_trigger( "eprint", EP_TRIGGER_STATUS_CHANGE , sub {
       my ( %params ) = @_;
 
       my $repository = %params->{repository};
 
       return undef if (!defined $repository);
 		`echo "Trig" >> /tmp/eventtest`;
	
       if (defined %params->{dataobj}) {
               my $dataobj = %params->{dataobj};
               my $eprint_id = $dataobj->id;
 				`echo "Reg: $eprint_id" >> /tmp/eventtest`;

				EPrints::Plugin::Event::DataCiteEvent->datacite_doi($repository, $eprint_id);
		#		EPrints::DataObj::EventQueue->create_unique( $repository, {
		#		       pluginid => "Event::DataCiteEvent",
         #              action => "datacite_doi",
          #             params => $eprint_id,
           #    });

#			$repository->dataset( "event_queue" )->create_dataobj({
#			                       pluginid => "Event::DataCiteEvent",
#			                       action => "datacite_doi",
#			                       params => [$eprint_id],
#			               });
     }
 
});
 